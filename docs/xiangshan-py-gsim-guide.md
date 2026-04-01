# XiangShan 仿真测试指南

本文档介绍如何使用 `xiangshan.py` 脚本以及如何使用 GSIM 进行仿真测试，特别是 SPEC CPU 检查点（checkpoint）测试。

## 目录

1. [xiangshan.py 脚本概述](#xiangshanpy-脚本概述)
2. [环境准备](#环境准备)
3. [基本使用方法](#基本使用方法)
4. [使用 GSIM 进行仿真](#使用-gsim-进行仿真)
5. [SPEC CPU 检查点测试](#spec-cpu-检查点测试)
6. [CI 测试类型](#ci-测试类型)
7. [高级配置选项](#高级配置选项)

---

## xiangshan.py 脚本概述

`xiangshan.py` 是 XiangShan 项目的 Python 包装脚本，位于 `XiangShan/scripts/xiangshan.py`。它提供了统一的接口来：

- 生成 Verilog/Chirrtl 代码
- 构建仿真器（emu）
- 运行测试用例
- 执行 CI 测试

### 环境变量

脚本会自动设置以下环境变量：

| 环境变量 | 默认值 | 说明 |
|---------|-------|------|
| `NOOP_HOME` | 脚本所在目录的父目录 | XiangShan 项目根目录 |
| `NEMU_HOME` | `$NOOP_HOME/../NEMU` | NEMU 模拟器路径 |
| `AM_HOME` | `$NOOP_HOME/../nexus-am` | Nexus-AM 路径 |
| `DRAMSIM3_HOME` | `$NOOP_HOME/../DRAMsim3` | DRAMsim3 路径 |
| `RVTEST_HOME` | `$NOOP_HOME/../riscv-tests` | RISC-V 测试路径 |

---

## 环境准备

### 1. 初始化子模块

```bash
cd XiangShan
make init
```

或强制初始化（CI 推荐）：

```bash
make init-force
```

### 2. 安装 GSIM（可选，如使用 gsim 仿真器）

GSIM 是一个快速的 RTL 仿真器，接受 Chirrtl 输入并编译为 C++。

**依赖项：**
- GMP (GNU Multiple Precision Arithmetic Library)
- Clang 19 或更高版本

**安装步骤：**

```bash
cd gsim
make init          # 初始化子模块
make build-gsim    # 构建 GSIM
```

构建后的二进制文件位于 `gsim/build/gsim/gsim`。

---

## 基本使用方法

### 命令格式

```bash
python3 scripts/xiangshan.py [workload] [options]
```

### 常用操作

#### 1. 生成 Verilog

```bash
# 生成 FPGA 用 Verilog
python3 scripts/xiangshan.py --generate

# 生成仿真用 Verilog（含 difftest 逻辑）
python3 scripts/xiangshan.py --vcs-gen

# 指定配置生成
python3 scripts/xiangshan.py --generate --config CHIConfig
```

#### 2. 构建仿真器

**使用 Verilator（默认）：**

```bash
# 基本构建
python3 scripts/xiangshan.py --build

# 指定线程数
python3 scripts/xiangshan.py --build --threads 8

# Release 模式（更快仿真速度）
python3 scripts/xiangshan.py --build --release

# 启用波形输出
python3 scripts/xiangshan.py --build --trace-fst
```

**使用 GSIM：**

```bash
python3 scripts/xiangshan.py --build --emulator gsim
```

#### 3. 运行测试

```bash
# 运行指定 workload
python3 scripts/xiangshan.py /path/to/workload.bin

# 限制最大指令数
python3 scripts/xiangshan.py /path/to/workload.bin --max-instr 10000000

# 禁用 difftest
python3 scripts/xiangshan.py /path/to/workload.bin --no-diff
```

#### 4. 清理构建

```bash
python3 scripts/xiangshan.py --clean
```

---

## 使用 GSIM 进行仿真

GSIM 是 XiangShan 支持的高性能仿真器，相比 Verilator 在某些场景下具有更好的性能。

### 构建 GSIM 仿真器

```bash
# 基本构建
python3 scripts/xiangshan.py --build --emulator gsim

# 完整配置（推荐）
python3 scripts/xiangshan.py --build \
    --emulator gsim \
    --yaml-config src/main/resources/config/Default.yml \
    --with-dramsim3 --dramsim3 /path/to/DRAMsim3 \
    --threads 1 \
    --trace-fst
```

**注意：** GSIM 当前建议单线程构建（`--threads 1`），因为多线程支持仍在完善中。

### GSIM 特有构建选项

| 选项 | 说明 |
|-----|------|
| `--emulator gsim` | 使用 GSIM 作为仿真器 |
| `--pgo <workload>` | 启用 Profile-Guided Optimization |
| `--llvm-profdata` | 指定 llvm-profdata 路径（使用 Clang 时需要） |

### PGO 优化构建示例

```bash
python3 scripts/xiangshan.py --build \
    --emulator gsim \
    --yaml-config src/main/resources/config/Default.yml \
    --with-dramsim3 --dramsim3 /nfs/home/share/ci-workloads/DRAMsim3 \
    --pgo ready-to-run/coremark-2-iteration.bin \
    --llvm-profdata llvm-profdata \
    --trace-fst
```

### 运行 GSIM 仿真

```bash
# 基本运行
python3 scripts/xiangshan.py /path/to/workload.bin --threads 1

# 使用 NUMA 绑定（推荐用于性能测试）
python3 scripts/xiangshan.py /path/to/workload.bin --threads 1 --numa

# 限制指令数并保存波形
python3 scripts/xiangshan.py /path/to/workload.bin \
    --threads 1 \
    --numa \
    --max-instr 5000000 \
    --wave-dump /path/to/wave
```

---

## SPEC CPU 检查点测试

SPEC CPU 检查点（Checkpoint）是 XiangShan 性能测试的标准方法。检查点保存了程序执行到某一时刻的完整状态，可以从该点快速恢复执行。

### 检查点类型

项目中常用的检查点路径：

| 路径 | 说明 |
|-----|------|
| `/nfs/home/share/checkpoints_profiles/spec06_rv64gcb_o2_20m/take_cpt` | SPEC06 GCC O2 优化 |
| `/nfs/home/share/checkpoints_profiles/spec06_rv64gcb_o3_20m/take_cpt` | SPEC06 GCC O3 优化 |
| `/nfs/home/share/checkpoints_profiles/spec17_rv64gcb_o2_20m/take_cpt` | SPEC17 GCC O2 优化 |
| `/nfs/home/share/checkpoints_profiles/spec06_gcc15_rv64gcb_base_260122/checkpoint-0-0-0` | GCC 15 编译的检查点 |

### 运行单个 SPEC 检查点

```bash
# 直接指定检查点文件
python3 scripts/xiangshan.py \
    /nfs/home/share/checkpoints_profiles/spec06_gcc15_rv64gcb_base_260122/checkpoint-0-0-0/mcf/6388/6388.zstd \
    --threads 1 \
    --numa \
    --max-instr 5000000 \
    --wave-dump /path/to/wave
```

### 使用 GCPT Restore Bin

某些检查点需要配合 gcpt.bin 进行恢复：

```bash
python3 scripts/xiangshan.py \
    /nfs/home/share/ci-workloads/hmmer-Vector/_6598_0.250135_.zstd \
    --threads 1 \
    --numa \
    --max-instr 5000000 \
    --gcpt-restore-bin /nfs/home/share/ci-workloads/fix-gcpt/gcpt.bin
```

### CI 中的 SPEC 测试

xiangshan.py 内置了常用 SPEC 测试的配置：

```bash
# 运行特定的 SPEC 测试
python3 scripts/xiangshan.py --ci mcf --threads 1 --numa --max-instr 5000000
python3 scripts/xiangshan.py --ci xalancbmk --threads 1 --numa --max-instr 5000000
python3 scripts/xiangshan.py --ci astar --threads 1 --numa --max-instr 5000000
```

支持的 SPEC 测试名称：
- `povray`, `mcf`, `xalancbmk`, `gcc`, `namd`, `milc`, `lbm`, `gromacs`, `wrf`, `astar`
- `hmmer-Vector`（需要 gcpt-restore-bin）

### 使用 SimFrontend 运行 SPEC

SimFrontend 是一种理想前端模式，用于评估核心微架构性能：

```bash
# 构建时启用 simfrontend
python3 scripts/xiangshan.py --build \
    --emulator verilator \
    --yaml-config src/main/resources/config/Default.yml \
    --with-dramsim3 --dramsim3 /path/to/DRAMsim3 \
    --simfrontend \
    --trace-fst

# 运行时需要指定 instr-trace
python3 scripts/xiangshan.py \
    --ci astar \
    --threads 8 \
    --numa \
    --max-instr 5000000 \
    --instr-trace astar \
    --gcpt-restore-bin /path/to/gcpt.bin
```

---

## CI 测试类型

### 基础 CI 测试

```bash
# CPU 基础测试
python3 scripts/xiangshan.py --ci cputest

# RISC-V 指令集测试
python3 scripts/xiangshan.py --ci riscv-tests

# 杂项测试
python3 scripts/xiangshan.py --ci misc-tests

# 多核测试
python3 scripts/xiangshan.py --ci mc-tests

# 无 diff 测试
python3 scripts/xiangshan.py --ci nodiff-tests

# Hypervisor 扩展测试
python3 scripts/xiangshan.py --ci rvh-tests

# Vector 扩展测试
python3 scripts/xiangshan.py --ci rvv-test

# F16 测试
python3 scripts/xiangshan.py --ci f16_test
```

### AM 应用测试

```bash
# MicroBench
python3 scripts/xiangshan.py --ci microbench

# CoreMark
python3 scripts/xiangshan.py --ci coremark
python3 scripts/xiangshan.py --ci coremark-1-iteration
```

### Linux 系统测试

```bash
# 单核 Linux
python3 scripts/xiangshan.py --ci linux-hello
python3 scripts/xiangshan.py --ci linux-hello-opensbi

# 多核 Linux
python3 scripts/xiangshan.py --ci linux-hello-smp
python3 scripts/xiangshan.py --ci linux-hello-smp-opensbi
```

---

## 高级配置选项

### 构建选项

| 选项 | 说明 | 示例 |
|-----|------|------|
| `--config` | 指定 XiangShan 配置 | `--config CHIConfig` |
| `--yaml-config` | YAML 配置文件 | `--yaml-config config/Default.yml` |
| `--num-cores` | 核心数 | `--num-cores 2` |
| `--threads` | 仿真器线程数 | `--threads 8` |
| `--make-threads` | Make 编译线程数 | `--make-threads 200` |
| `--release` | Release 模式 | `--release` |
| `--trace` | 启用 VCD 波形 | `--trace` |
| `--trace-fst` | 启用 FST 波形（更小） | `--trace-fst` |
| `--with-dramsim3` | 启用 DRAMsim3 | `--with-dramsim3 --dramsim3 /path/to/DRAMsim3` |
| `--enable-log` | 启用日志 | `--enable-log` |

### 运行时选项

| 选项 | 说明 | 示例 |
|-----|------|------|
| `--max-instr` | 最大执行指令数 | `--max-instr 10000000` |
| `--diff` | 指定 difftest 库 | `--diff ./ready-to-run/riscv64-nemu-interpreter-so` |
| `--no-diff` | 禁用 difftest | `--no-diff` |
| `--numa` | 使用 NUMA 绑定 | `--numa` |
| `--seed` | 随机种子 | `--seed 1234` |
| `--ram-size` | 内存大小 | `--ram-size 8GB` |
| `--disable-fork` | 禁用 LightSSS | `--disable-fork` |
| `--dump-db` | 启用 ChiselDB | `--dump-db` |

### 路径选项

| 选项 | 说明 | 示例 |
|-----|------|------|
| `--nemu` | NEMU 路径 | `--nemu /path/to/NEMU` |
| `--am` | Nexus-AM 路径 | `--am /path/to/nexus-am` |
| `--dramsim3` | DRAMsim3 路径 | `--dramsim3 /path/to/DRAMsim3` |
| `--rvtest` | RISC-V tests 路径 | `--rvtest /path/to/riscv-tests` |
| `--wave-dump` | 波形输出路径 | `--wave-dump /path/to/wave` |

---

## 完整示例

### 示例 1：GSIM 单核性能测试

```bash
cd XiangShan

# 1. 清理并初始化
python3 scripts/xiangshan.py --clean
make init-force

# 2. 构建 GSIM 仿真器
python3 scripts/xiangshan.py --build \
    --emulator gsim \
    --yaml-config src/main/resources/config/Default.yml \
    --with-dramsim3 --dramsim3 /nfs/home/share/ci-workloads/DRAMsim3 \
    --threads 1 \
    --pgo ready-to-run/coremark-2-iteration.bin \
    --llvm-profdata llvm-profdata \
    --trace-fst

# 3. 运行 SPEC 检查点
python3 scripts/xiangshan.py \
    /nfs/home/share/checkpoints_profiles/spec06_gcc15_rv64gcb_base_260122/checkpoint-0-0-0/mcf/6388/6388.zstd \
    --threads 1 \
    --numa \
    --max-instr 5000000 \
    --wave-dump ./wave
```

### 示例 2：多核仿真测试

```bash
# 构建多核仿真器
python3 scripts/xiangshan.py --build \
    --threads 16 \
    --num-cores 2 \
    --with-dramsim3 --dramsim3 /nfs/home/share/ci-workloads/DRAMsim3 \
    --pgo /nfs/home/share/ci-workloads/linux-hello-smp-new/bbl.bin \
    --llvm-profdata llvm-profdata \
    --trace-fst \
    --trace-all

# 运行多核测试
python3 scripts/xiangshan.py \
    --threads 16 \
    --numa \
    --diff ./ready-to-run/riscv64-nemu-interpreter-dual-so \
    --ci mc-tests

# 运行 SMP Linux
python3 scripts/xiangshan.py \
    --threads 16 \
    --numa \
    --diff ./ready-to-run/riscv64-nemu-interpreter-dual-so \
    --ci linux-hello-smp-new
```

### 示例 3：使用 SimFrontend 进行性能评估

```bash
# 构建
python3 scripts/xiangshan.py --build \
    --threads 8 \
    --yaml-config src/main/resources/config/Default.yml \
    --with-dramsim3 --dramsim3 /nfs/home/share/ci-workloads/DRAMsim3 \
    --simfrontend \
    --trace-fst

# 运行 SPEC 测试
python3 scripts/xiangshan.py \
    --numa --threads 8 \
    --max-instr 5000000 \
    --ci astar \
    --instr-trace astar \
    --gcpt-restore-bin /nfs/home/share/ci-workloads/fix-gcpt/gcpt.bin
```

---

## 故障排除

### 常见问题

1. **GSIM 找不到**
   - 确保 GSIM 已构建并添加到 PATH，或设置 `GSIM_BIN` 环境变量

2. **DRAMsim3 路径错误**
   - 使用 `--dramsim3` 指定正确路径

3. **波形文件过大**
   - 使用 `--trace-fst` 替代 `--trace`，FST 格式更紧凑
   - 限制仿真指令数 `--max-instr`

4. **内存不足**
   - 减少 Make 线程数 `--make-threads`
   - 使用 Release 模式 `--release`

5. **difftest 失败**
   - 检查 NEMU 库版本是否匹配
   - 使用 `--no-diff` 临时禁用 difftest 进行调试

---

## 参考资料

- [XiangShan GitHub](https://github.com/OpenXiangShan/XiangShan)
- [GSIM GitHub](https://github.com/OpenXiangShan/GSIM)
- [GSIM 论文 (DAC 2025)](https://github.com/jaypiper/simulator/blob/master/docs/dac-gsim.pdf)
