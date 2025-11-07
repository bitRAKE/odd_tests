// clang -c -mavx512f vpowups.S -o vpowups.o

.intel_syntax noprefix
.section .text
.global vpowups
.align 16

/*
  Exponentiation by unsigned (squaring w/ optimized special case filtering).
  https://wikipedia.org/wiki/Exponentiation_by_squaring
   + No memory access.

__m512 vpowups(__m512 x, uint64_t e);
	input:	ZMM0, RCX
	output:	ZMM0 <- ZMM0^RCX (per float element)
	used:	ZMM1
*/

// First, handle special cases: 0, 1 and powers of two:

1:	vmulps zmm0, zmm0, zmm0
vpowups:
	shr rcx, 1
	ja 1b				// Y: ~Z & ~C, ~50%

// All trailing zero-bits are gone, only continue if set bits remain:

	jz .done			// Y: ~0%
	vmovaps zmm1, zmm0

// Second, squaring loop taps at set bits to complete calculation:

.square:
	vmulps zmm1, zmm1, zmm1
	shr rcx, 1
	jnc .square			// ~50%
	vmulps zmm0, zmm0, zmm1
	jnz .square			// N: ~1%
.not_zero:
	retn

.done:
	jc .not_zero			// N: ~0%
	mov ecx, 0x3f800000		// 1f
	vpbroadcastd zmm0, ecx
	retn

// Each branch comment refers to either if the branch is taken (Y[es]:), or if
// the branch is not taken (N[o]:) -- including approximate branch percentages.
