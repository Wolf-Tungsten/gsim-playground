ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/../..)
REPRO_DIR := $(ROOT)/repro/pipe-collapse-repro

BUILD_DIR := $(ROOT)/build/pipe-collapse-repro
SCALA_BUILD_DIR := $(BUILD_DIR)/scala-classes
GEN_DIR := $(BUILD_DIR)/gen
GSIM_MODEL_DIR := $(BUILD_DIR)/gsim-model
VERILATOR_BUILD_DIR := $(BUILD_DIR)/verilator-build

CACHE_DIR := $(ROOT)/.cache
CCACHE_DIR := $(CACHE_DIR)/ccache/cache
CCACHE_TEMPDIR := $(CACHE_DIR)/ccache/tmp

SRC := $(ROOT)/repro/pipe-collapse-repro/src/main/scala/gsimrepro/PipeCollapseRepro.scala
TB := $(ROOT)/repro/pipe-collapse-repro/tb.cpp
GSIM_BIN := $(ROOT)/gsim/build/gsim/gsim

CCACHE_ENV := CCACHE_DIR=$(CCACHE_DIR) CCACHE_TEMPDIR=$(CCACHE_TEMPDIR)

.PHONY: gen gsim-model gsim-sim run-gsim verilator-sim run-verilator clean

define json_cp
$$(sed -n 's/.*:\(\/[^"]*\)".*/\1/p' $(1) | paste -sd:)
endef

gen:
	mkdir -p $(BUILD_DIR) $(SCALA_BUILD_DIR)
	COMPILER_CP="$(call json_cp,$(ROOT)/XiangShan/out/xiangshan/test/scalaCompilerClasspath.json)"; \
	COMPILE_CP="$(call json_cp,$(ROOT)/XiangShan/out/xiangshan/test/compileClasspath.json)"; \
	PLUGIN="$$(sed -n 's/.*:\(\/[^"]*chisel-plugin[^"]*\.jar\)".*/\1/p' $(ROOT)/XiangShan/out/xiangshan/test/scalacPluginClasspath.json)"; \
	java -cp "$$COMPILER_CP" scala.tools.nsc.Main \
		-cp "$$COMPILE_CP" \
		-d $(SCALA_BUILD_DIR) \
		-Xplugin:$$PLUGIN \
		-language:reflectiveCalls \
		-Ymacro-annotations \
		-Ytasty-reader \
		-deprecation \
		-feature \
		$(SRC); \
	RUNTIME_CP="$(SCALA_BUILD_DIR):$$COMPILE_CP"; \
	java -cp "$$RUNTIME_CP" gsimrepro.PipeCollapseReproMain \
		--target systemverilog \
		--split-verilog \
		--dump-fir \
		--target-dir $(GEN_DIR)

gsim-model: gen
	mkdir -p $(GSIM_MODEL_DIR)
	$(GSIM_BIN) --dir $(GSIM_MODEL_DIR) $(GEN_DIR)/PipeCollapseRepro.fir

gsim-sim: gsim-model $(TB)
	clang++ -std=c++20 -DGSIM -I$(GSIM_MODEL_DIR) \
		$(TB) $(GSIM_MODEL_DIR)/PipeCollapseRepro0.cpp \
		-o $(BUILD_DIR)/gsim-sim

run-gsim: gsim-sim
	$(BUILD_DIR)/gsim-sim

verilator-sim: gen $(TB)
	mkdir -p $(CCACHE_DIR) $(CCACHE_TEMPDIR)
	$(CCACHE_ENV) verilator --cc --exe --build \
		--Mdir $(VERILATOR_BUILD_DIR) \
		-CFLAGS -DVERILATOR \
		$(TB) $(GEN_DIR)/PipeCollapseRepro.sv

run-verilator: verilator-sim
	$(VERILATOR_BUILD_DIR)/VPipeCollapseRepro

clean:
	rm -rf $(BUILD_DIR)
