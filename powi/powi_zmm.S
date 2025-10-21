// clang -c -mavx512f powi_zmm.S -o powi_zmm.o

.intel_syntax noprefix
.section .text
.global powi_zmm
.align 16

// __m512 powi_zmm(__m512 x, uint32_t e)
//	input: ZMM0, ECX
//	output ZMM0 <- ZMM0^ECX
//	leaf function doesn't need SEH


// First, handle special cases: 0, 1 and powers of two:

1:	vmulps zmm0, zmm0, zmm0
powi_zmm:
	shr rcx, 1
	ja 1b				// Y: ~Z & ~C

// All trailing zero-bits are gone, only continue if more bits remain.

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

.done:	jc .not_zero // perdict backward likely jump
	mov ecx, 0x3f800000 // 1f
//	movd xmm0, ecx
//	vbroadcastss zmm0, xmm0
	vpbroadcastd zmm0, ecx
	retn

// + No memory access.
