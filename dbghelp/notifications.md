
Output example:
```CMD
> notifications.exe ntdll.dll
CBA_EVENT: sevInfo [0] : DBGHELP: No header for ntdll.dll.  Searching for image on disk
CBA_EVENT: sevInfo [0] : DBGHELP: Y:\_F\dbghelp\examples\ntdll.dll - file not found
CBA_EVENT: sevInfo [0] : DBGHELP: ntdll.dll not found in .
CBA_EVENT: sevInfo [0] : DBGHELP: ntdll - no symbols loaded
notifications.asm, 120: SymLoadModuleExW .hProcess, NULL, rax, rdx, rdx, edx, rdx, edx
There are no more files.
CBA_EVENT: sevInfo [0] : DBGHELP:
```
... the file doesn't exist, an error is reported between events.
