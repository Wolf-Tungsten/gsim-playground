# GSIM FIRRTL 寄存器语义错误分析

## 1. 结论

本次问题的根因不是 workload、DRAMSim3、difftest，也不是此前已经排除过的“不支持时钟”告警。

根因已经收敛到 **GSIM 在生成 C++ 仿真模型时破坏了寄存器的时序语义**：

- RTL / FIRRTL / Verilog 非阻塞赋值语义要求：`REG_1 <= REG` 在当前拍读到的是 `REG` 的旧值。
- GSIM 生成的 C++ 在同一个 substep 里先执行 `REG = REG$NEXT`，随后才计算 `REG_1$NEXT = REG`。
- 结果是 `REG_1$NEXT` 读到的是 `REG` 的新值，而不是旧值。
- 等价效果是把两级寄存器链压缩成一级，导致控制路径提前一拍传播。

这正好解释了 XiangShan 中 `io_error_0_REG <= ...; io_error_0_REG_1 <= io_error_0_REG;` 这类路径为何在 GSIM 下会过早触发 `csr_dbltrp_inMN`。

## 2. 运行层证据

### 2.1 GSIM 与 Verilator 在同一 workload 上出现不同结果

同一个 workload：

- `logs/xs-gsim-emu/20260408_213354/run_xs_gsim_emu_20260408_213354_20260408_213405.log`
- `logs/xs-verilator-emu/20260408_213138/run_xs_verilator_emu_20260408_213138_20260408_213145.log`

两者在 `pc=0x80000028` 的 `lw t1, 0(s0)`（`inst=00043303`）处分叉：

GSIM：

```text
[06] exception pc 0000000080000028 inst 00043303 cause 000000000000000c
```

Verilator：

```text
[06] commit pc 0000000080000028 inst 00043303 wen 1 dst 06 data 000000000000caff idx 006
```

也就是说 Verilator 正常从 `0x80000888` 读出了 `0xcaff`，而 GSIM 在同一条指令上已经进入异常路径。

### 2.2 去掉 difftest 后 GSIM 仍然失败

在 `XiangShan/build/gsim-compile` 下直接运行：

```bash
./emu -i ../../../workload/_49458_0.264720_.zstd \
  --no-diff --seed 1705 --max-instr 40 --dump-commit-trace
```

仍然会在很早阶段失败：

```text
[ERROR][time=8470] SimTop.cpu.l_soc.core_with_l2.core.backend.inner.intRegion.intExuBlock: critical error: csr_dbltrp_inMN
emu: .../XiangShan/build/gsim-compile/model/SimTop82.cpp:20057:
Assertion `!(... & ...io_error_0_REG_1)' failed.
```

因此根因不在 difftest，对应错误是 **GSIM 生成 DUT 自身就已经算错了**。

## 3. 语义错误的最小抽象

正确的时序语义应等价于：

```verilog
always @(posedge clock) begin
  a <= in;
  b <= a;
