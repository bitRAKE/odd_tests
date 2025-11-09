#!/usr/bin/env python3
# cv2dwarf.py — Convert Windows COFF+CodeView assembly to Linux ELF+DWARF assembly.
# Updated: cross‑ref aware; robust .cv_loc; optional ELF COMDAT grouping.
#
# Key transforms:
#   - .cv_file N "path"          -> .file N "path"
#   - .cv_loc FID FILE LINE [COL] -> .loc FILE LINE [COL]   (FID dropped; flags preserved)
#   - .cv_func_id / .cv_linetable -> removed
#   - .seh_proc / .seh_endproc   -> .cfi_startproc / .cfi_endproc
#   - .section .drectve ...      -> removed
#   - .section .text$NAME,...    ->
#         * default: ".text" (strip COMDAT)
#         * --elf-comdat=group: '.section .text.NAME,"axG",@progbits,SIG,comdat'
#            SIG = associated symbol if present, else NAME
#   - Optional: --strip-seh removes raw .xdata/.pdata sections
#   - Optional: --map-rdata maps '.rdata' -> '.rodata'
#
# Non-goals:
#   - No CodeView type → DWARF type translation
#   - No TLS model remapping
#   - No automatic .type/.size emission
#
import sys, re, argparse
from pathlib import Path

# ---------- Regexes ----------

# .cv_file  N "path"
RX_CV_FILE = re.compile(r'^\s*\.cv_file\s+(\d+)\s+"([^"]+)"\s*$', re.IGNORECASE)

# .cv_loc FuncId File Line [Col] [flags...]
RX_CV_LOC = re.compile(
    r'^\s*\.cv_loc\s+(\d+)\s+(\d+)\s+(\d+)(?:\s+(\d+))?(.*)$',
    re.IGNORECASE
)

# .cv_func_id ...  and  .cv_linetable ...
RX_CV_FUNC_ID = re.compile(r'^\s*\.cv_func_id\b.*$', re.IGNORECASE)
RX_CV_LINETABLE = re.compile(r'^\s*\.cv_linetable\b.*$', re.IGNORECASE)

# .seh_proc foo   /   .seh_endproc
RX_SEH_PROC = re.compile(r'^\s*\.seh_proc\b.*$', re.IGNORECASE)
RX_SEH_END  = re.compile(r'^\s*\.seh_endproc\b.*$', re.IGNORECASE)

# .section .drectve ...
RX_DRECTVE = re.compile(r'^\s*\.section\s+\.drectve\b.*$', re.IGNORECASE)

# .section .text$NAME,"xr",discard[,ASSOC]
# Capture NAME and trailing tokens to probe for associated symbol.
RX_TEXT_DOLLAR = re.compile(
    r'^\s*\.section\s+\.text\$(?P<name>[A-Za-z0-9_.$@]+)\s*,'
    r'\s*"[^"]*"'                                # flags (ignored here)
    r'(?:\s*,\s*(?P<sel>[A-Za-z0-9_.$@]+))?'     # selection token (e.g., discard)
    r'(?:\s*,\s*(?P<assoc>[A-Za-z0-9_.$@]+))?'   # associated symbol (e.g., vpowups)
    r'\s*$', re.IGNORECASE
)

# .section .xdata / .section .pdata  (optionally stripped)
RX_SECT_XDATA = re.compile(r'^\s*\.section\s+\.xdata\b.*$', re.IGNORECASE)
RX_SECT_PDATA = re.compile(r'^\s*\.section\s+\.pdata\b.*$', re.IGNORECASE)

# .section .rdata (optional rename to .rodata)
RX_RDATA = re.compile(r'^\s*\.section\s+\.rdata\b(.*)$', re.IGNORECASE)

# Generic new section line (to stop skipping blocks)
RX_NEW_SECTION = re.compile(r'^\s*\.section\b', re.IGNORECASE)

