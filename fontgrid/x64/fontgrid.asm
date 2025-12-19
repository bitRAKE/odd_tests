; c:\fasm\fasm2\fasm2 -e 5 fontgrid.asm

; https://board.flatassembler.net/topic.php?p=246577#246577

format PE64 GUI 5.0
entry start

include 'win64a.inc'

struc GUID def
	label .:4 ; only require dword alignment
	namespace .
		match ,def
			Data1 rd 1
			Data2 rw 1
			Data3 rw 1
			Data4 rb 2
			Data5 rb 6
		else match d1-d2-d3-d4-d5, def
			Data1 dd 0x#d1
			Data2 dw 0x#d2
			Data3 dw 0x#d3
			Data4 db 0x#d4 shr 8,0x#d4 and 0FFh
			Data5 db 0x#d5 shr 40,0x#d5 shr 32 and 0FFh,0x#d5 shr 24 and 0FFh,0x#d5 shr 16 and 0FFh,0x#d5 shr 8 and 0FFh,0x#d5 and 0FFh
		else
			err
		end match
	end namespace
end struc

struct GdiplusStartupInput
	GdiplusVersion			dd ?
		padding dd ? ; explicit padding for alignment
	DebugEventCallback		dq ?
	SuppressBackgroundThread	dd ?
	SuppressExternalCodecs		dd ?
ends

struct ImageCodecInfo
	Clsid			GUID
	FormatID		GUID
	CodecName		dq ?	;*WCHAR
	DllName			dq ?	;*WCHAR
	FormatDescription	dq ?	;*WCHAR
	FilenameExtension	dq ?	;*WCHAR
	MimeType		dq ?	;*WCHAR
	Flags			dd ?
	Version			dd ?
	SigCount		dd ?
	SigSize			dd ?
	SigPattern		dq ?	;*BYTE
	SigMask			dq ?	;*BYTE
ends

; =============================================================
;	Data Section
; =============================================================

section '.data' data readable writeable

; ---------------------------------------------------------
;	USER CONFIGURATION BLOCK
; ---------------------------------------------------------
config_data:
	dd 48, 64       ; [0] Cell Width, Cell Height (pixels)
	dd 3, 4         ; [8] Grid Cols, Grid Rows (characters)
        
	; Rows of ASCII characters (null-terminated)
	db '123',0
	db '456',0
	db '789',0
	db ' 0 ',0
	db 0            ; terminator

; ---------------------------------------------------------
;	Variables & Handles (8-byte pointers for x64)
; ---------------------------------------------------------

_filename	du 'output.png',0
_font_family	du 'Consolas',0
_mime_png	du 'image/png',0

token           dq ?
gdiplusInput    GdiplusStartupInput 
encoderClsid    GUID

pBitmap		dq ?
pGraphics	dq ?
pFamily		dq ?
pFont		dq ?
pBrushText	dq ?

; Rendering counters (32-bit sufficient for dimensions)
cell_w	dd ?
cell_h	dd ?
cols	dd ?
rows	dd ?
curr_x	dd ?
curr_y	dd ?

; Helper buffer to hold single WCHAR string for GDI+
; (Avoids messy stack alignment logic inside the loop)
char_buf dw 0, 0 
    
; RectF (X, Y, W, H) - 4 floats (IEEE 754)
draw_rect dd 0.0, 0.0, 0.0, 0.0

; =============================================================
;	Code Section
; =============================================================

section '.text' code readable executable

; =============================================================
;	Helper: GetEncoderClsid (Symbolic / Structured)
; =============================================================
proc GetEncoderClsid uses rbx rsi rdi, formatPtr, clsidPtr
	local numEncoders:DWORD
	local size:DWORD
	local pImageCodecInfo:QWORD

	; 0. Preserve passed parameters
	fastcall?.frame =: 0 ; track max param-space use
	sub rsp, frame_size

	mov [formatPtr], rcx
	mov [clsidPtr], rdx

	; 1. Get the array size in bytes
	invoke GdipGetImageEncodersSize, addr numEncoders, addr size
	test eax, eax
	jnz .fail
	cmp [numEncoders], eax ; terminate early if no encoders
	jz .fail

	; 2. Allocate memory for the array
	invoke GlobalAlloc, GMEM_ZEROINIT, [size] ; GPTR
	test rax, rax
	jz .fail
	mov [pImageCodecInfo], rax

	; 3. Populate the array
	invoke GdipGetImageEncoders, [numEncoders], [size], [pImageCodecInfo]
	test eax, eax
	jnz .fail_free

	; 4. Setup Unicode string compare of MimeType loop
	mov ecx, [numEncoders]
	mov rbx, [pImageCodecInfo]
	jmp @F
.nomatch:
	add rbx, sizeof ImageCodecInfo
	dec ecx
	jz .fail_free

@@:	mov rsi, [rbx+ImageCodecInfo.MimeType]
	mov rdi, [formatPtr]
