# TOGA-WA verification

The complete cocotb suite and 17 program datasets are in `cocotb_benches`.
The integrated bench drives the Tiny Tapeout wrapper through `tb.v` and the
streaming SPI RAM model in `cocotb_wrappers` at 50 MHz. It checks program
results, branch targets, data transfers, HALT, reset, and unused output pins.

Run the full CPU program suite inside the Docker environment from the repository
root with `make test-full`. Run component and Python checks with `make test-unit`.
It runs all 17 programs plus four integrated reset/memory-helper checks.

The [programs directory](cocotb_benches/programs) contains the
JSON datasets, assembler/exporter, and dataset checker.
Each JSON file, such as [adder.json](cocotb_benches/programs/adder.json),
defines `code`, `precondition.memory`, and `postcondition.memory`.
For each case, the bench clears the 64 KiB SPI RAM, loads the instructions at
byte address zero and the declared initial data, then releases CPU reset.
The actual RTL executes through the serial SPI RAM model until HALT. The checker
reads back every declared postcondition block and fails on a mismatch, reporting
the program name, block address, actual bytes, and expected bytes. A timeout
also fails the test if the CPU never halts. New JSON datasets are discovered
automatically.

Tests load the JSON datasets directly. Optional HEX exports are generated files
and are excluded from Git. To recreate them from the repository root:

```sh
PYTHONPATH=test python -m cocotb_benches.programs.generate
```

Use Verilator 5.036 or newer, a C++17 compiler, Python, and the packages in
`requirements.txt`. The project uses SystemVerilog interfaces, so RTL simulation
requires Verilator. With those tools on `PATH`, run from the repository root:

```sh
make -C test
make -C test unit
python -m unittest discover -s test/cocotb_benches/programs -t test
```

The component targets `unit-arbiter` and `unit-spi` can also run separately.
The arbiter tests use `cocotb_wrappers/spi_arbiter.sv`, `ideal_spi_ram.sv`,
and `cpp/ideal_mem.cpp`. The SPI-master and integrated tests use the serial
SPI model in `cocotb_wrappers/spi_ram_model.sv`. The integrated RTL and gate-level
tests share `tb.v`, which exercises the Tiny Tapeout pins.

Results are written to `test/results*.xml`. Waveforms are enabled by default;
pass `SIM_ARGS=` to disable runtime tracing for RTL runs. Open
`test/sim_build/rtl/dump.fst` (Verilator) or `test/tb.fst` (Icarus) with GTKWave
or Surfer. Each component's waveform is in its own `sim_build` subdirectory.

GitHub's GDS workflow supplies the powered netlist and PDK to the gate-level
test action automatically. To run the same harness locally after hardening:

```sh
cp runs/wokwi/final/pnl/tt_um_bigjr_mkkong.pnl.v test/gate_level_netlist.v
make -C test GATES=yes PDK_ROOT=/path/to/pdk
```

This uses the template's GF180MCU D / 7-track cell models and Icarus for functional
gate simulation; it does not annotate SDF. Internal
RTL monitors and the three reset tests that inspect internal state are skipped
in gate mode; public pin, HALT, SPI, and program-memory checks remain active.