end
```

期望行为：

- `a_next = in`
- `b_next = a_old`

GSIM 当前表现出来的行为更接近：

```cpp
a = a_next;
b_next = a;
```

于是变成：

- `a = a_next`
- `b_next = a_next`

这会把原本两拍传播的链路压缩成一拍。

## 4. XiangShan 中的直接证据

### 4.1 RTL 本身是正确的

`XiangShan/build/rtl/NewCSR.sv`：

```sv
io_error_0_REG <= criticalErrorStateInCSR;
io_error_0_REG_1 <= io_error_0_REG;
```

同样的两级寄存器链也出现在：

- `XiangShan/build/rtl/CSR.sv`
- `XiangShan/build/rtl/CtrlBlock.sv`

这类写法在 RTL 中是合法且常见的，`io_error_0_REG_1` 必须看到 `io_error_0_REG` 的旧值。

### 4.2 GSIM 生成代码把旧值链路破坏了

`XiangShan/build/gsim-compile/model/SimTop62.cpp` 中可以直接看到错误顺序：

```cpp
cpu...io_error_0_REG = cpu...io_error_0_REG$NEXT;
cpu...io_error_0_REG_1 = cpu...io_error_0_REG_1$NEXT;
cpu...io_error_0_REG_1$NEXT = cpu...io_error_0_REG;
```

这里最后一行读取的 `io_error_0_REG` 已经是本拍更新后的值，不再是旧值。

这不是孤例。在同一文件里，`csr_io_csrio_robDeqPtr_delay` 的两级寄存器链也出现同样模式：

```cpp
cpu...csr_io_csrio_robDeqPtr_delay.REG.flag = ...REG.flag$NEXT;
cpu...csr_io_csrio_robDeqPtr_delay.REG.value = ...REG.value$NEXT;
cpu...csr_io_csrio_robDeqPtr_delay.REG_1.flag = ...REG_1.flag$NEXT;
cpu...csr_io_csrio_robDeqPtr_delay.REG_1.value = ...REG_1.value$NEXT;
cpu...csr_io_csrio_robDeqPtr_delay.REG_1.value$NEXT = ...REG.value;
cpu...csr_io_csrio_robDeqPtr_delay.REG_1.flag$NEXT = ...REG.flag;
```

这说明问题不是 `io_error_0_REG` 特例，而是 **GSIM backend 的寄存器更新调度策略整体有误**。

### 4.3 错误如何传播到 `csr_dbltrp_inMN`

`XiangShan/src/main/scala/xiangshan/backend/fu/NewCSR/NewCSR.scala`：

```scala
val criticalErrors = Seq(
  ("csr_dbltrp_inMN", !mnstatus.regOut.NMIE && hasTrap && !entryDebugMode),
)
criticalErrorStateInCSR := criticalErrors.map(criticalError => criticalError._2).reduce(_ || _).asBool
```

`XiangShan/src/main/scala/xiangshan/backend/fu/NewCSR/TrapHandleModule.scala`：

```scala
private val dbltrpToMN = m_EX_DT && mnstatus.NMIE.asBool
private val hasDTExcp  = m_EX_DT || s_EX_DT || vs_EX_DT
```

GSIM 把 `criticalErrorStateInCSR -> io_error_0_REG -> io_error_0_REG_1` 这条链提早了一拍，因此 `io_error_0_REG_1` 在本不该拉高的时刻就参与断言，最终在：

`XiangShan/build/gsim-compile/model/SimTop82.cpp:20057`

触发：

```cpp
gAssert(!( ... & ...io_error_0_REG_1), "Assertion failed at LogUtils.scala:132\n");
```

## 5. 为什么 Verilator 没有这个问题

Verilator 消费的是 `XiangShan/build/rtl/*.sv`，按照 Verilog 的寄存器更新语义执行，因此：

- `io_error_0_REG <= criticalErrorStateInCSR`
- `io_error_0_REG_1 <= io_error_0_REG`

会自然保持两拍链路。

GSIM 则是直接把 FIRRTL/中间表示转成 C++ 执行。当前 bug 出在这条 C++ 生成链的调度上，而不是 XiangShan RTL 本身。

## 6. 后端定位

目前已经确认：

- 错误行为体现在 `XiangShan/build/gsim-compile/model/SimTop62.cpp` / `SimTop82.cpp`
- 同类错误出现在多个无关寄存器链上
- 问题属于 **寄存器提交顺序与 `$NEXT` 计算顺序混叠**

最可疑的位置在 GSIM emitter：

- `gsim/src/cppEmitter.cpp`
- `gsim/src/instsGenerator.cpp`

尤其是以下两个阶段需要继续核查：

1. `instsGenerator.cpp` 对 `SUPER_INFO_ASSIGN_BEG` / `SUPER_INFO_ASSIGN_END` 的插入顺序  
2. `cppEmitter.cpp` 在 `genSuperEval()` / `translateInst()` 所生成的 substep 内部，是否过早把 `REG = REG$NEXT` 混入了仍在计算其它 `$NEXT` 的区域

`cppEmitter.cpp` 中 `activateNext()` 还包含一个 `inStep` 分支，会直接发出：

```cpp
node = node$NEXT;
```

虽然仅凭当前证据还不能断言最终 bug 就落在这一处分支，但它与已经观察到的错误模式高度一致，因此是首要排查点。

## 7. 当前结论的边界

已经确认的内容：

- GSIM 仿真错误源自 GSIM 生成的 DUT 模型
- 错误类型是寄存器链读取到了“新值”而不是“旧值”
- 该错误足以解释当前 workload 上的 `csr_dbltrp_inMN`

尚未最终确认的内容：

- `cppEmitter.cpp` 中哪一条具体生成路径最终产出了 `REG = REG$NEXT; REG_1$NEXT = REG;`
- 是否还有其它 FIRRTL 语义在同一调度策略下被连带破坏

## 8. 建议的下一步

1. 在 GSIM backend 中构造一个最小测试：

```verilog
reg a, b;
always @(posedge clock) begin
  a <= in;
  b <= a;
end
```

确认生成 C++ 是否也会把 `b_next` 错算成 `a_next`。

2. 在 emitter 中强制分离两个阶段：

- 先计算所有 `$NEXT`
- 再统一提交所有 `REG = REG$NEXT`

3. 修复后优先回归以下信号链：

- `io_error_0_REG -> io_error_0_REG_1`
- `csr_io_csrio_robDeqPtr_delay.REG -> REG_1`

这两条链已经是当前问题的直接反例。
