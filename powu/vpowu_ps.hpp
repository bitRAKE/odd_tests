// vpowups.hpp
#pragma once
#include <immintrin.h>
#include <cstdint>
#include <type_traits>

#if defined(_MSC_VER)
#  define VPOWU_FINL __forceinline
#else
#  define VPOWU_FINL __attribute__((always_inline)) inline
#endif

namespace vpowu_detail {

// Choose an unsigned shift type sized for the exponent.
template<class E>
using uexp_t = std::conditional_t<(sizeof(E) <= 4), uint32_t, uint64_t>;

// Per-vector float ops.
template<class V> struct ops; // specializations only

template<> struct ops<__m128> {
    using v = __m128;
    static VPOWU_FINL v mul(v a, v b) { return _mm_mul_ps(a, b); }
    static VPOWU_FINL v sqr(v a)      { return _mm_mul_ps(a, a); }
    static VPOWU_FINL v one()         { return _mm_set1_ps(1.0f); }
};

#if defined(__AVX__)
template<> struct ops<__m256> {
    using v = __m256;
    static VPOWU_FINL v mul(v a, v b) { return _mm256_mul_ps(a, b); }
    static VPOWU_FINL v sqr(v a)      { return _mm256_mul_ps(a, a); }
    static VPOWU_FINL v one()         { return _mm256_set1_ps(1.0f); }
};
#endif

#if defined(__AVX512F__)
template<> struct ops<__m512> {
    using v = __m512;
    static VPOWU_FINL v mul(v a, v b) { return _mm512_mul_ps(a, b); }
    static VPOWU_FINL v sqr(v a)      { return _mm512_mul_ps(a, a); }
    static VPOWU_FINL v one()         { return _mm512_set1_ps(1.0f); }
};
#endif

template<class V>
constexpr bool is_vec_ps_v =
    std::is_same_v<V,__m128>
#if defined(__AVX__)
 || std::is_same_v<V,__m256>
#endif
#if defined(__AVX512F__)
 || std::is_same_v<V,__m512>
#endif
 ;

} // namespace vpowu_detail

// Single entry point: vpowups(base, exp) for __m128/__m256/__m512 and uint32_t/uint64_t.
template<class V, class E>
VPOWU_FINL V vpowups(V base, E exp) {
    static_assert(vpowu_detail::is_vec_ps_v<V>, "V must be __m128/__m256/__m512 of float");
    static_assert(std::is_unsigned_v<std::make_unsigned_t<E>>, "E must be unsigned or castable to unsigned");
    using O = vpowu_detail::ops<V>;
    using U = vpowu_detail::uexp_t<E>;

    U e = static_cast<U>(exp);
    if (e == 0) return O::one();

    // Skip trailing zeros.
    while ((e & U{1}) == 0) {
        base = O::sqr(base);
        e >>= 1;
    }

    V acc = base;
    while ((e >>= 1) != 0) {
        base = O::sqr(base);
        if (e & U{1}) acc = O::mul(acc, base);
    }
    return acc;
}
