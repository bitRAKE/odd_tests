// clang -c -mavx512f powi_zmm.S -o powi_zmm.o

.intel_syntax noprefix
.section .text
.global powi_zmm

// __m512 powi_zmm(__m512 x, uint32_t e)
//	input: ZMM0, ECX
//	output ZMM0 <- ZMM0^ECX
//	leaf function doesn't need SEH

powi_zmm:

// First, handle special cases: 0, 1 and powers of two:

.reduce:
	shr rcx, 1
	jbe .first_bit // Y: Z|C
	vmulps zmm0, zmm0, zmm0
	jmp .reduce

.first_bit:
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
