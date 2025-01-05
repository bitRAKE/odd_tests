; https://board.flatassembler.net/topic.php?p=242282#242282

; Attempt to use UI Automation to programatically interact with Universal
; Windows Platform (UWP) application. The modern calculator application
; button '3' is invoked.
;
; Note: Missing error checking.

include 'windows.g'
include 'UIAutomation.g'

public Main
:Main:
	virtual at rbp-.local
		.pAutomation	IUIAutomation
		.pCalculator	IUIAutomationElement
		.pCondition	IUIAutomationCondition
		.pButton3	IUIAutomationElement
		.pInvoke	IUIAutomationInvokePattern
		.var		VARIANT
		.local := ($ - $$) and -16
	end virtual
	enter .frame+.local, 0
	CoInitialize NULL
	CoCreateInstance & CLSID_CUIAutomation, NULL, CLSCTX_INPROC_SERVER,\
		& IID_IUIAutomation, & .pAutomation

	FindWindowA A 'ApplicationFrameWindow', A 'Calculator'
	xchg rdx, rax
	IUIAutomation__ElementFromHandle [.pAutomation], rdx, & .pCalculator
	cmp [.pCalculator], 0
	jz .no_element

	SysAllocString W "num3Button"
	mov [.var.qVal], rax
	mov [.var.vt], VT_BSTR
	IUIAutomation__CreatePropertyCondition [.pAutomation], \
		UIA_AutomationIdPropertyId, & .var, & .pCondition
	IUIAutomationElement__FindFirst [.pCalculator],\
		TreeScope_Descendants, [.pCondition], & .pButton3
	cmp [.pButton3], 0
	jz .no_condition_element

	IUIAutomationElement__GetCurrentPattern [.pButton3],\
		UIA_InvokePatternId, & .pInvoke
	cmp [.pInvoke], 0
	jz .no_pattern
	IUIAutomationInvokePattern__Invoke [.pInvoke]
	IUIAutomationInvokePattern__Release [.pInvoke]
.no_pattern:
	IUIAutomationElement__Release [.pButton3]
.no_condition_element:
	IUIAutomationCondition__Release [.pCondition]
	IUIAutomationElement__Release [.pCalculator]
	SysFreeString [.var.qVal] ; VariantClear & .var ; also works
.no_element:
	IUIAutomation__Release [.pAutomation]

	CoUninitialize
	ExitProcess 0
	jmp $


virtual as 'cmd' ; Maybe your editor can grok this and build the executable?
	db '@echo off',10
	db 'call ..\..\bin\fasm2.cmd -n ',__FILE__,10

	base = __FILE__ bswap lengthof __FILE__
	while '.' <> base and 0xFF
		base = base shr 8 ; prune extension bytes
	end while
	db 'link /NOLOGO /ENTRY:Main /SUBSYSTEM:"WINDOWS,6.02"',\
		' /FIXED /IGNORE:4281 /BASE:0x7FFF0000',\
		' /NODEFAULTLIB kernel32.lib user32.lib Ole32.lib OleAut32.lib ',\
		base bswap lengthof base,'obj',10
end virtual
