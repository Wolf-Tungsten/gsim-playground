# build_xs_gsim_emu.sh 构建失败根因分析

## 1. 错误现象

执行 `./build_xs_gsim_emu.sh` 时，构建流程在 **PGO（Profile-Guided Optimization）训练阶段** 异常终止，返回错误码 `134`（`SIGABRT`）。

### 关键日志节选

```text
Training emu with PGO Workload...
Error:
cycles: PMU Hardware doesn't support sampling/overflow-interrupts. Try 'perf stat'
-e [31mlinux-perf is not available, fallback to instrumentation-based PGO[0m
BOLT-INFO: shared object or position-independent executable detected
...
BOLT-INFO: setting __hot_end to 0x77275b8
Aborted (core dumped)
make[3]: *** [gsim.mk:139: gsim-gen-emu] Error 134
make[2]: *** [gsim.mk:164: gsim-emu] Error 2
make[1]: *** [emu.mk:87: emu] Error 2
make: *** [Makefile:344: gsim] Error 2
```

---

## 2. 根本原因

**直接原因**：`emu.instrumented` 运行时找不到 PGO workload 文件，触发 `FileReader` 构造函数中的断言失败，进程被强制 `abort()`。

**深层原因**：`build_xs_gsim_emu.sh` 传入的 `--pgo` 参数是**相对路径**（`ready-to-run/coremark-2-iteration.bin`），而 `gsim.mk` 在 BOLT instrumentation fallback 分支中执行 `emu.instrumented` 时，当前工作目录是 `XiangShan/difftest/`，并非 `XiangShan/`。相对路径在此工作目录下失效。

---

## 3. 错误触发链

```
build_xs_gsim_emu.sh
    │
    ▼
xiangshan.py --build --pgo ready-to-run/coremark-2-iteration.bin
    │
    ▼
将 PGO_WORKLOAD=ready-to-run/coremark-2-iteration.bin 传给 make
    │
    ▼
make 在 XiangShan/difftest/ 目录下执行 gsim.mk 的 gsim-gen-emu 目标
    │
    ▼
PGO_BOLT 默认为 1（系统已安装 llvm-bolt）
    │
    ▼
构建 emu.pre-bolt 成功
    │
    ▼
尝试 perf record 采集 profile
    │
    ▼
当前环境 PMU 不支持 sampling/overflow-interrupts → perf record 失败
    │
    ▼
进入 fallback 分支：llvm-bolt -instrument 生成 emu.instrumented
    │
    ▼
直接执行 $(GSIM_EMU_PGO_DIR)/emu.instrumented -i $(PGO_WORKLOAD) ...
    │
    ▼
工作目录 = difftest/，文件 ready-to-run/coremark-2-iteration.bin 不存在
    │
    ▼
ram.cpp:202 FileReader 断言失败 (assert(0)) → SIGABORT → 构建失败
```

### 运行时错误日志确认

`pgo/1775028051.err` 中明确记录了断言失败：

```text
Cannot open 'ready-to-run/coremark-2-iteration.bin'
emu.instrumented: .../ram.cpp:202: FileReader::FileReader(const char *): Assertion `0' failed.
```

---

## 4. 代码定位

### 4.1 触发点：gsim.mk BOLT fallback 分支

文件：`XiangShan/difftest/gsim.mk`（约第 139-152 行）

```makefile
@((perf record -j any,u -o $(GSIM_EMU_PGO_DIR)/perf.data -- sh -c "\
    $(GSIM_EMU_TARGET).pre-bolt -i $(PGO_WORKLOAD) --max-cycles=$(PGO_MAX_CYCLE) \
        ...") && \
    perf2bolt ...) || \
    (echo -e "\033[31mlinux-perf is not available, fallback to instrumentation-based PGO\033[0m" && \
    $(LLVM_BOLT) $(GSIM_EMU_TARGET).pre-bolt \
        -instrument --instrumentation-file=$(GSIM_EMU_PGO_DIR)/perf.fdata \
        -o $(GSIM_EMU_PGO_DIR)/emu.instrumented && \
    $(GSIM_EMU_PGO_DIR)/emu.instrumented -i $(PGO_WORKLOAD) --max-cycles=$(PGO_MAX_CYCLE) \
        ...)
