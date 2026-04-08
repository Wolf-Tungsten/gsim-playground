#***************************************************************************************
# Makefile for building GSIM and DRAMsim3 submodules
#***************************************************************************************

SHELL := /bin/bash

# Default number of parallel jobs
JOBS ?= $(shell nproc 2>/dev/null || echo 4)
ROOT_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
XIANGSHAN_HOME := $(ROOT_DIR)/XiangShan
XIANGSHAN_PY := $(XIANGSHAN_HOME)/scripts/xiangshan.py

#=======================================================================================
# XiangShan GSIM Emulator
#=======================================================================================

ifeq ($(origin XS_GSIM_EMU_VERSION), undefined)
XS_GSIM_EMU_VERSION := $(shell date +%Y%m%d_%H%M%S)
endif
XS_GSIM_EMU_META_ROOT ?= $(ROOT_DIR)/artifacts/xs-gsim-emu
XS_GSIM_EMU_VERSION_DIR ?= $(XS_GSIM_EMU_META_ROOT)/$(XS_GSIM_EMU_VERSION)
XS_GSIM_EMU_BIN ?= $(XS_GSIM_EMU_VERSION_DIR)/emu
XS_GSIM_EMU_MANIFEST ?= $(XS_GSIM_EMU_VERSION_DIR)/build.env
XS_GSIM_EMU_RUN_MANIFEST ?= $(XS_GSIM_EMU_VERSION_DIR)/last-run.env
XS_GSIM_EMU_CURRENT_LINK ?= $(XS_GSIM_EMU_META_ROOT)/current
XS_GSIM_EMU_LOG_ROOT ?= $(ROOT_DIR)/logs/xs-gsim-emu
XS_GSIM_EMU_LOG_DIR ?= $(XS_GSIM_EMU_LOG_ROOT)/$(XS_GSIM_EMU_VERSION)
XS_GSIM_EMU_LOG_PREFIX ?= run_xs_gsim_emu_$(XS_GSIM_EMU_VERSION)
XS_GSIM_EMU_DEFAULT_WORKLOAD ?= $(ROOT_DIR)/workload/_49458_0.264720_.zstd
XS_GSIM_EMU_WORKLOAD ?= $(XS_GSIM_EMU_DEFAULT_WORKLOAD)
XS_GSIM_EMU_SKIP_PGO ?= 1
XS_GSIM_EMU_TRACE_FST ?= 0
XS_GSIM_EMU_MAX_INSTR ?=
XS_GSIM_EMU_PGO_BOLT ?= 0
XS_GSIM_EMU_COMMIT_TRACE ?= 1

ifeq ($(origin XS_VERILATOR_EMU_VERSION), undefined)
XS_VERILATOR_EMU_VERSION := $(shell date +%Y%m%d_%H%M%S)
endif
XS_VERILATOR_EMU_META_ROOT ?= $(ROOT_DIR)/artifacts/xs-verilator-emu
XS_VERILATOR_EMU_VERSION_DIR ?= $(XS_VERILATOR_EMU_META_ROOT)/$(XS_VERILATOR_EMU_VERSION)
XS_VERILATOR_EMU_BIN ?= $(XS_VERILATOR_EMU_VERSION_DIR)/emu
XS_VERILATOR_EMU_MANIFEST ?= $(XS_VERILATOR_EMU_VERSION_DIR)/build.env
XS_VERILATOR_EMU_RUN_MANIFEST ?= $(XS_VERILATOR_EMU_VERSION_DIR)/last-run.env
XS_VERILATOR_EMU_CURRENT_LINK ?= $(XS_VERILATOR_EMU_META_ROOT)/current
XS_VERILATOR_EMU_LOG_ROOT ?= $(ROOT_DIR)/logs/xs-verilator-emu
XS_VERILATOR_EMU_LOG_DIR ?= $(XS_VERILATOR_EMU_LOG_ROOT)/$(XS_VERILATOR_EMU_VERSION)
XS_VERILATOR_EMU_LOG_PREFIX ?= run_xs_verilator_emu_$(XS_VERILATOR_EMU_VERSION)
XS_VERILATOR_EMU_DEFAULT_WORKLOAD ?= $(ROOT_DIR)/workload/_49458_0.264720_.zstd
XS_VERILATOR_EMU_WORKLOAD ?= $(XS_VERILATOR_EMU_DEFAULT_WORKLOAD)
XS_VERILATOR_EMU_SKIP_PGO ?= 1
XS_VERILATOR_EMU_TRACE_FST ?= 0
XS_VERILATOR_EMU_MAX_INSTR ?=
XS_VERILATOR_EMU_PGO_BOLT ?= 0
XS_VERILATOR_EMU_DISABLE_FORK ?= 0
XS_VERILATOR_EMU_COMMIT_TRACE ?= 1

