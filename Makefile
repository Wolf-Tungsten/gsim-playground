#***************************************************************************************
# Makefile for building GSIM and DRAMsim3 submodules
#***************************************************************************************

# Default number of parallel jobs
JOBS ?= $(shell nproc 2>/dev/null || echo 4)

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
	@echo "  JOBS=<n>        - Number of parallel jobs (default: $(JOBS))"
	@echo ""
	@echo "Examples:"
	@echo "  make build-gsim JOBS=8"
	@echo "  make build-dramsim3"
	@echo "  make build-all JOBS=16"
