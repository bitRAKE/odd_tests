clang -c -gcodeview -mavx512f ./powu/vpowups.S -o vpowups.obj
python cv2dwarf.py ./powu/vpowups.S -o vpowups.elf.S
clang -c -gdwarf-5 -mavx512f vpowups.elf.S -o vpowups.o
del vpowups.obj vpowups.elf.S vpowups.o
