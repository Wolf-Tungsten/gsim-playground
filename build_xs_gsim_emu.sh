#!/bin/bash
#***************************************************************************************
# Build XiangShan GSIM emulator
# Usage: ./build_xs_gsim_emu.sh
#***************************************************************************************

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NOOP_HOME="${SCRIPT_DIR}/XiangShan"
GSIM_HOME="${SCRIPT_DIR}/gsim"
DRAMSIM3_HOME="${SCRIPT_DIR}/DRAMsim3"

# Add gsim to PATH
if [ -d "${GSIM_HOME}/build/gsim" ]; then
    export PATH="${GSIM_HOME}/build/gsim:${PATH}"
fi

# Export required paths
export NOOP_HOME
export GSIM_HOME
export DRAMSIM3_HOME

echo "============================================"
echo "Building XiangShan GSIM Emulator"
echo "============================================"
echo "NOOP_HOME:     ${NOOP_HOME}"
echo "GSIM_HOME:     ${GSIM_HOME}"
echo "DRAMSIM3_HOME: ${DRAMSIM3_HOME}"
echo "============================================"
echo ""

# Check prerequisites
if [ ! -d "${NOOP_HOME}" ]; then
    echo "Error: XiangShan not found at ${NOOP_HOME}"
    exit 1
fi

if [ ! -d "${GSIM_HOME}" ]; then
    echo "Error: gsim not found at ${GSIM_HOME}"
    exit 1
fi

if [ ! -d "${DRAMSIM3_HOME}" ]; then
    echo "Error: DRAMsim3 not found at ${DRAMSIM3_HOME}"
    exit 1
fi

# Build GSIM if needed
if [ ! -f "${GSIM_HOME}/build/gsim/gsim" ]; then
    echo "Building GSIM..."
    make -C "${SCRIPT_DIR}" build-gsim
    echo ""
fi

# Build DRAMsim3 if needed
if [ ! -f "${DRAMSIM3_HOME}/build/libdramsim3.so" ]; then
    echo "Building DRAMsim3..."
    make -C "${SCRIPT_DIR}" build-dramsim3
    echo ""
fi

# Build XiangShan emulator
echo "Building XiangShan GSIM emulator..."
cd "${NOOP_HOME}"

python3 scripts/xiangshan.py --build \
    --emulator gsim \
    --threads 1 \
    --yaml-config src/main/resources/config/Default.yml \
    --with-dramsim3 \
    --dramsim3 "${DRAMSIM3_HOME}" \
    --trace-fst \
    --pgo "${NOOP_HOME}/ready-to-run/coremark-2-iteration.bin" \
    --llvm-profdata llvm-profdata

echo ""
echo "============================================"
echo "Build Complete!"
echo "Emulator: ${NOOP_HOME}/build/emu"
echo "============================================"
