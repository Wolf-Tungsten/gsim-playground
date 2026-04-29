# gsim-playground
GSIM develop playground

## Waveform Dump for XiangShan

Waveform dumping is enabled in two steps: build the simulator with trace support, then pass waveform options at runtime.

* Verilator uses `make -C XiangShan emu EMU_TRACE=fst`.
* GSIM uses `make -C XiangShan gsim GSIM=1 EMU_TRACE=fst`.
* GSIM waveform output is written by `XiangShan/build/gsim-compile/emu`.
* Use `--dump-wave` to dump waveform values in the active log range.
* Use `--dump-wave-full` if you need the fuller dump mode.
* Use `--wave-path=...` to force the output under the project directory instead of `/tmp`.
* Do not use `--enable-fork` when dumping waves; the simulator disables waveform dumping in fork mode.
* `XiangShan/scripts/xiangshan.py` does not currently forward `--dump-wave`, `--wave-path`, or `-C`, so direct `emu` invocation is the reliable path for wave capture.

Example: dump a 20k-cycle GSIM waveform to the project directory:

```bash
mkdir -p XiangShan/build/waves
make -C XiangShan gsim GSIM=1 EMU_TRACE=fst
XiangShan/build/gsim-compile/emu \
  -i XiangShan/ready-to-run/coremark-2-iteration.bin \
  --diff XiangShan/ready-to-run/riscv64-nemu-interpreter-so \
  -C 20000 \
  --dump-wave \
  --wave-path XiangShan/build/waves/coremark-2-iteration-gsim-20k.fst
```

Example: dump a 20k-cycle Verilator waveform to the project directory:

```bash
mkdir -p XiangShan/build/waves
make -C XiangShan emu EMU_TRACE=fst
XiangShan/build/emu \
  -i XiangShan/ready-to-run/coremark-2-iteration.bin \
  --diff XiangShan/ready-to-run/riscv64-nemu-interpreter-so \
  -C 20000 \
  --dump-wave \
  --wave-path XiangShan/build/waves/coremark-2-iteration-verilator-20k.fst
```

The generated FST file can be opened directly in GTKWave, or converted with `fst2vcd` if VCD is required.

## Difftest Change Summary

For `XiangShan/difftest`, the current local code change that should be reviewed by difftest maintainers is:

* Branch: `grh/dev-gsim-waveform-support`
* HEAD: `c7a43c95bd9f9212f20c9419c10c8bb9aa839150` (`c7a43c95 feat: add gsim waveform support`)
* File: `XiangShan/difftest/src/test/csrc/gsim/gsim.cpp`
* Function: `GsimSim::waveform_tick()`
* Change: replace the previous no-op implementation with `dut->emitAllSignalValues();`

Rationale:

* The XiangShan emulation loop already calls `dut_ptr->waveform_tick()` during waveform dumping.
* On the GSIM path, keeping `waveform_tick()` empty allowed time to advance but did not flush updated signal values into the FST stream.
* The visible symptom was a waveform file that existed but looked effectively all-zero or missing value transitions.

Expected impact:

* Scope is limited to the GSIM waveform path.
* No difftest ABI or CLI change is introduced.
* Normal non-waveform execution is unaffected.

Reviewer focus:

* Confirm that `emitAllSignalValues()` is the correct per-tick hook for GSIM after `SSimTop::step()`.
* Confirm that this does not duplicate time-change records or introduce incorrect ordering in the FST writer.
* Confirm that the larger waveform size is expected, since real value changes are now emitted instead of only time progression.

Validation observed in this playground:

* A 20k-cycle GSIM run of `coremark-2-iteration.bin` generated `XiangShan/build/waves/coremark-2-iteration-gsim-20k.fst`.
* The resulting FST size was about `968 MiB`.
* A spot check after `fst2vcd` conversion showed `timer` incrementing (`0, 1, 2, ...`), which confirms that value changes are now present in the dumped waveform.
