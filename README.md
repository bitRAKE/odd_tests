# odd_tests

Miscellaneous low-level experiments, notes, and one-off validation suites. Most of
the checked-in programs target Windows, fasm2/fasmg, or x86 assembly research;
there is no repository-wide build target. Use the per-directory notes and scripts
below as the entry points for the parts that are meant to be rebuilt or rerun.

## Repository map

| Path | Purpose | Entry point / notes |
| --- | --- | --- |
| [`cv2dwarf.py`](cv2dwarf.py), [`cv2dwarf.md`](cv2dwarf.md) | Converts a focused subset of COFF/CodeView assembly directives to ELF/DWARF syntax. | `python cv2dwarf.py --help`; [`cv2dwarf.test.cmd`](cv2dwarf.test.cmd) shows the Windows/Clang smoke test using [`powu/vpowups.S`](powu/vpowups.S). |
| [`hang-suite/`](hang-suite/) | fasmg hang/runaway-allocation corpus for testing caller-side time and memory guards. | See [`hang-suite/README.md`](hang-suite/README.md); `./run.sh [timeout] [/path/to/fasmg.exe]`. |
| [`fontgrid/`](fontgrid/) | GDI+ font-grid PNG rendering examples for fasm2, with x86 and x64 sources. | See [`fontgrid/readme.md`](fontgrid/readme.md); assembles [`fontgrid/x86/fontgrid.asm`](fontgrid/x86/fontgrid.asm) or [`fontgrid/x64/fontgrid.asm`](fontgrid/x64/fontgrid.asm). |
| [`quines/`](quines/) | Tiny fasmg quines and a verification batch file. | See [`quines/readme.md`](quines/readme.md); `_test.cmd` compares generated output. |
| [`ntdll/`](ntdll/) | Windows syscall table and ntdll import experiments. | [`ntdll/makefile`](ntdll/makefile) builds the main examples; generated syscall-table notes live under [`ntdll/x86_64/`](ntdll/x86_64/). |
| [`dbghelp/`](dbghelp/) | DbgHelp notification experiment. | [`dbghelp/notifications.md`](dbghelp/notifications.md) captures expected diagnostic output. |
| [`dd64/`](dd64/) | x64dbg database/debug-data experiment. | [`dd64/readme.md`](dd64/readme.md) notes the relevant x64dbg database setting. |
| [`entryhook/`](entryhook/) | DLL/main executable hook experiment with checked-in response files and makefile. | [`entryhook/makefile`](entryhook/makefile). |
| [`html/`](html/) | fasmg text/state experiments for HTML/error-message data. | Main source: [`html/html_test.asm`](html/html_test.asm). |
| [`powu/`](powu/) | Vector power approximation sources used by the cv2dwarf sample conversion. | [`powu/testing.c`](powu/testing.c), [`powu/vpowups.S`](powu/vpowups.S). |
| [`uiauto/`](uiauto/) | UI Automation assembly experiment. | [`uiauto/uiauto.asm`](uiauto/uiauto.asm). |
| Root assembly/notes | Standalone experiments and reference notes. | Examples: [`features.asm`](features.asm), [`merge.asm`](merge.asm), [`History.of.CPUID.md`](History.of.CPUID.md), [`exp_notes.md`](exp_notes.md). |

## Validation notes

- No single build or test command covers the whole repository.
- Prefer running the smallest documented entry point for the experiment being
  changed.
- On Linux, syntax-level checks are still useful for Python utilities, for
  example:

  ```bash
  python3 -m py_compile cv2dwarf.py
  python3 cv2dwarf.py --help
  ```

- Windows assembly examples generally require the matching local toolchain
  (`fasm2`/`fasmg`, Visual Studio tools, Windows SDK components, or Clang as
  noted by each script).