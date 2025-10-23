// clang -c -mavx512f vpowips.S -o vpowips.o

.intel_syntax noprefix
.section .text
.global vpowips
.align 16

/*
  Exponentiation by squaring w/ optimized special case filtering.
  https://wikipedia.org/wiki/Exponentiation_by_squaring
   + No memory access.

__m512 vpowips(__m512 x, uint64_t e);
	input: ZMM0, RCX
	output ZMM0 <- ZMM0^RCX (per float element)
*/

// First, handle special cases: 0, 1 and powers of two:

1:	vmulps zmm0, zmm0, zmm0
vpowips:
	shr rcx, 1
	ja 1b				// Y: ~Z & ~C

// All trailing zero-bits are gone, only continue if set bits remain.

	jz .done
	vmovaps zmm1, zmm0

// Second, loop to complete calculation:

.square:
	vmulps zmm1, zmm1, zmm1
	shr rcx, 1
	jnc .square
	vmulps zmm0, zmm0, zmm1
	jnz .square
.not_zero:
	retn

.done:	jc .not_zero			// perdict backward likely jump
	mov ecx, 0x3f800000		// 1f
	vpbroadcastd zmm0, ecx
	retn