NUM_CORES ?= 1
EMU_THREADS ?= 1
MAKE_THREADS ?= 200
SIM_TOP ?= SimTop
RTL_SUFFIX ?= sv
YAML_CONFIG ?= src/main/resources/config/Default.yml
PGO_WORKLOAD ?= $(ROOT_DIR)/XiangShan/ready-to-run/coremark-2-iteration.bin
LLVM_PROFDATA_BIN ?= llvm-profdata
WITH_CHISELDB ?= 0

TRUE_VALUES := 1 true TRUE yes YES on ON

.PHONY: build-xs-gsim-emu
build-xs-gsim-emu: build-gsim build-dramsim3
	@mkdir -p "$(XS_GSIM_EMU_VERSION_DIR)" "$(XS_GSIM_EMU_LOG_DIR)"
	@echo "Building xs-gsim-emu version: $(XS_GSIM_EMU_VERSION)"
	@cd "$(XIANGSHAN_HOME)" && \
		env PATH="$(ROOT_DIR)/gsim/build/gsim:$$PATH" \
		PGO_BOLT="$(XS_GSIM_EMU_PGO_BOLT)" \
		python3 -u "$(XIANGSHAN_PY)" --build \
			--emulator gsim \
			--num-cores "$(NUM_CORES)" \
			--threads "$(EMU_THREADS)" \
			--make-threads "$(MAKE_THREADS)" \
			--yaml-config "$(YAML_CONFIG)" \
			--with-dramsim3 \
			--dramsim3 "$(ROOT_DIR)/DRAMsim3" \
			$(if $(filter $(TRUE_VALUES),$(XS_GSIM_EMU_TRACE_FST)),--trace-fst,) \
			$(if $(filter $(TRUE_VALUES),$(WITH_CHISELDB)),--dump-db,) \
			$(if $(filter $(TRUE_VALUES),$(XS_GSIM_EMU_SKIP_PGO)),,$(if $(PGO_WORKLOAD),--pgo "$(PGO_WORKLOAD)",)) \
			$(if $(filter $(TRUE_VALUES),$(XS_GSIM_EMU_SKIP_PGO)),,$(if $(LLVM_PROFDATA_BIN),--llvm-profdata "$(LLVM_PROFDATA_BIN)",))
	@EMU_SOURCE="$$(readlink -f "$(XIANGSHAN_HOME)/build/emu")"; \
		if [ ! -x "$$EMU_SOURCE" ]; then \
			echo "Error: built gsim emu not found at $$EMU_SOURCE"; \
			exit 1; \
		fi; \
		install -D -m 755 "$$EMU_SOURCE" "$(XS_GSIM_EMU_BIN)"
	@{ \
		printf 'XS_GSIM_EMU_VERSION=%s\n' "$(XS_GSIM_EMU_VERSION)"; \
		printf 'BUILT_AT=%s\n' "$$(date -Iseconds)"; \
		printf 'EMU_PATH=%s\n' "$(XS_GSIM_EMU_BIN)"; \
		printf 'SOURCE_EMU_PATH=%s\n' "$$(readlink -f "$(XIANGSHAN_HOME)/build/emu")"; \
		printf 'NUM_CORES=%s\n' "$(NUM_CORES)"; \
		printf 'EMU_THREADS=%s\n' "$(EMU_THREADS)"; \
		printf 'MAKE_THREADS=%s\n' "$(MAKE_THREADS)"; \
		printf 'YAML_CONFIG=%s\n' "$(YAML_CONFIG)"; \
		printf 'WITH_CHISELDB=%s\n' "$(WITH_CHISELDB)"; \
		printf 'XS_GSIM_EMU_TRACE_FST=%s\n' "$(XS_GSIM_EMU_TRACE_FST)"; \
		printf 'XS_GSIM_EMU_PGO_BOLT=%s\n' "$(XS_GSIM_EMU_PGO_BOLT)"; \
		printf 'LLVM_PROFDATA_BIN=%s\n' "$(LLVM_PROFDATA_BIN)"; \
		printf 'PGO_WORKLOAD=%s\n' "$(PGO_WORKLOAD)"; \
		printf 'XS_GSIM_EMU_SKIP_PGO=%s\n' "$(XS_GSIM_EMU_SKIP_PGO)"; \
	} > "$(XS_GSIM_EMU_MANIFEST)"
	@ln -sfn "$(XS_GSIM_EMU_VERSION)" "$(XS_GSIM_EMU_CURRENT_LINK)"
	@echo "Build metadata recorded at: $(XS_GSIM_EMU_MANIFEST)"

