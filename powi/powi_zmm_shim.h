/* Non-standard callee: expects ZMM0=base, ECX=exp, returns ZMM0 */
extern void powi_zmm(void);

/* Wrapper to call powi_zmm with proper calling convention */
static inline __m512 powi_zmm_call(__m512 base, uint32_t exp) {
    /* Pin operands to the required registers; compiler inserts any moves. */
    register __m512    x __asm__("zmm0") = base;   // use "xmm0" if your toolchain rejects "zmm0"
    register uint32_t  e __asm__("ecx")  = exp;

    __asm__ volatile(
        "call powi_zmm"
        : "+x"(x),        /* ZMM0 in/out */
          "+c"(e)         /* ECX  in/out (ties ‘e’ to ECX) */
        : 
        : "zmm1","cc" /* the CALL/RET doesn't need "memory" no side effects */
    );
    return x;  // ZMM0 after call
}
