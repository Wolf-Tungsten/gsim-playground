#!/bin/bash
#***************************************************************************************
# Run XiangShan GSIM emulator
# Usage: ./run_xs_gsim_emu.sh [WORKLOAD]
#***************************************************************************************

set -e
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NOOP_HOME="${SCRIPT_DIR}/XiangShan"
GSIM_HOME="${SCRIPT_DIR}/gsim"
DRAMSIM3_HOME="${SCRIPT_DIR}/DRAMsim3"

# Default workload
DEFAULT_WORKLOAD="${SCRIPT_DIR}/workload/_49458_0.264720_.zstd"
WORKLOAD="${1:-${DEFAULT_WORKLOAD}}"

# Setup logging
LOG_DIR="${SCRIPT_DIR}/logs"
mkdir -p "${LOG_DIR}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="${LOG_DIR}/run_xs_gsim_emu_${TIMESTAMP}.log"

# Redirect stdout and stderr to both terminal and log file
exec > >(tee -a "${LOG_FILE}") 2>&1

# Add gsim to PATH
if [ -d "${GSIM_HOME}/build/gsim" ]; then
    export PATH="${GSIM_HOME}/build/gsim:${PATH}"
fi

# Export required paths
export NOOP_HOME
export GSIM_HOME
export DRAMSIM3_HOME

echo "============================================"
echo "Running XiangShan GSIM Emulator"
echo "============================================"
echo "NOOP_HOME:     ${NOOP_HOME}"
echo "GSIM_HOME:     ${GSIM_HOME}"
echo "DRAMSIM3_HOME: ${DRAMSIM3_HOME}"
echo "WORKLOAD:      ${WORKLOAD}"
echo "============================================"
echo ""

# Check prerequisites
if [ ! -d "${NOOP_HOME}" ]; then
    echo "Error: XiangShan not found at ${NOOP_HOME}"
    exit 1
fi

if [ ! -f "${NOOP_HOME}/build/emu" ]; then
    echo "Error: Emulator not found at ${NOOP_HOME}/build/emu"
    echo "Please run ./build_xs_gsim_emu.sh first."
    exit 1
fi

if [ ! -f "${WORKLOAD}" ]; then
    echo "Error: Workload not found at ${WORKLOAD}"
    exit 1
fi

# Run XiangShan emulator
cd "${NOOP_HOME}"

python3 scripts/xiangshan.py \
    --emulator gsim \
    --with-dramsim3 \
    --dramsim3 "${DRAMSIM3_HOME}" \
    --trace-fst \
    "${WORKLOAD}"