.PHONY: run-xs-gsim-emu
run-xs-gsim-emu: build-xs-gsim-emu
	@mkdir -p "$(XS_GSIM_EMU_VERSION_DIR)" "$(XS_GSIM_EMU_LOG_DIR)"
	@echo "Running xs-gsim-emu version: $(XS_GSIM_EMU_VERSION)"
	@LOG_FILE="$(XS_GSIM_EMU_LOG_DIR)/$(XS_GSIM_EMU_LOG_PREFIX)_$$(date +%Y%m%d_%H%M%S).log"; \
		echo "Run log: $$LOG_FILE"; \
		ln -sfn "$(XS_GSIM_EMU_BIN)" "$(XIANGSHAN_HOME)/build/emu"; \
		cd "$(XIANGSHAN_HOME)" && \
		set -o pipefail && \
		env PATH="$(ROOT_DIR)/gsim/build/gsim:$$PATH" PGO_BOLT="$(XS_GSIM_EMU_PGO_BOLT)" \
		python3 -u "$(XIANGSHAN_PY)" \
			--emulator gsim \
			--with-dramsim3 \
			--dramsim3 "$(ROOT_DIR)/DRAMsim3" \
			--disable-fork \
			$(if $(filter $(TRUE_VALUES),$(XS_GSIM_EMU_COMMIT_TRACE)),--dump-commit-trace,) \
			$(if $(XS_GSIM_EMU_MAX_INSTR),--max-instr "$(XS_GSIM_EMU_MAX_INSTR)",) \
			"$(XS_GSIM_EMU_WORKLOAD)" \
		2>&1 | tee -a "$$LOG_FILE"
	@{ \
		printf 'XS_GSIM_EMU_VERSION=%s\n' "$(XS_GSIM_EMU_VERSION)"; \
		printf 'RAN_AT=%s\n' "$$(date -Iseconds)"; \
		printf 'WORKLOAD=%s\n' "$(XS_GSIM_EMU_WORKLOAD)"; \
		printf 'XS_GSIM_EMU_MAX_INSTR=%s\n' "$(XS_GSIM_EMU_MAX_INSTR)"; \
		printf 'XS_GSIM_EMU_COMMIT_TRACE=%s\n' "$(XS_GSIM_EMU_COMMIT_TRACE)"; \
		printf 'LOG_DIR=%s\n' "$(XS_GSIM_EMU_LOG_DIR)"; \
		printf 'LOG_PREFIX=%s\n' "$(XS_GSIM_EMU_LOG_PREFIX)"; \
	} > "$(XS_GSIM_EMU_RUN_MANIFEST)"
	@echo "Run metadata recorded at: $(XS_GSIM_EMU_RUN_MANIFEST)"

.PHONY: list-xs-gsim-emu-versions
list-xs-gsim-emu-versions:
	@if [ ! -d "$(XS_GSIM_EMU_META_ROOT)" ]; then \
		echo "No xs-gsim-emu versions recorded."; \
	else \
		find "$(XS_GSIM_EMU_META_ROOT)" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | LC_ALL=C sort; \
	fi

