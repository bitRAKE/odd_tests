### Usage

```bash
# single file -> explicit output
python cv2dwarf.py vpowups.S -o vpowups.elf.S

# batch -> directory
python cv2dwarf.py a.S b.S c.S -d out_elf/

# stdin -> stdout
python cv2dwarf.py - < vpowups.S > vpowups.elf.S

# optionally remove any stray .xdata/.pdata blocks
python cv2dwarf.py vpowups.S -o vpowups.elf.S --strip-seh
```

### What it converts

* `.cv_file N "path"` → `.file N "path"`
* `.cv_loc  N L C [flags]` → `.loc N L C [flags]`
  keeps `prologue_end` / `epilogue_begin` tokens
* `.cv_func_id ...` → removed
* `.seh_proc name` → `.cfi_startproc`
* `.seh_endproc` → `.cfi_endproc`
* `.section .text$foo,"xr",discard,...` → `.text`
* `.section .drectve ...` → removed
* Leaves `.p2align`, `.globl`, `.intel_syntax` as-is
  Optional `--strip-seh` nukes `.xdata/.pdata` sections if present.






# cv2dwarf — Convert COFF+CodeView Assembly to ELF+DWARF

A tiny source-to-source converter that lets you **author assembly once** (Windows COFF + CodeView) and **emit Linux-ready** (ELF + DWARF) assembly with correct line info and unwind markers. Minimal changes to your authoring style. No compiler plugins. No opaque toolchain magic.

---

## Why

Windows/MSVC-style assembly often embeds:

* **CodeView** line directives (`.cv_file`, `.cv_loc`)
* **SEH** unwind markers (`.seh_proc`, `.seh_endproc`)
* **COFF-specific sections** (e.g., `.section .text$foo,"xr",discard,assoc`)

Linux expects:

* **DWARF** line directives (`.file`, `.loc`)
* **CFI** unwind markers (`.cfi_startproc`, `.cfi_endproc`)
* **ELF sections** (usually just `.text`, `.data`, `.rodata`)

This tool rewrites a **subset of COFF+CodeView directives** to **ELF+DWARF** equivalents so you keep one source and build on both platforms.

---

## Features

* **Line mapping:** `.cv_file` → `.file`, `.cv_loc` → `.loc`
* **Unwind mapping:** `.seh_proc` → `.cfi_startproc`, `.seh_endproc` → `.cfi_endproc`
* **Section cleanup:** `.section .text$foo,"xr",...` → `.text`
* **Linker directives:** drops `.drectve` (not useful on ELF)
* **Optional SEH strip:** `--strip-seh` removes any `.xdata`/`.pdata` blocks if they appear
* **No-op preservation:** leaves `.intel_syntax`, `.globl`, `.p2align` as-is
* **Batch or single-file operation:** outputs to directory, inplace, or stdout

Non-goals (by design):

* Not a full CodeView→DWARF *type* translator
* Not a PDB generator
* Not a general COFF↔ELF assembler converter

---

## Install

Place the script anywhere on your PATH or keep it in your repo.

```
cv2dwarf.py
```

---

## Usage

### Basic

```bash
# Single file → explicit output
python cv2dwarf.py vpowups.S -o vpowups.elf.S

# Batch → directory
python cv2dwarf.py a.S b.S c.S -d out_elf/

# Stdin → stdout
python cv2dwarf.py - < vpowups.S > vpowups.elf.S
```

### Options

* `--strip-seh`
  Remove any `.xdata` and `.pdata` sections if present in the source (rare if you only use `.seh_*`).

* `--inplace`
  Rewrite files in-place (cannot be combined with `-o` or `-d`).

### Defaults

* With **no `-o` or `-d`**, each input `X.S` produces `X.S.elf.S` alongside it.

---

## Supported Transformations

| From (COFF/CodeView)                    | To (ELF/DWARF)               | Notes                                                    |
| --------------------------------------- | ---------------------------- | -------------------------------------------------------- |
| `.cv_file N "path"`                     | `.file N "path"`             | Adds to file table                                       |
| `.cv_loc N LINE COL [flags]`            | `.loc N LINE COL [flags]`    | Keeps tokens like `prologue_end`, `epilogue_begin` as-is |
| `.cv_func_id ...`                       | *(removed)*                  | CV function-id indexing not needed for DWARF             |
| `.seh_proc name`                        | `.cfi_startproc`             | LLVM maps CFI to x64 unwind                              |
| `.seh_endproc`                          | `.cfi_endproc`               | —                                                        |
| `.section .text$foo,"xr",discard,assoc` | `.text`                      | Drops COMDAT/association for ELF                         |
| `.section .drectve ...`                 | *(removed)*                  | Linker directives are COFF-only                          |
| `.xdata` / `.pdata`                     | *(removed by `--strip-seh`)* | Only if you opt in; CFI replaces manual tables           |
| `.p2align`, `.globl`, `.intel_syntax`   | *(unchanged)*                | Portable with LLVM/GAS                                   |

---

## Example

**Input (Windows authoring)**

