/* Non-standard callee: expects ZMM0=base, RCX=exp, returns ZMM0 */
extern void vpowups(void);

/* Wrapper to call vpowups with proper calling convention */
static inline __m512 vpowups_call(__m512 base, uint64_t exp) {
    /* Pin operands to the required registers; compiler inserts any moves. */
    register __m512    x __asm__("zmm0") = base;   // use "xmm0" if your toolchain rejects "zmm0"
    register uint64_t  e __asm__("rcx")  = exp;

    __asm__ volatile(
        "call vpowups"
        : "+x"(x),        /* ZMM0 in/out */
          "+c"(e)         /* RCX  in/out (ties ‘e’ to RCX) */
        :
        : "zmm1","cc"    /* the CALL/RET doesn't need "memory" no side effects */
    );
    return x;  // ZMM0 after call
}
