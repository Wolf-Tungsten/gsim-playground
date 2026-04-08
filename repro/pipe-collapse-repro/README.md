# Pipe Collapse Repro

这个最小案例用于复现 GSIM 和 Verilator 在同一个 Chisel 设计上的行为差异。

整个 repro 都位于项目根目录下的 `repro/pipe-collapse-repro/`，不依赖把测试模块塞进 XiangShan 的源码树。
所有生成物统一落在 `build/pipe-collapse-repro/`，不会在 repro 目录下生成 `out/`。

## 设计

Chisel 设计位于：

- `repro/pipe-collapse-repro/src/gsimrepro/PipeCollapseRepro.scala`

核心逻辑只有两级寄存器链：

```scala
aReg := io.in
bReg := aReg
```

对应的 SystemVerilog 会生成为：

```sv
aReg <= io_in;
bReg <= aReg;
```

这正是此前分析过的敏感模式。

## 运行

在仓库根目录执行：

```bash
make -C repro/pipe-collapse-repro run-verilator
make -C repro/pipe-collapse-repro run-gsim
```

首次执行 `run-verilator` / `run-gsim` 时，`gen` 目标会调用 Chisel/Mill 生成：

- `build/pipe-collapse-repro/gen/PipeCollapseRepro.sv`
- `build/pipe-collapse-repro/gen/PipeCollapseRepro.fir`

这里的 Chisel 生成步骤由 `Makefile` 直接调用 Scala 编译器和生成入口完成，因此不需要在 repro 目录下维护额外的 Mill `out/` 目录。

然后：

- Verilator 使用 `.sv`
- GSIM 使用 `.fir`

两边共用同一个 `cpp tb`：

- `repro/pipe-collapse-repro/tb.cpp`

- `repro/pipe-collapse-repro/Makefile`

## 预期结果

Verilator 应该通过：

```text
cycle=0 in=1 a=1 b=0
cycle=1 in=0 a=0 b=1
cycle=2 in=0 a=0 b=0
PASS
```

GSIM 当前会失败：

```text
cycle=0 in=1 a=0 b=0
mismatch at cycle 0: in=1 got(a=0,b=0) expect(a=1,b=0)
```

## 生成代码中的直接证据

GSIM 生成的模型位于：

- `build/pipe-collapse-repro/gsim-model/PipeCollapseRepro0.cpp`

其中可以看到错误顺序：

```cpp
aReg = aReg$NEXT;
bReg = bReg$NEXT;
io$$b = bReg;
io$$a = aReg;
bReg$NEXT = aReg;
aReg$NEXT = io$$in;
```

也就是说：

1. 先提交 `aReg = aReg$NEXT`
2. 再计算 `bReg$NEXT = aReg`

此时 `bReg$NEXT` 读到的是已经提交后的 `aReg`，而不是本拍开始时的旧值。

这与 Verilog 非阻塞赋值语义不一致，是该最小案例的根因。
