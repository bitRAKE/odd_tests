; c:\fasm\fasm2\fasm2 -e 5 fontgrid.asm

format PE GUI 4.0
entry start

include 'win32a.inc'

; Structs for GDI+
struct GdiplusStartupInput
    GdiplusVersion           dd ?
    DebugEventCallback       dd ?
    SuppressBackgroundThread dd ?
    SuppressExternalCodecs   dd ?
ends

; =============================================================
; Data Section: Configuration and Variables
; =============================================================
section '.data' data readable writeable

    ; ---------------------------------------------------------
    ; USER CONFIGURATION BLOCK
    ; ---------------------------------------------------------
    config_data:
        dd 48, 64       ; [0] Width, Height of each cell (pixels)
        dd 3, 4         ; [8] Grid Width, Height (characters)
        
        ; Rows of characters (null-terminated strings)
        db '123',0
        db '456',0
        db '789',0
        db ' 0 ',0
        db 0            ; Terminator for safety

    ; ---------------------------------------------------------
    ; Internal Variables
    ; ---------------------------------------------------------
    ; Unicode for GDI+
    _filename       du 'output.png',0
    _font_family    du 'Consolas',0
    _mime_png       du 'image/png',0

    token           dd ?
    gdiplusInput    GdiplusStartupInput
    encoderClsid    rd 4 ; GUID

    pBitmap         dd ?
    pGraphics       dd ?
    pFamily         dd ?
    pFont           dd ?
    pBrushText      dd ?
    pBrushBg        dd ?

    ; Rendering vars
    cell_w          dd ?
    cell_h          dd ?
    cols            dd ?
    rows            dd ?
    curr_x          dd ?
    curr_y          dd ?
    
    ; RectF structure for drawing (X, Y, Width, Height)
    draw_rect       dd 0.0, 0.0, 0.0, 0.0

; =============================================================
; Code Section
; =============================================================
section '.text' code readable executable

; =============================================================
; Helper: Get Encoder CLSID for MimeType
; =============================================================
proc GetEncoderClsid uses ebx esi edi, _format, clsid
    locals
        numEncoders dd ?
        size        dd ?
        pImageCodecInfo dd ?
    endl

    invoke  GdipGetImageEncodersSize, addr numEncoders, addr size
    test    eax, eax
    jnz     .fail

    invoke  GlobalAlloc, 0x40, [size] ; GPTR
    mov     [pImageCodecInfo], eax
    
    invoke  GdipGetImageEncoders, [numEncoders], [size], [pImageCodecInfo]

    mov     ecx, [numEncoders]
    mov     esi, [pImageCodecInfo]

    .scan:
        push    ecx
        push    esi

        mov     eax, [esi + 48] ; MimeType is at offset 48
        mov     ebx, [_format]
        
        ; Simple string compare (WideChar)
        .strcmp:
            mov     dx, [eax]
            cmp     dx, [ebx]
            jne     .next_encoder
            test    dx, dx
            jz      .found
            add     eax, 2
            add     ebx, 2
            jmp     .strcmp

        .next_encoder:
        pop     esi
        pop     ecx
        add     esi, 76 ; Size of ImageCodecInfo structure
        dec     ecx
        jnz     .scan
        
    .fail:
        invoke  GlobalFree, [pImageCodecInfo]
        mov     eax, -1
        ret

    .found:
        pop     esi ; restore current codec info pointer
        pop     ecx ; balance stack
        
        ; Copy CLSID (offset 0) to destination
        mov     edi, [clsid]
        mov     ecx, 4 ; 16 bytes = 4 dwords
        rep     movsd
        
        invoke  GlobalFree, [pImageCodecInfo]
        xor     eax, eax ; Success
        ret
endp


start:
    ; 1. Initialize GDI+
    mov     [gdiplusInput.GdiplusVersion], 1
    invoke  GdiplusStartup, token, gdiplusInput, NULL
    test    eax, eax
    jnz     .exit

    ; 2. Parse Config Data
    mov     esi, config_data
    lodsd
    mov     [cell_w], eax
    lodsd
    mov     [cell_h], eax
    lodsd
    mov     [cols], eax
    lodsd
    mov     [rows], eax
    ; ESI now points to the first string

    ; Calculate total image size
    mov     eax, [cell_w]
    imul    eax, [cols]
    mov     ebx, [cell_h]
    imul    ebx, [rows]

    ; 3. Create Bitmap (Canvas)
    ; PixelFormat24bppRGB = 0x21808 (defined in headers or magic number)
    invoke  GdipCreateBitmapFromScan0, eax, ebx, 0, 0x21808, NULL, pBitmap
    invoke  GdipGetImageGraphicsContext, [pBitmap], pGraphics

    ; 4. Setup Graphics (Font, Brush, Clear)
    invoke  GdipGraphicsClear, [pGraphics], 0xFFFFFFFF ; White background
    
    ; Create Font: Consolas, Size 32 (approx), Regular Style (0), UnitPixel (2)
    invoke  GdipCreateFontFamilyFromName, _font_family, NULL, pFamily
    invoke  GdipCreateFont, [pFamily], 32.0, 0, 2, pFont
    
    invoke  GdipCreateSolidFill, 0xFF000000, pBrushText ; Black text

    ; 5. Rendering Loop
    mov     edi, 0          ; Row counter
    xor     ecx, ecx
    mov     [curr_y], ecx

