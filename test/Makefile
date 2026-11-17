# Makefile
# See https://docs.cocotb.org/en/stable/quickstart.html for more info

# defaults
ifeq ($(GATES),yes)
SIM ?= icarus
else
SIM ?= verilator
endif
FST ?= -fst # Use more efficient FST format
TOPLEVEL_LANG ?= verilog
SRC_DIR = $(abspath ../src)
PROJECT_SOURCES = $(shell cat $(SRC_DIR)/rtl.flist)
export PYTHONPATH := $(CURDIR):$(PYTHONPATH)
export GATES

ifeq ($(SIM),verilator)
COMPILE_ARGS += -Wno-fatal --trace-fst --trace-structs -CFLAGS -std=c++17
SIM_ARGS += --trace --trace-file $(SIM_BUILD)/dump.fst
endif

ifneq ($(GATES),yes)

# RTL simulation:
SIM_BUILD				= sim_build/rtl
VERILOG_SOURCES += $(addprefix $(SRC_DIR)/,$(PROJECT_SOURCES))

else

# Gate level simulation:
SIM_BUILD				= sim_build/gl
COMPILE_ARGS    += -DGL_TEST
COMPILE_ARGS    += -DFUNCTIONAL
COMPILE_ARGS    += -DUSE_POWER_PINS
COMPILE_ARGS    += -DSIM
COMPILE_ARGS    += -DUNIT_DELAY=\#1
VERILOG_SOURCES += $(PDK_ROOT)/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu7t5v0/verilog/primitives.v
VERILOG_SOURCES += $(PDK_ROOT)/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu7t5v0/verilog/gf180mcu_fd_sc_mcu7t5v0.v

# this gets copied in by the GDS action workflow
VERILOG_SOURCES += $(CURDIR)/gate_level_netlist.v

endif

# Allow sharing configuration between design and testbench via `include`:
COMPILE_ARGS 		+= -I$(SRC_DIR)

# Include the testbench sources:
VERILOG_SOURCES += $(CURDIR)/cocotb_wrappers/spi_ram_model.sv $(CURDIR)/tb.v
CUSTOM_COMPILE_DEPS += $(SRC_DIR)/rtl.flist
TOPLEVEL = tb

# List test modules to run, separated by commas and without the .py suffix:
COCOTB_TEST_MODULES = cocotb_benches.top_module

ifeq ($(MAKECMDGOALS),clean)
.PHONY: clean
clean:
	$(RM) -r sim_build
	$(RM) results*.xml tb.fst tb.vcd
else
include $(shell cocotb-config --makefiles)/Makefile.sim
endif

.PHONY: unit unit-arbiter unit-spi
unit: unit-arbiter unit-spi

UNIT_SOURCES = $(filter-out $(CURDIR)/tb.v,$(VERILOG_SOURCES))
IDEAL_RAM = $(CURDIR)/cocotb_wrappers/ideal_spi_ram.sv $(CURDIR)/cpp/ideal_mem.cpp

unit-arbiter:
	$(MAKE) sim SIM=verilator TOPLEVEL=two2one_spi_arbiter_unit_test \
		COCOTB_TEST_MODULES=cocotb_benches.spi_arbiter \
		SIM_BUILD=sim_build/arbiter COCOTB_RESULTS_FILE=results-arbiter.xml \
		VERILOG_SOURCES="$(UNIT_SOURCES) $(CURDIR)/cocotb_wrappers/spi_arbiter.sv $(IDEAL_RAM)"

unit-spi:
	$(MAKE) sim SIM=verilator TOPLEVEL=spi_master_unit_test \
		COCOTB_TEST_MODULES=cocotb_benches.spi_master \
		SIM_BUILD=sim_build/spi COCOTB_RESULTS_FILE=results-spi.xml \
		VERILOG_SOURCES="$(UNIT_SOURCES) $(CURDIR)/cocotb_wrappers/spi_master.sv"
