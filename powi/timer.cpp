// clang++ -O3 -march=native -mavx512f -masm=intel timer.cpp powi_zmm.S -o timer.exe

#include <iostream>
#include <chrono>    // For high-precision timing
#include <immintrin.h>
#include <stdint.h>

#include "powi_zmm_shim.h" // powi_zmm_call()

// This function "consumes" the result, preventing the compiler
// from optimizing away the loop. It adds almost no overhead.
static void escape(__m512 *p) {
    asm volatile("" : : "x"(*p) : "memory");
}

int main() {
    // 1. Set up test data
    const long long WARMUP_ITER = 1000000;
    const long long TIMING_ITER = 100000000; // 100 Million
    
    __m512 base = _mm512_set1_ps(1.0001f);
    uint32_t exponent = 1234567;
    
    __m512 result; // Declare result outside the loop

    // 2. Warm-up Loop
    // This gets the CPU out of low-power states and warms up the
    // instruction and data caches.
    for (long long i = 0; i < WARMUP_ITER; ++i) {
        result = powi_zmm_call(base, exponent);
        escape(&result); // "Use" the result
    }

    // 3. Timing Loop
    auto start = std::chrono::high_resolution_clock::now();

    for (long long i = 0; i < TIMING_ITER; ++i) {
        result = powi_zmm_call(base, exponent);
        // We must "use" the result in a way the compiler can't
        // optimize out. This tells the compiler the 'result'
        // is used by an asm block it can't understand.
        asm volatile("" : : "x"(result));
    }

    auto end = std::chrono::high_resolution_clock::now();
    
    // We must *also* use 'result' after the loop, to prevent
    // the whole loop from being removed.
    if (((float*)&result)[0] == 12345.0f) {
        printf("Dead code\n");
    }

    // 4. Calculate and Print Results
    std::chrono::duration<double, std::nano> total_ns = end - start;
    double time_per_call_ns = total_ns.count() / TIMING_ITER;

    std::cout << "Total iterations: " << TIMING_ITER << std::endl;
    std::cout << "Total time:       " << total_ns.count() / 1e9 << " seconds" << std::endl;
    std::cout << "Time per call:    " << time_per_call_ns << " ns" << std::endl;

    return 0;
}