.row_loop:
    cmp     edi, [rows]
    jge     .save_image

    mov     [curr_x], 0
    mov     ebx, 0          ; Col counter

    .col_loop:
        cmp     ebx, [cols]
        jge     .next_row_prep

        ; Check for null terminator in string
        mov     al, [esi]
        test    al, al
        jz      .next_row_prep ; End of string line

        ; Setup RectF for this character
        fild    [curr_x]
        fstp    [draw_rect]
        fild    [curr_y]
        fstp    [draw_rect+4]
        fild    [cell_w]
        fstp    [draw_rect+8]
        fild    [cell_h]
        fstp    [draw_rect+12]

        ; Draw the single character (ESI points to it)
        ; -1 length indicates null terminated, but we want 1 char.
        ; Convert char to Unicode? GdipDrawString expects WCHAR.
        ; Quick hack: We use GdipDrawString which needs WCHAR.
        ; We will convert ASCII char to WCHAR buffer on stack.
        xor     eax, eax
        mov     al, [esi]
        push    0           ; Null terminator high byte
        push    ax          ; Char + Null
        mov     edx, esp    ; Pointer to temporary WCHAR string

        invoke  GdipDrawString, [pGraphics], edx, -1, [pFont], draw_rect, NULL, [pBrushText]
        add     esp, 4      ; Restore stack

        ; Advance
        inc     esi
        inc     ebx
        
        mov     eax, [curr_x]
        add     eax, [cell_w]
        mov     [curr_x], eax
        
        jmp     .col_loop

    .next_row_prep:
        ; Skip to the next null terminator in ESI if we exited loop early
        .skip_null:
            cmp     byte [esi], 0
            je      .found_null
            inc     esi
            jmp     .skip_null
        .found_null:
        inc     esi ; Skip the null itself

        inc     edi
        mov     eax, [curr_y]
        add     eax, [cell_h]
        mov     [curr_y], eax
        jmp     .row_loop

    ; 6. Save to PNG
.save_image:
    ; Find PNG Encoder CLSID
    stdcall GetEncoderClsid, _mime_png, encoderClsid
    test    eax, eax
    js      .cleanup ; Failed (-1)

    invoke  GdipSaveImageToFile, [pBitmap], _filename, encoderClsid, NULL

.cleanup:
    invoke  GdipDeleteBrush, [pBrushText]
    invoke  GdipDeleteFont, [pFont]
    invoke  GdipDeleteFontFamily, [pFamily]
    invoke  GdipDeleteGraphics, [pGraphics]
    invoke  GdipDisposeImage, [pBitmap]
    invoke  GdiplusShutdown, [token]

.exit:
    invoke  ExitProcess, 0

; =============================================================
; Imports
; =============================================================
section '.idata' import data readable writeable

    library kernel32,'KERNEL32.DLL',\
            gdiplus,'gdiplus.dll'

    include 'api/kernel32.inc'

    import gdiplus,\
           GdiplusStartup,'GdiplusStartup',\
           GdiplusShutdown,'GdiplusShutdown',\
           GdipCreateBitmapFromScan0,'GdipCreateBitmapFromScan0',\
           GdipGetImageGraphicsContext,'GdipGetImageGraphicsContext',\
           GdipGraphicsClear,'GdipGraphicsClear',\
           GdipCreateFontFamilyFromName,'GdipCreateFontFamilyFromName',\
           GdipCreateFont,'GdipCreateFont',\
           GdipDrawString,'GdipDrawString',\
           GdipCreateSolidFill,'GdipCreateSolidFill',\
           GdipDeleteBrush,'GdipDeleteBrush',\
           GdipDeleteFont,'GdipDeleteFont',\
           GdipDeleteFontFamily,'GdipDeleteFontFamily',\
           GdipDeleteGraphics,'GdipDeleteGraphics',\
           GdipDisposeImage,'GdipDisposeImage',\
           GdipSaveImageToFile,'GdipSaveImageToFile',\
           GdipGetImageEncodersSize,'GdipGetImageEncodersSize',\
           GdipGetImageEncoders,'GdipGetImageEncoders'

; ### Explanation
; 
; 1. **Format PE GUI**: This directive tells `fasmg` (via the included macros) to construct a Windows Executable (Portable Executable format) for the Graphical User Interface subsystem (though we don't create a window, this allows GDI usage without a console popping up).
; 2. **Config Data**: The `input_data` label points to the binary block you specified. The code parses this at runtime:
; * `lodsd` instructions read the 32-bit integers (width, height, cols, rows) sequentially.
; * The string data is accessed using a byte-pointer (`esi`) that increments as we draw characters.
;
;
; 3. **GDI+ Pipeline**:
; * 
; **Startup**: Initializes the GDI+ library.
; 
; 
; * **Bitmap**: Calculates the total image size (`CellWidth * Cols` by `CellHeight * Rows`) and creates a 24-bit RGB bitmap in memory.
; * **Graphics Context**: Creates a drawing context (`Graphics`) associated with that bitmap.
; * **Font**: Creates a "Consolas" font object. The size is approximated to fit the cell height.
; * **Loop**: It iterates through your data rows and columns. For every character found, it defines a rectangle (`RectF`) corresponding to that grid cell's pixel coordinates and commands GDI+ to draw the text there.
; 
; 
; 4. **PNG Encoding**:
; * The `GetEncoderClsid` procedure searches the system's available encoders for one matching the mime type `image/png`.
; * It retrieves the **CLSID** (Class ID) required by `GdipSaveImageToFile` to write the output correctly.
; 
; 
; 5. **Output**: When you run the compiled executable, it will silently generate `output.png` in the same folder.
; 
; This approach combines the low-level data parsing of assembly with the high-level graphical capabilities of the Windows OS, satisfying the requirement to process your specific binary structure and output a standard image format.