def convert_lines(lines, *, strip_seh=False, map_rdata=False, elf_comdat='strip'):
    """
    Convert iterable of lines. Returns list of converted lines.
    elf_comdat: 'strip' (default) or 'group'
    """
    out = []
    skip_block = False

    for line in lines:
        raw = line.rstrip('\n')

        # Handle optional skipping of .xdata/.pdata section bodies.
        if strip_seh:
            if not skip_block and (RX_SECT_XDATA.match(raw) or RX_SECT_PDATA.match(raw)):
                skip_block = True
                # drop the section header line
                continue
            if skip_block:
                if RX_NEW_SECTION.match(raw):
                    skip_block = False
                    # fall through to process this new section header
                else:
                    # still inside stripped section
                    continue

        # .cv_file -> .file
        m = RX_CV_FILE.match(raw)
        if m:
            out.append(f'.file {m.group(1)} "{m.group(2)}"')
            continue

        # .cv_loc -> .loc (drop FunctionId)
        m = RX_CV_LOC.match(raw)
        if m:
            file_no = m.group(2)
            line_no = m.group(3)
            col_no  = m.group(4) or '0'
            tail    = m.group(5) or ''
            out.append(f'.loc {file_no} {line_no} {col_no}{tail}')
            continue

        # Drop .cv_func_id / .cv_linetable
        if RX_CV_FUNC_ID.match(raw) or RX_CV_LINETABLE.match(raw):
            continue

        # .seh_proc / .seh_endproc -> CFI
        if RX_SEH_PROC.match(raw):
            out.append('.cfi_startproc')
            continue
        if RX_SEH_END.match(raw):
            out.append('.cfi_endproc')
            continue

        # Drop .drectve
        if RX_DRECTVE.match(raw):
            continue

        # .section .text$NAME ... -> either .text or ELF COMDAT group
        m = RX_TEXT_DOLLAR.match(raw)
        if m:
            name = m.group('name')
            assoc = m.group('assoc') or name
            if elf_comdat == 'group':
                # GAS syntax: .section .text.NAME,"axG",@progbits,SIG,comdat
                out.append(f'.section .text.{name},"axG",@progbits,{assoc},comdat')
            else:
                out.append('.text')
            continue

        # Optional .rdata -> .rodata
        if map_rdata:
            m = RX_RDATA.match(raw)
            if m:
                out.append(f'.section .rodata{m.group(1)}')
                continue

        out.append(raw)

    return out

def convert_text(text, **kw):
    return '\n'.join(convert_lines(text.splitlines(), **kw)) + '\n'

def main():
    ap = argparse.ArgumentParser(description="Convert COFF+CodeView ASM to ELF+DWARF ASM")
    ap.add_argument('inputs', nargs='+', help="Input .S/.asm files or '-' for stdin")
    ap.add_argument('-o', '--output', help="Single output file (only with one input or '-')")
    ap.add_argument('-d', '--outdir', help="Output directory for multiple inputs")
    ap.add_argument('--strip-seh', action='store_true', help="Remove .xdata/.pdata section blocks if present")
    ap.add_argument('--map-rdata', action='store_true', help="Map .rdata to .rodata")
    ap.add_argument('--elf-comdat', choices=['strip','group'], default='strip',
                    help="How to treat '.text$NAME' COFF subsections: strip -> '.text' (default), group -> ELF COMDAT group")
    ap.add_argument('--inplace', action='store_true', help="Rewrite files in place (no -o/-d)")
    args = ap.parse_args()

    if args.output and (len(args.inputs) != 1):
        ap.error("-o/--output only valid with a single input (or '-')")

    if args.inplace and (args.output or args.outdir):
        ap.error("--inplace cannot be combined with -o/--output or -d/--outdir")

    def write_out(dst_path, content):
        Path(dst_path).write_text(content, encoding='utf-8')

    for src in args.inputs:
        if src == '-':
            data = sys.stdin.read()
            out = convert_text(data, strip_seh=args.strip_seh, map_rdata=args.map_rdata, elf_comdat=args.elf_comdat)
            if args.output:
                write_out(args.output, out)
            else:
                sys.stdout.write(out)
            continue

        p = Path(src)
        data = p.read_text(encoding='utf-8')
        out = convert_text(data, strip_seh=args.strip_seh, map_rdata=args.map_rdata, elf_comdat=args.elf_comdat)

        if args.inplace:
            write_out(p, out)
        elif args.output:
            write_out(args.output, out)
        elif args.outdir:
            Path(args.outdir).mkdir(parents=True, exist_ok=True)
            write_out(Path(args.outdir) / p.name, out)
        else:
            # default: alongside with .elf.S suffix
            write_out(p.with_suffix(p.suffix + ".elf.S"), out)

if __name__ == '__main__':
    main()