@@:	cmpsw
	jnz .nomatch
	cmp word [rsi], 0
	jnz @B

	; Copy the CLSID (GUID) from the struct to the output buffer
	; The CLSID is at offset 0 (ImageCodecInfo.Clsid)

	mov rdi, [clsidPtr]
	lea rsi, [rbx+ImageCodecInfo.Clsid]
	movups xmm0, [rsi]
	movups [rdi], xmm0

	invoke GlobalFree, [pImageCodecInfo]
	xor rax, rax ; success
	ret

.fail_free:
	invoke GlobalFree, [pImageCodecInfo]
.fail:	or rax, -1 ; failure
	ret

	frame_size := fastcall?.frame
	restore fastcall?.frame
endp

;-------------------------------------------------------------------------------
start:
	fastcall.frame = 0 ; setting fastcall.frame to non-negative value makes fastcall/invoke use it to track maximum necessary stack space, and not allocate it automatically

	; 1. Stack Alignment & Init
	enter .frame, 0

	; GDI+ Startup
	mov [gdiplusInput.GdiplusVersion], 1
	invoke GdiplusStartup, addr token, addr gdiplusInput, NULL
	test eax, eax
	jnz .exit

	; 2. Parse Config
	mov rsi, config_data
	lodsd                   ; Load Cell Width
	mov [cell_w], eax
	lodsd                   ; Load Cell Height
	mov [cell_h], eax
	lodsd                   ; Load Cols
	mov [cols], eax
	lodsd                   ; Load Rows
	mov [rows], eax
	; RSI now points to first ASCII string

	; Calc Image Size: W = cell_w * cols, H = cell_h * rows
	mov eax, [cell_w]
	imul eax, [cols]
	mov ebx, [cell_h]
	imul ebx, [rows]

	; 3. Create Bitmap
	; PixelFormat24bppRGB = 0x21808
	invoke GdipCreateBitmapFromScan0, eax, ebx, 0, 0x21808, NULL, addr pBitmap
	invoke GdipGetImageGraphicsContext, [pBitmap], addr pGraphics

	; 4. Setup Graphics
	invoke GdipGraphicsClear, [pGraphics], 0xFFFFFFFF ; White

	; Create Font: Size 32, UnitPixel(2)
	invoke GdipCreateFontFamilyFromName, addr _font_family, NULL, addr pFamily

	; Note: "float dword" required as the default is qword.
	invoke GdipCreateFont, [pFamily], float dword 32.0, 0, 2, addr pFont
    
	invoke GdipCreateSolidFill, 0xFF000000, addr pBrushText ; Black

;	5. Render Loop

	xor edi, edi			; Row Index
	mov [curr_y], 0
.row_loop:
	cmp edi, [rows]
	jge .save

	mov [curr_x], 0
	xor ebx, ebx
.col_loop:
	cmp ebx, [cols]
	jge .next_row_prep

	; Check null terminator
	lodsb
	test al, al
	jz .row_ended_early

	; Convert ASCII char to Unicode in memory buffer
	movzx eax, al
	mov dword [char_buf], eax

	; Prepare RectF (x, y, w, h)
	; Convert Integers to Floats (Single Precision)
	cvtsi2ss xmm0, [curr_x]
	movss    [draw_rect], xmm0      ; X
	cvtsi2ss xmm0, [curr_y]
	movss    [draw_rect+4], xmm0    ; Y
	cvtsi2ss xmm0, [cell_w]
	movss    [draw_rect+8], xmm0    ; Width
	cvtsi2ss xmm0, [cell_h]
	movss    [draw_rect+12], xmm0   ; Height

	; Draw String
	; Args: Graphics, StringPtr, Len(-1), Font, RectPtr, Format, Brush
	invoke  GdipDrawString, [pGraphics], addr char_buf, -1, \
		[pFont], addr draw_rect, NULL, [pBrushText]

	inc ebx
	mov eax, [cell_w]
	add [curr_x], eax
	jmp .col_loop

.next_row_prep: ; skip to null
@@:	lodsb
	test al, al
	jnz @B
.row_ended_early:
	inc edi
	mov eax, [cell_h]
	add [curr_y], eax
	jmp .row_loop

;	6. Save Image
.save:
	fastcall GetEncoderClsid, addr _mime_png, addr encoderClsid
	cmp rax, -1
	jz .cleanup

	invoke GdipSaveImageToFile, [pBitmap], addr _filename, addr encoderClsid, NULL
.cleanup:
	invoke GdipDeleteBrush, [pBrushText]
	invoke GdipDeleteFont, [pFont]
	invoke GdipDeleteFontFamily, [pFamily]
	invoke GdipDeleteGraphics, [pGraphics]
	invoke GdipDisposeImage, [pBitmap]
	invoke GdiplusShutdown, [token]
.exit:
	invoke ExitProcess, 0
	.frame := fastcall.frame

; =============================================================
; Imports & Structs
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
