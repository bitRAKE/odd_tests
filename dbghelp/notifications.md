
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


Output example:
```CMD
> notifications.exe c:\Windows\System32\kernel32.dll
CBA_EVENT: sevInfo [0] : DBGHELP: No header for c:\Windows\System32\kernel32.dll.  Searching for image on disk
CBA_EVENT: sevInfo [0] : DBGHELP: c:\Windows\System32\kernel32.dll - OK
CBA_EVENT: sevInfo [0] : DBGHELP: .\kernel32.pdb - file not found
CBA_EVENT: sevInfo [0] : DBGHELP: .\dll\kernel32.pdb - file not found
CBA_EVENT: sevInfo [0] : DBGHELP: .\symbols\dll\kernel32.pdb - file not found
CBA_EVENT: sevInfo [0] : SYMSRV:  BYINDEX: 0x1
         C:\Symbols*https://msdl.microsoft.com/download/symbols
         kernel32.pdb
         565E88E4301F391AA32C3CC439369F751
CBA_EVENT: sevInfo [0] : SYMSRV:  PATH: C:\Symbols\kernel32.pdb\565E88E4301F391AA32C3CC439369F751\kernel32.pdb
CBA_EVENT: sevInfo [0] : SYMSRV:  RESULT: 0x00000000
CBA_EVENT: sevInfo [0] : DBGHELP: kernel32 - public symbols
        C:\Symbols\kernel32.pdb\565E88E4301F391AA32C3CC439369F751\kernel32.pdb
```
... symbol server finds compatible PDB.