```

**问题**：`perf record` 通过 `sh -c` 执行时，工作目录继承 `difftest/`；而 fallback 分支直接调用 `$(GSIM_EMU_PGO_DIR)/emu.instrumented`，工作目录同样是 `difftest/`。当 `PGO_WORKLOAD` 为相对路径时，两者都无法正确解析文件位置。

### 4.2 路径传入点

文件：`build_xs_gsim_emu.sh`（第 74 行）

```bash
--pgo ready-to-run/coremark-2-iteration.bin \
```

文件：`XiangShan/scripts/xiangshan.py`（第 102、150 行）

```python
self.pgo = args.pgo          # 直接保存原始字符串，未做绝对路径转换
...
(self.pgo, "PGO_WORKLOAD"),  # 直接传给 Makefile
```

---

## 5. 影响范围

同样的路径解析 bug 也存在于 **Verilator 构建流程** 中：

- 文件：`XiangShan/difftest/verilator.mk`（约第 212 行）
- 问题描述完全一致：BOLT fallback 分支直接执行 `$(VERILATOR_PGO_DIR)/emu.instrumented -i $(PGO_WORKLOAD)`，未处理相对路径与工作目录不一致的问题。

此外，`gsim.mk` 和 `verilator.mk` 中 **非 BOLT 的 PGO 分支**（`PGO_BOLT=0`）也存在类似风险：它们直接执行 `$(GSIM_EMU_TARGET) -i $(PGO_WORKLOAD)` 或 `$(VERILATOR_TARGET) -i $(PGO_WORKLOAD)`，工作目录同样是 `difftest/`。

---

## 6. 修复建议

### 方案 A：修改构建脚本（最快绕过）

在 `build_xs_gsim_emu.sh` 中，将 `--pgo` 参数改为绝对路径：

```bash
--pgo "${NOOP_HOME}/ready-to-run/coremark-2-iteration.bin" \
```

**优点**：改动最小，可立即恢复构建。  
**缺点**：未修复框架层面的 bug，其他用户或脚本若传入相对路径仍会触发。

### 方案 B：修改 xiangshan.py（推荐）

在 `XiangShan/scripts/xiangshan.py` 中，将 `self.pgo` 转换为绝对路径：

```python
if args.pgo and not os.path.isabs(args.pgo):
    self.pgo = os.path.abspath(os.path.join(self.noop_home, args.pgo))
else:
    self.pgo = args.pgo
```

**优点**：在框架入口统一处理路径问题，所有下游 Makefile 都能收到正确的绝对路径。  
**缺点**：需要修改 XiangShan 子模块代码。

### 方案 C：修改 Makefile

在 `gsim.mk` 和 `verilator.mk` 中，执行 `emu.instrumented` 或 `emu.pre-bolt` 前，显式切换到正确的工作目录：

```makefile
cd $(DESIGN_DIR) && $(GSIM_EMU_TARGET).pre-bolt -i $(PGO_WORKLOAD) ...
```

或：

```makefile
cd $(DESIGN_DIR) && $(GSIM_EMU_PGO_DIR)/emu.instrumented -i $(PGO_WORKLOAD) ...
```

**优点**：在构建系统层修复，不依赖上游传入绝对路径。  
**缺点**：需要同时修改 `gsim.mk` 和 `verilator.mk` 的多个分支，改动面稍大。

---

## 7. 验证方法

1. 临时将 `build_xs_gsim_emu.sh` 中的 `--pgo` 改为绝对路径：
   ```bash
   --pgo "${NOOP_HOME}/ready-to-run/coremark-2-iteration.bin"
   ```
2. 重新运行脚本，观察 `pgo/` 目录下的 `.err` 日志是否不再出现 `Cannot open ...` 和 `Assertion '0' failed`。
3. 若 workload 能正常加载，PGO 训练流程即可顺利完成。
