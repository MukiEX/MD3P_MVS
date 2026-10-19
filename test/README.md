# Test harness

These are the tools used to develop and verify the patches. They're kept for
reference and aren't needed to build anything.

- `harness/neo.py`: drives a patched Geolith libretro core headlessly.
  - Its `Spinner` class generates real quadrature on LEFT/RIGHT with emulated
    in-frame timing, plus an optional 1 ms input quantum like MiSTer's USB path.
  - It can watch RAM reads and writes, log sound commands and VRAM writes,
    and save and load states.
  - Address errors are emulated, so odd-address word accesses fault the way
    they do on hardware.
- `../third_party/geolith-harness.patch`: the changes to geolith-libretro (upstream
  commit `2dc88e3`) that the harness needs:
  - debug hooks;
  - address-error emulation;
  - the SOCD filter removed, so LEFT+RIGHT can be held together.
- `harness/util.py`, `ramuse.py`, `m68kdis.py`: loading helpers, RAM-use
  scanning, and a capstone-based disassembler (P ROM via `P_BIN`).

Environment:

```
GEOLITH_CORE=/path/to/geolith_libretro.so
NEOGEO_SYSDIR=/path/to/folder/with/neogeo.zip
PYTHONPATH=test/harness
```

The scripts in `test/<set>/` expect save states (`st_*.pkl` / `pst_*.pkl`)
that aren't in the repo, since they're made from the ROMs.
`test/pbobbl2n/mkstate.py` shows how they're made. Run the scripts from a
folder that holds the states and ROMs.