.PHONY: build-xs-verilator-emu
build-xs-verilator-emu: build-dramsim3
	@mkdir -p "$(XS_VERILATOR_EMU_VERSION_DIR)" "$(XS_VERILATOR_EMU_LOG_DIR)"
	@echo "Building xs-verilator-emu version: $(XS_VERILATOR_EMU_VERSION)"
	@cd "$(XIANGSHAN_HOME)" && \
		env PGO_BOLT="$(XS_VERILATOR_EMU_PGO_BOLT)" \
		python3 -u "$(XIANGSHAN_PY)" --build \
			--emulator verilator \
			--num-cores "$(NUM_CORES)" \
			--threads "$(EMU_THREADS)" \
			--make-threads "$(MAKE_THREADS)" \
			--yaml-config "$(YAML_CONFIG)" \
			--with-dramsim3 \
			--dramsim3 "$(ROOT_DIR)/DRAMsim3" \
			$(if $(filter $(TRUE_VALUES),$(XS_VERILATOR_EMU_TRACE_FST)),--trace-fst,) \
			$(if $(filter $(TRUE_VALUES),$(WITH_CHISELDB)),--dump-db,) \
			$(if $(filter $(TRUE_VALUES),$(XS_VERILATOR_EMU_SKIP_PGO)),,$(if $(PGO_WORKLOAD),--pgo "$(PGO_WORKLOAD)",)) \
			$(if $(filter $(TRUE_VALUES),$(XS_VERILATOR_EMU_SKIP_PGO)),,$(if $(LLVM_PROFDATA_BIN),--llvm-profdata "$(LLVM_PROFDATA_BIN)",))
	@EMU_SOURCE="$$(readlink -f "$(XIANGSHAN_HOME)/build/emu")"; \
		if [ ! -x "$$EMU_SOURCE" ]; then \
			echo "Error: built verilator emu not found at $$EMU_SOURCE"; \
			exit 1; \
		fi; \
		install -D -m 755 "$$EMU_SOURCE" "$(XS_VERILATOR_EMU_BIN)"
	@{ \
		printf 'XS_VERILATOR_EMU_VERSION=%s\n' "$(XS_VERILATOR_EMU_VERSION)"; \
		printf 'BUILT_AT=%s\n' "$$(date -Iseconds)"; \
		printf 'EMU_PATH=%s\n' "$(XS_VERILATOR_EMU_BIN)"; \
		printf 'SOURCE_EMU_PATH=%s\n' "$$(readlink -f "$(XIANGSHAN_HOME)/build/emu")"; \
		printf 'NUM_CORES=%s\n' "$(NUM_CORES)"; \
		printf 'EMU_THREADS=%s\n' "$(EMU_THREADS)"; \
		printf 'MAKE_THREADS=%s\n' "$(MAKE_THREADS)"; \
		printf 'YAML_CONFIG=%s\n' "$(YAML_CONFIG)"; \
		printf 'WITH_CHISELDB=%s\n' "$(WITH_CHISELDB)"; \
		printf 'XS_VERILATOR_EMU_TRACE_FST=%s\n' "$(XS_VERILATOR_EMU_TRACE_FST)"; \
		printf 'XS_VERILATOR_EMU_PGO_BOLT=%s\n' "$(XS_VERILATOR_EMU_PGO_BOLT)"; \
		printf 'LLVM_PROFDATA_BIN=%s\n' "$(LLVM_PROFDATA_BIN)"; \
		printf 'PGO_WORKLOAD=%s\n' "$(PGO_WORKLOAD)"; \
		printf 'XS_VERILATOR_EMU_SKIP_PGO=%s\n' "$(XS_VERILATOR_EMU_SKIP_PGO)"; \
	} > "$(XS_VERILATOR_EMU_MANIFEST)"
	@ln -sfn "$(XS_VERILATOR_EMU_VERSION)" "$(XS_VERILATOR_EMU_CURRENT_LINK)"
	@echo "Build metadata recorded at: $(XS_VERILATOR_EMU_MANIFEST)"

