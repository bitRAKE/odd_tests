// Generate object file (with debug info):
//	clang -c -g -mavx512f vpowups.S -o vpowups.o

// Inspect generation:
//	llvm-nm vpowups.o # symbol visibilities
//	llvm-objdump --line-numbers --x86-asm-syntax=intel vpowups.o
//	llvm-objdump -x -s -u vpowups.o
//	llvm-readobj --coff-exports --symbols --sections vpowups.o
//	llvm-readobj --codeview --symbols --sections vpowups.o

.intel_syntax noprefix
.section .text,"xr",discard,vpowups
.global vpowups

.cv_file 1 "vpowups.S"
.cv_func_id 1
.cv_loc 1 1 33 0 // func file line col

.p2align 4		// align to 2^4 bytes
.cfi_startproc		// unwindable and does not need anything

/*
  Exponentiation by unsigned (squaring w/ optimized special case filtering).
  https://wikipedia.org/wiki/Exponentiation_by_squaring
   + No memory access.

__m512 vpowups(__m512 x, uint64_t e);
	input:	ZMM0, RCX
	output:	ZMM0 <- ZMM0^RCX (per float element)
	used:	ZMM1
*/

// Handle special cases: 0, 1 and powers of two:

0:	vmulps zmm0, zmm0, zmm0
vpowups:
	shr rcx, 1
	ja 0b				// ~50%, Y: ~Z & ~C

// All trailing zero-bits are gone, only continue if set bits remain:

	jz 1f				// Y: ~0%
	vmovaps zmm1, zmm0

// Squaring loop accumulates at set bits to complete calculation:

0:	vmulps zmm1, zmm1, zmm1
	shr rcx, 1
	jnc 0b				// ~50%
	vmulps zmm0, zmm0, zmm1
	jnz 0b				// N: ~1%
0:	retn

// Powers of two are complete, but zero results in constant:

1:	jc 0b				// N: ~0%
	mov ecx, 0x3F800000		// 1f
	vpbroadcastd zmm0, ecx
	retn

// Each branch comment refers to either if the branch is taken (Y[es]:), or if
// the branch is not taken (N[o]:) -- including approximate branch percentages.

.cfi_endproc
