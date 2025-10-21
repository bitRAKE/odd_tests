// clang -O3 -march=native -mavx512f -masm=intel -std=c23 test_harness.c powi_zmm.S -o test_powi.exe

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <immintrin.h>
#include <stdbool.h>

#include "powi_zmm_shim.h" // __m512 powi_zmm_call(__m512 base, uint32_t exp)

/* Reference implementation using scalar math */
float reference_powi(float base, uint32_t exp) {
    return powf(base, (float)exp);
}

/* Validation helper */
bool floats_equal(float a, float b, float epsilon) {
    if (isnan(a) && isnan(b)) return true;
    if (isinf(a) && isinf(b)) return (a == b);
    return fabsf(a - b) <= epsilon * fabsf(a) + epsilon;
}

/* Test a single vector of floats */
void test_vector(__m512 base_vec, uint32_t exp, const char *desc) {
    __m512 result = powi_zmm_call(base_vec, exp);
    
    float base_arr[16], result_arr[16];
    _mm512_storeu_ps(base_arr, base_vec);
    _mm512_storeu_ps(result_arr, result);
    
    printf("\n%s (exp=%u):\n", desc, exp);
    printf("  Base:     ");
    for (int i = 0; i < 4; i++) printf("%8.3f ", base_arr[i]);
    printf("\n  Result:   ");
    for (int i = 0; i < 4; i++) printf("%8.3f ", result_arr[i]);
    printf("\n  Expected: ");
    
    bool all_pass = true;
    for (int i = 0; i < 4; i++) {
        float expected = reference_powi(base_arr[i], exp);
        printf("%8.3f ", expected);
        if (!floats_equal(result_arr[i], expected, 1e-5f)) {
            all_pass = false;
        }
    }
    printf("\n  Status:   %s\n", all_pass ? "PASS" : "FAIL");
}

/* Edge case: exponent = 0 */
void test_exp_zero(void) {
    printf("\n=== Test: Exponent = 0 (should return 1.0) ===\n");
    
    float vals[] = {0.0f, 1.0f, 2.5f, -3.7f, 100.0f};
    for (int i = 0; i < 5; i++) {
        __m512 base = _mm512_set1_ps(vals[i]);
        __m512 result = powi_zmm_call(base, 0);
        float res = _mm512_cvtss_f32(result);
        printf("  %.1f^0 = %.3f (expect 1.000) - %s\n", 
               vals[i], res, fabsf(res - 1.0f) < 1e-5f ? "PASS" : "FAIL");
    }
}

/* Edge case: exponent = 1 */
void test_exp_one(void) {
    printf("\n=== Test: Exponent = 1 (should return base) ===\n");
    
    float vals[] = {0.5f, 1.0f, 2.5f, -3.7f, 1000.0f};
    for (int i = 0; i < 5; i++) {
        __m512 base = _mm512_set1_ps(vals[i]);
        __m512 result = powi_zmm_call(base, 1);
        float res = _mm512_cvtss_f32(result);
        printf("  %.1f^1 = %.3f (expect %.3f) - %s\n", 
               vals[i], res, vals[i], 
               fabsf(res - vals[i]) < 1e-5f * fabsf(vals[i]) ? "PASS" : "FAIL");
    }
}

/* Power of two exponents (special optimization path) */
void test_power_of_two(void) {
    printf("\n=== Test: Power of Two Exponents ===\n");
    
    __m512 base = _mm512_set1_ps(2.0f);
    uint32_t exps[] = {2, 4, 8, 16, 32};
    
    for (int i = 0; i < 5; i++) {
        __m512 result = powi_zmm_call(base, exps[i]);
        float res = _mm512_cvtss_f32(result);
        float expected = powf(2.0f, (float)exps[i]);
        printf("  2^%u = %.1f (expect %.1f) - %s\n", 
               exps[i], res, expected, fabsf(res - expected) < 1e-3f ? "PASS" : "FAIL");
    }
}

/* General exponent test */
void test_general_exponents(void) {
    printf("\n=== Test: General Exponents ===\n");
    
    float bases[] = {0.5f, 1.5f, 2.0f, 3.0f, 0.1f};
    uint32_t exps[] = {3, 5, 7, 10, 15};
    
    for (int b = 0; b < 5; b++) {
        for (int e = 0; e < 5; e++) {
            __m512 base = _mm512_set1_ps(bases[b]);
            __m512 result = powi_zmm_call(base, exps[e]);
            float res = _mm512_cvtss_f32(result);
            float expected = powf(bases[b], (float)exps[e]);
            float epsilon = fmaxf(1e-5f, 1e-5f * fabsf(expected));
            
            if (fabsf(res - expected) > epsilon) {
                printf("  %.1f^%u = %.6f (expect %.6f) - FAIL\n", 
                       bases[b], exps[e], res, expected);
            }
        }
    }
    printf("  General exponent tests completed\n");
}

/* Test with different float values in a single vector */
void test_mixed_values(void) {
    printf("\n=== Test: Mixed Values in Vector ===\n");
    
    float vals[16] = {1.0f, 2.0f, 3.0f, 0.5f, 1.5f, 2.5f, -1.0f, 0.0f,
                      1.1f, 2.2f, 3.3f, 0.7f, 1.8f, 2.9f, -0.5f, 10.0f};
    __m512 base = _mm512_loadu_ps(vals);
    
    uint32_t exp = 3;
    __m512 result = powi_zmm_call(base, exp);
    
    float result_arr[16];
    _mm512_storeu_ps(result_arr, result);
    
    bool all_pass = true;
    for (int i = 0; i < 16; i++) {
        float expected = powf(vals[i], (float)exp);
        float epsilon = fmaxf(1e-5f, 1e-5f * fabsf(expected));
        if (fabsf(result_arr[i] - expected) > epsilon) {
            printf("  vals[%d]=%.2f: got %.6f, expected %.6f - FAIL\n", 
                   i, vals[i], result_arr[i], expected);
            all_pass = false;
        }
    }
    printf("  Mixed values test: %s\n", all_pass ? "PASS" : "FAIL");
}

/* Test edge cases with special float values */
void test_special_values(void) {
    printf("\n=== Test: Special Float Values ===\n");
    
    __m512 base;
    
    /* 1.0 to any power */
    base = _mm512_set1_ps(1.0f);
    for (uint32_t exp = 0; exp <= 100; exp += 10) {
        __m512 result = powi_zmm_call(base, exp);
        float res = _mm512_cvtss_f32(result);
        printf("  1.0^%u = %.3f - %s\n", exp, res, 
               fabsf(res - 1.0f) < 1e-5f ? "PASS" : "FAIL");
    }
}

int main(void) {
    printf("======================================\n");
    printf("  AVX-512 powi_zmm Test Harness\n");
    printf("======================================\n");
    
    /* Run all test suites */
    test_exp_zero();
    test_exp_one();
    test_power_of_two();
    test_general_exponents();
    test_mixed_values();
    test_special_values();
    
    printf("\n======================================\n");
    printf("  All tests completed\n");
    printf("======================================\n");
    
    return 0;
}