.PHONY: run-xs-verilator-emu
run-xs-verilator-emu: build-xs-verilator-emu
	@mkdir -p "$(XS_VERILATOR_EMU_VERSION_DIR)" "$(XS_VERILATOR_EMU_LOG_DIR)"
	@echo "Running xs-verilator-emu version: $(XS_VERILATOR_EMU_VERSION)"
	@LOG_FILE="$(XS_VERILATOR_EMU_LOG_DIR)/$(XS_VERILATOR_EMU_LOG_PREFIX)_$$(date +%Y%m%d_%H%M%S).log"; \
		echo "Run log: $$LOG_FILE"; \
		ln -sfn "$(XS_VERILATOR_EMU_BIN)" "$(XIANGSHAN_HOME)/build/emu"; \
		cd "$(XIANGSHAN_HOME)" && \
		set -o pipefail && \
		env PGO_BOLT="$(XS_VERILATOR_EMU_PGO_BOLT)" \
		python3 -u "$(XIANGSHAN_PY)" \
			--emulator verilator \
			--with-dramsim3 \
			--dramsim3 "$(ROOT_DIR)/DRAMsim3" \
			$(if $(filter $(TRUE_VALUES),$(XS_VERILATOR_EMU_DISABLE_FORK)),--disable-fork,) \
			$(if $(filter $(TRUE_VALUES),$(XS_VERILATOR_EMU_COMMIT_TRACE)),--dump-commit-trace,) \
			$(if $(XS_VERILATOR_EMU_MAX_INSTR),--max-instr "$(XS_VERILATOR_EMU_MAX_INSTR)",) \
			"$(XS_VERILATOR_EMU_WORKLOAD)" \
		2>&1 | tee -a "$$LOG_FILE"
	@{ \
		printf 'XS_VERILATOR_EMU_VERSION=%s\n' "$(XS_VERILATOR_EMU_VERSION)"; \
		printf 'RAN_AT=%s\n' "$$(date -Iseconds)"; \
		printf 'WORKLOAD=%s\n' "$(XS_VERILATOR_EMU_WORKLOAD)"; \
		printf 'XS_VERILATOR_EMU_MAX_INSTR=%s\n' "$(XS_VERILATOR_EMU_MAX_INSTR)"; \
		printf 'XS_VERILATOR_EMU_DISABLE_FORK=%s\n' "$(XS_VERILATOR_EMU_DISABLE_FORK)"; \
		printf 'XS_VERILATOR_EMU_COMMIT_TRACE=%s\n' "$(XS_VERILATOR_EMU_COMMIT_TRACE)"; \
		printf 'LOG_DIR=%s\n' "$(XS_VERILATOR_EMU_LOG_DIR)"; \
		printf 'LOG_PREFIX=%s\n' "$(XS_VERILATOR_EMU_LOG_PREFIX)"; \
	} > "$(XS_VERILATOR_EMU_RUN_MANIFEST)"
	@echo "Run metadata recorded at: $(XS_VERILATOR_EMU_RUN_MANIFEST)"

.PHONY: list-xs-verilator-emu-versions
list-xs-verilator-emu-versions:
	@if [ ! -d "$(XS_VERILATOR_EMU_META_ROOT)" ]; then \
		echo "No xs-verilator-emu versions recorded."; \
	else \
		find "$(XS_VERILATOR_EMU_META_ROOT)" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | LC_ALL=C sort; \
	fi

#=======================================================================================
# GSIM Build
#=======================================================================================

.PHONY: build-gsim
build-gsim:
	@echo "Building GSIM..."
	$(MAKE) -C gsim build-gsim -j$(JOBS)
	@echo "GSIM build complete. Binary located at: gsim/build/gsim/gsim"

#=======================================================================================
# DRAMsim3 Build
#=======================================================================================

DRAMSIM3_BUILD_DIR = DRAMsim3/build

.PHONY: build-dramsim3
build-dramsim3:
	@echo "Building DRAMsim3 with COSIM=1..."
	@mkdir -p $(DRAMSIM3_BUILD_DIR)
	cd $(DRAMSIM3_BUILD_DIR) && cmake -D COSIM=1 ..
	$(MAKE) -C $(DRAMSIM3_BUILD_DIR) -j$(JOBS)
	@echo "DRAMsim3 build complete. Library located at: $(DRAMSIM3_BUILD_DIR)/libdramsim3.so"

#=======================================================================================
# Build All
#=======================================================================================

.PHONY: build-all
build-all: build-gsim build-dramsim3

#=======================================================================================
# Clean
#=======================================================================================

.PHONY: clean-gsim
clean-gsim:
	@echo "Cleaning GSIM build..."
	-$(MAKE) -C gsim clean 2>/dev/null || rm -rf gsim/build

.PHONY: clean-dramsim3
clean-dramsim3:
	@echo "Cleaning DRAMsim3 build..."
	-rm -rf $(DRAMSIM3_BUILD_DIR)

.PHONY: clean
clean: clean-gsim clean-dramsim3

#=======================================================================================
# Init Submodules
#=======================================================================================

.PHONY: init
init:
	git submodule update --init --recursive

#=======================================================================================
# Help
#=======================================================================================

