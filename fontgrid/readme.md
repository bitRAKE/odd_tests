> [!WARNING]
> This software was created in partnership with AI.

# FontGrid Demonstration Program

This program demonstrates how to use **flat assembler 2** (`fasm2`) to interface with the Windows GDI+ API. It parses a custom binary configuration block to render an aligned grid of text characters and saves the result as a PNG image.

## Overview

The application is a standalone Windows executable (PE/PE64) that performs the following steps:

1. **Parses Configuration**: Reads dimensions and strings from a hardcoded data block.
2. **Initializes GDI+**: Sets up the Windows graphics library.
3. **Renders Grid**: Draws specified characters into a 2D grid using the *Consolas* font.
4. **Exports Image**: Encodes the resulting bitmap into a PNG file named `output.png`.

## Requirements

* **Assembler**: `fasm2` (flat assembler 2).
* **Include Files**: Standard `win32a.inc` (for 32-bit) or `win64a.inc` (for 64-bit), typically found in the `fasmg`/`fasm2` include directories.
* **Operating System**: Windows XP or later (requires GDI+).

## Configuration Format

The input data block in the source code controls the output. It follows this structure:

```asm
config_data:
    dd 48, 64       ; [0] Cell Width, Cell Height (pixels)
    dd 3, 4         ; [8] Grid Columns, Grid Rows (characters)
    
    ; Rows of characters (null-terminated strings)
    db '123',0
    db '456',0
    db '789',0
    db ' 0 ',0
    db 0            ; terminator

```

* **Cell Width/Height**: The pixel dimensions for each character cell.
* **Grid Columns/Rows**: The layout of the character grid.
* **Strings**: ASCII strings representing the rows of the keypad/grid. The parser expects one string per row.

## How to Build

### 32-bit Version (`fontgrid.asm`)

```bash
fasm2 x86\fontgrid.asm
```

### 64-bit Version (`fontgrid64.asm`)

```bash
fasm2 x64\fontgrid.asm
```

## How to Run

1. Compile the source code using the commands above.
2. Run the resulting `fontgrid.exe`.
3. The program will run silently and terminate.
4. Check the directory for the generated `output.png` file.

## Technical Details

* **GDI+ Interface**: The code manually manages GDI+ objects including `Bitmap`, `Graphics`, `FontFamily`, and `SolidBrush`.
* **Image Encoding**: It searches the system encoders for the `image/png` MIME type to retrieve the correct CLSID for saving.
* **x64 Calling Convention**: The 64-bit version correctly handles the Microsoft x64 calling convention, including:
* Aligning the stack to 16 bytes.
* Passing floating-point arguments (font size) in XMM registers.
* Using SSE instructions for float conversions.
* Defining the `ImageCodecInfo` structure to ensure correct alignment and offsets.

## License

This is a demonstration program provided "as-is" for educational purposes regarding `fasm2` and Windows API integration.