```asm
.intel_syntax noprefix

.cv_file 1 "vpowups.S"
.cv_func_id 1

.section .text$vpowups,"xr",discard,vpowups
.globl vpowups
.p2align 4
.seh_proc vpowups
vpowups:
  ; ...
  ret
.seh_endproc

.section .drectve
.ascii "-defaultlib:kernel32"
```

**Converted (Linux-ready)**

```asm
.intel_syntax noprefix

.file 1 "vpowups.S"

.text
.globl vpowups
.p2align 4
.cfi_startproc
vpowups:
  ; ...
  ret
.cfi_endproc
```

**Build and inspect**

```bash
# Linux
clang -c -gdwarf-5 -mavx512f vpowups.elf.S -o vpowups.o
llvm-dwarfdump --debug-line vpowups.o
```

---

## Recommended Build Flows

### Windows (authoring and testing)

```bat
clang -c -gcodeview -mavx512f vpowups.S -o vpowups.obj
llvm-readobj --codeview --sections --symbols vpowups.obj
```

### Linux (after conversion)

```bash
python cv2dwarf.py vpowups.S -o vpowups.elf.S
clang -c -gdwarf-5 -mavx512f vpowups.elf.S -o vpowups.o
llvm-objdump -d --no-show-raw-insn vpowups.o
llvm-dwarfdump --debug-info --debug-line vpowups.o
```

---

## Compatibility Notes

* **`.cfi_*`** is portable across ELF/COFF/Mach-O with LLVM. LLVM will synthesize `.pdata/.xdata` on COFF from CFI when assembling for Windows; on ELF it emits DWARF CFIs as expected.
* **Local labels:** Prefer `.Lname:` or numeric labels `1f/1b` for internal jumps. They do not pollute the symbol table.
* **Types and signatures:** If you need debugger-visible prototypes, provide a tiny C/C++ declaration unit and link it; this is outside this converter’s scope.

---

## Validation Checklist

* **Symbols:** `llvm-nm <obj>` → only intended globals are exported
* **Sections:** `llvm-objdump -h <obj>` → `.text` present, no stray `.drectve`
* **Unwind:** `llvm-objdump -h -s -j .eh_frame <obj>` (ELF) or `-j .xdata/.pdata` (COFF) as appropriate
* **Lines:** `llvm-dwarfdump --debug-line <obj>` (ELF) or `llvm-readobj --codeview <obj>` (COFF original)

---

## Known Limitations

* **No CodeView type translation.** This tool only maps **line** and **unwind** surfaces, not rich type info.
* **COMDAT semantics dropped.** `.text$foo` is normalized to `.text`. If you truly rely on COMDAT folding across ELF, you will need ELF comdat groups; this tool does not inject them.
* **Linker directives removed.** `.drectve` is COFF-only. If you depended on automatic library linking, replicate it in your ELF link flags.
* **Hand-authored `.xdata/.pdata`.** If your source contains raw unwind tables, use `--strip-seh` or refactor to `.cfi_*`.

---

## Typical Problems and Fixes

* **“Undefined symbol: `one`” after conversion**
  Caused by COFF associative section declarations like
  `.section .text$foo,"xr",discard,one`
  → Converter rewrites to `.text`, so this symptom should disappear in the ELF output. In the original COFF, ensure the **associated symbol** exists or remove association.

* **No line numbers in DWARF**
  Ensure you compiled with `-gdwarf-5` (or `-g`) and the file has `.file/.loc` after conversion. Verify with `llvm-dwarfdump --debug-line`.

* **Debugger not showing a function boundary**
  Confirm `.cfi_startproc`/`.cfi_endproc` surround the label. The converter maps `.seh_*` to `.cfi_*`; if absent, add them in the source.

---

## Future Expansion

* **ELF COMDAT groups:** Optional mapping from `.text$foo` into ELF `.group` for function-level folding.
* **.rdata → .rodata mapping:** Opt-in normalization for read-only data segments.
* **Symbol visibility controls:** Optional `.hidden`/`.internal` annotations on ELF for internal helpers.
* **Heuristics for `.loc` flags:** Map CodeView prologue/epilogue flags into DWARF line prologue markers (where meaningful).
* **Round-trip mode:** ELF→COFF rewrite to keep symmetry.

---

## Contributing

* Keep transformations **deterministic** and **conservative**.
* Prefer **regex matches anchored at start-of-line**; avoid accidental edits of comments or strings.
* Proposed additions should include:

  * A test input
  * The expected converted output
  * One-liners to validate with LLVM tools

---

## License

MIT

---

## Changelog (suggested)

* **v0.1.0** — Initial public version: CV→DWARF line + unwind, section cleanup, drectve strip.

---

## Appendix: Quick Reference

**Windows authoring flags:**

```
clang -c -gcodeview yourfile.S -o yourfile.obj
```

**Linux build flags:**

```
clang -c -gdwarf-5 yourfile.elf.S -o yourfile.o
```

**Inspection:**

```
llvm-readobj --codeview yourfile.obj
llvm-dwarfdump --debug-line yourfile.o
```