.PHONY: help
help:
	@echo "Available targets:"
	@echo "  build-xs-gsim-emu      - Build XiangShan GSIM emulator and record version metadata"
	@echo "  run-xs-gsim-emu        - Build if needed, run emulator, and record run metadata"
	@echo "  list-xs-gsim-emu-versions - List recorded xs-gsim-emu versions"
	@echo "  build-xs-verilator-emu - Build XiangShan Verilator emulator and record version metadata"
	@echo "  run-xs-verilator-emu   - Build if needed, run Verilator emulator, and record run metadata"
	@echo "  list-xs-verilator-emu-versions - List recorded xs-verilator-emu versions"
	@echo "  build-gsim      - Build GSIM simulator (in gsim/build/gsim/)"
	@echo "  build-dramsim3  - Build DRAMsim3 with COSIM=1 (in DRAMsim3/build/)"
	@echo "  build-all       - Build both GSIM and DRAMsim3"
	@echo "  clean-gsim      - Clean GSIM build artifacts"
	@echo "  clean-dramsim3  - Clean DRAMsim3 build artifacts"
	@echo "  clean           - Clean all build artifacts"
	@echo "  init            - Initialize all submodules"
	@echo "  help            - Show this help message"
	@echo ""
	@echo "Variables:"
	@echo "  XS_GSIM_EMU_VERSION=<name>   - Logical version label for metadata/logs (default: $(XS_GSIM_EMU_VERSION))"
	@echo "  XS_GSIM_EMU_WORKLOAD=<path>  - Runtime workload path (default: $(XS_GSIM_EMU_WORKLOAD))"
	@echo "  XS_GSIM_EMU_SKIP_PGO=1       - Disable PGO during build"
	@echo "  XS_GSIM_EMU_PGO_BOLT=0       - Disable llvm-bolt PGO path by default; use clang/gcc instrumentation PGO instead"
	@echo "  XS_GSIM_EMU_TRACE_FST=1      - Enable --trace-fst when building via xiangshan.py"
	@echo "  XS_GSIM_EMU_MAX_INSTR=<n>    - Pass --max-instr to runtime"
	@echo "  XS_GSIM_EMU_COMMIT_TRACE=1   - Print commit PC trace during gsim runtime (default: enabled)"
	@echo "  XS_VERILATOR_EMU_VERSION=<name> - Logical version label for verilator metadata/logs (default: $(XS_VERILATOR_EMU_VERSION))"
	@echo "  XS_VERILATOR_EMU_WORKLOAD=<path> - Runtime workload path for verilator (default: $(XS_VERILATOR_EMU_WORKLOAD))"
	@echo "  XS_VERILATOR_EMU_SKIP_PGO=1  - Disable PGO during verilator build"
	@echo "  XS_VERILATOR_EMU_PGO_BOLT=0  - Disable llvm-bolt PGO path by default for verilator"
	@echo "  XS_VERILATOR_EMU_TRACE_FST=1 - Enable --trace-fst when building verilator via xiangshan.py"
	@echo "  XS_VERILATOR_EMU_MAX_INSTR=<n> - Pass --max-instr to verilator runtime"
	@echo "  XS_VERILATOR_EMU_DISABLE_FORK=1 - Disable lightSSS fork mode when running verilator emu"
	@echo "  XS_VERILATOR_EMU_COMMIT_TRACE=1 - Print commit PC trace during verilator runtime (default: enabled)"
	@echo "  JOBS=<n>        - Number of parallel jobs (default: $(JOBS))"
	@echo "  NUM_CORES=<n> / EMU_THREADS=<n> / MAKE_THREADS=<n> - Build knobs forwarded to XiangShan/scripts/xiangshan.py"
	@echo ""
	@echo "Examples:"
	@echo "  make build-xs-gsim-emu XS_GSIM_EMU_VERSION=v1"
	@echo "  make build-xs-gsim-emu XS_GSIM_EMU_PGO_BOLT=1"
	@echo "  make run-xs-gsim-emu XS_GSIM_EMU_VERSION=v1 XS_GSIM_EMU_WORKLOAD=$(ROOT_DIR)/workload/foo.zstd"
	@echo "  make build-xs-verilator-emu XS_VERILATOR_EMU_VERSION=v1"
	@echo "  make run-xs-verilator-emu XS_VERILATOR_EMU_VERSION=v1 XS_VERILATOR_EMU_WORKLOAD=$(ROOT_DIR)/workload/foo.zstd"
	@echo "  make list-xs-gsim-emu-versions"
	@echo "  make list-xs-verilator-emu-versions"
	@echo "  make build-gsim JOBS=8"
	@echo "  make build-dramsim3"
	@echo "  make build-all JOBS=16"
