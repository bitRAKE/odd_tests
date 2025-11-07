#ifndef UNICODE
#define UNICODE
#endif
#ifndef _UNICODE
#define _UNICODE
#endif
#define NOMINMAX
#define WIN32_LEAN_AND_MEAN
// clang -O3 -march=native -mavx512f -masm=intel -std=c23 testing.c vpowups.S -lgdi32 -luser32 -lkernel32 -lbcrypt -o testing.exe
//
// Algorithm Testing Application:
//  - console application displays log text
//      + info/warn/error messages
//      + test results
//      + performance summary
//  - graphics window displays performance metrics in real-time

#include <windows.h>
#include <windowsx.h>
#include <bcrypt.h>
#include <immintrin.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdarg.h>
#include <float.h>
#include <math.h>
#include <strsafe.h>
#include <stdalign.h>
#include <string.h>

#include "vpowups_shim.h" // __m512 vpowups_call(__m512 base, uint64_t exp)

#pragma comment(lib, "bcrypt.lib")
#pragma comment(lib, "user32.lib")
#pragma comment(lib, "gdi32.lib")
#pragma comment(lib, "kernel32.lib")

#define WM_APP_PERF_UPDATE (WM_APP + 1)
#define ARRAY_SIZE(a) (sizeof(a) / sizeof((a)[0]))
#define PERF_BAR_COUNT 64u

typedef enum {
    LOG_INFO,
    LOG_WARN,
    LOG_ERROR
} log_level;

typedef struct {
    float max_abs_error;
    uint32_t max_ulp_error;
    uint32_t lane_index;
    float expected_lane;
    float actual_lane;
} comparison_result;

typedef struct {
    uint32_t cases_run;
    uint32_t failures;
} functional_stats;

typedef struct {
    HWND hwnd;
    SRWLOCK perf_lock;
    double avg_ticks[PERF_BAR_COUNT];
    double min_ticks[PERF_BAR_COUNT];
    double current_ticks[PERF_BAR_COUNT];
    uint64_t sample_counts[PERF_BAR_COUNT];
    double max_tick;
    BOOL perf_ready;
    double tick_frequency;
    LONG running;
    LONG functional_cases;
    LONG functional_failures;
    BOOL functional_done;
    HANDLE worker_thread;
    HBITMAP heat_bitmap;
    BITMAPINFO heat_info;
    uint32_t *heat_pixels;
    UINT heat_width;
    UINT heat_height;
} app_state;

static HANDLE g_console = NULL;
static app_state g_app;
static alignas(64) volatile float g_sink[16];

static void init_console(void);
static void log_message(log_level level, PCSTR format, ...);
static BOOL random_bytes(void *buffer, size_t size);
static __m512 ref_vpowups(__m512 base, uint64_t exp);
static BOOL compare_vectors(__m512 expected, __m512 actual, uint64_t exponent, comparison_result *out);
static BOOL execute_case(const char *group, const char *label, __m512 base, uint64_t exponent, functional_stats *stats);
static BOOL test_exponent_zero(functional_stats *stats);
static BOOL test_exponent_one(functional_stats *stats);
static BOOL test_power_of_two(functional_stats *stats);
static BOOL test_mixed_bit_patterns(functional_stats *stats);
static BOOL test_randomized(functional_stats *stats);
static BOOL run_functional_tests(app_state *state);
static void run_performance_monitor(app_state *state);
static DWORD WINAPI worker_thread_proc(LPVOID param);
static ATOM register_window_class(HINSTANCE instance);
static HWND create_main_window(HINSTANCE instance, app_state *state);
static void draw_performance_chart(HDC hdc, const RECT *client, app_state *state);
static LRESULT CALLBACK main_wnd_proc(HWND hwnd, UINT message, WPARAM w_param, LPARAM l_param);
static uint64_t generate_exponent_for_bit(uint32_t bit_index);
static __m512 random_uniform_vector(float min_value, float max_value);
static __m512 random_wide_vector(void);
static __m512 random_special_vector(void);
static float make_float_from_bits(uint32_t bits);
static BOOL ensure_heatmap_surface(app_state *state, UINT width, UINT height);
static void decay_heatmap(app_state *state, double decay);
static void plot_heatmap_samples(app_state *state, int chart_width, int chart_height, int bar_width, int spacing, const double current_values[], const uint64_t sample_counts[], double max_tick);
static void blit_heatmap(HDC hdc, int dst_left, int dst_top, const app_state *state);
static void destroy_heatmap(app_state *state);

static void init_console(void) {
    if (!GetConsoleWindow()) {
        AllocConsole();
    }
    g_console = GetStdHandle(STD_OUTPUT_HANDLE);
    if (g_console != INVALID_HANDLE_VALUE) {
        SetConsoleTitleW(L"vpowups Test Harness");
    }
}

static void log_message(log_level level, PCSTR format, ...) {
    if (!g_console || g_console == INVALID_HANDLE_VALUE) {
        return;
    }

    CHAR prefix[16] = {0};
    switch (level) {
        case LOG_INFO: StringCchCopyA(prefix, ARRAY_SIZE(prefix), "[INFO] "); break;
        case LOG_WARN: StringCchCopyA(prefix, ARRAY_SIZE(prefix), "[WARN] "); break;
        case LOG_ERROR: StringCchCopyA(prefix, ARRAY_SIZE(prefix), "[ERROR] "); break;
        default: StringCchCopyA(prefix, ARRAY_SIZE(prefix), "[LOG] "); break;
    }

    CHAR body[1024];
    va_list args;
    va_start(args, format);
    HRESULT hr = StringCchVPrintfA(body, ARRAY_SIZE(body), format, args);
    va_end(args);
    if (FAILED(hr)) {
        return;
    }

    CHAR line[1152];
    hr = StringCchCopyA(line, ARRAY_SIZE(line), prefix);
    if (FAILED(hr)) {
        return;
    }
    hr = StringCchCatA(line, ARRAY_SIZE(line), body);
    if (FAILED(hr)) {
        return;
    }
    hr = StringCchCatA(line, ARRAY_SIZE(line), "\r\n");
    if (FAILED(hr)) {
        return;
    }

    DWORD written = 0;
    WriteConsoleA(g_console, line, (DWORD)strlen(line), &written, NULL);
}

static BOOL random_bytes(void *buffer, size_t size) {
    if (size > ULONG_MAX) {
        return FALSE;
    }
    NTSTATUS status = BCryptGenRandom(
        NULL,
        (PUCHAR)buffer,
        (ULONG)size,
        BCRYPT_USE_SYSTEM_PREFERRED_RNG);
    return status >= 0;
}

static float make_float_from_bits(uint32_t bits) {
    union {
        uint32_t u;
        float f;
    } conv = {.u = bits};
    return conv.f;
}

static uint32_t float_to_ordered(uint32_t bits) {
    int32_t signed_bits = (int32_t)bits;
    uint32_t mask = (uint32_t)(signed_bits >> 31);
    return bits ^ (mask | 0x80000000u);
}

static __m512 ref_vpowups(__m512 base, uint64_t exp) {
    if (exp == 0u) {
        return _mm512_set1_ps(1.0f);
    }

    __m512 acc = _mm512_set1_ps(1.0f);
    __m512 factor = base;
    uint64_t e = exp;

    while (e != 0u) {
        if ((e & 1u) != 0u) {
            acc = _mm512_mul_ps(acc, factor);
        }
        e >>= 1;
        if (e == 0u) {
            break;
        }
        factor = _mm512_mul_ps(factor, factor);
    }
    return acc;
}

static BOOL compare_vectors(__m512 expected, __m512 actual, uint64_t exponent, comparison_result *out) {
    alignas(64) float expected_vals[16];
    alignas(64) float actual_vals[16];
    _mm512_store_ps(expected_vals, expected);
    _mm512_store_ps(actual_vals, actual);

    comparison_result result = {0};
    BOOL matched = TRUE;

    for (uint32_t i = 0; i < 16; ++i) {
        const float exp_val = expected_vals[i];
        const float act_val = actual_vals[i];

        if (exp_val == act_val) {
            continue;
        }
        if (isnan(exp_val) && isnan(act_val)) {
            continue;
        }

        float abs_error = fabsf(act_val - exp_val);
        if (abs_error > result.max_abs_error) {
            result.max_abs_error = abs_error;
            result.lane_index = i;
            result.expected_lane = exp_val;
            result.actual_lane = act_val;
        }

        union {
            float f;
            uint32_t u;
        } exp_bits = { .f = exp_val }, act_bits = { .f = act_val };

        uint32_t ordered_exp = float_to_ordered(exp_bits.u);
        uint32_t ordered_act = float_to_ordered(act_bits.u);
        uint32_t ulp_diff = (ordered_act > ordered_exp) ? (ordered_act - ordered_exp) : (ordered_exp - ordered_act);

        if (ulp_diff > result.max_ulp_error) {
            result.max_ulp_error = ulp_diff;
            result.lane_index = i;
            result.expected_lane = exp_val;
            result.actual_lane = act_val;
        }

        if (ulp_diff > 1u) {
            matched = FALSE;
        }
    }

    if (out) {
        *out = result;
    }

    if (!matched) {
        log_message(LOG_ERROR,
                    "Lane mismatch (exp=%llu) lane=%u abs=%.9g ulp=%u expected=%.9g actual=%.9g",
                    (unsigned long long)exponent,
                    result.lane_index,
                    result.max_abs_error,
                    result.max_ulp_error,
                    result.expected_lane,
                    result.actual_lane);
    }

    return matched;
}

static BOOL execute_case(const char *group, const char *label, __m512 base, uint64_t exponent, functional_stats *stats) {
    __m512 expected = ref_vpowups(base, exponent);
    __m512 actual = vpowups_call(base, exponent);

    ++stats->cases_run;

    comparison_result cmp = {0};
    if (!compare_vectors(expected, actual, exponent, &cmp)) {
        ++stats->failures;
        log_message(LOG_ERROR,
                    "%s/%s failed (exponent=%llu, lane=%u)",
                    group,
                    label,
                    (unsigned long long)exponent,
                    cmp.lane_index);
        return FALSE;
    }
    return TRUE;
}

static BOOL test_exponent_zero(functional_stats *stats) {
    log_message(LOG_INFO, "Testing exponent==0 path");
    BOOL ok = TRUE;

    alignas(64) float set_even[16] = {
        0.0f, -0.0f, 1.0f, -1.0f,
        2.0f, -2.0f, 4.0f, -4.0f,
        8.0f, -8.0f, 16.0f, -16.0f,
        32.0f, -32.0f, 64.0f, -64.0f
    };
    alignas(64) float set_edge[16] = {
        FLT_TRUE_MIN, -FLT_TRUE_MIN, FLT_MIN, -FLT_MIN,
        FLT_MAX, -FLT_MAX, 0.5f, -0.5f,
        3.5f, -3.5f, 11.0f, -11.0f,
        0.25f, -0.25f, 7.0f, -7.0f
    };
    alignas(64) float set_special[16] = {0};
    set_special[0] = make_float_from_bits(0x7fc00000u);     // quiet NaN
    set_special[1] = make_float_from_bits(0xffc00000u);     // negative quiet NaN
    set_special[2] = INFINITY;
    set_special[3] = -INFINITY;
    set_special[4] = 9.5f;
    set_special[5] = -9.5f;
    set_special[6] = 1.0f;
    set_special[7] = -1.0f;
    set_special[8] = 0.03125f;
    set_special[9] = -0.03125f;
    set_special[10] = 128.0f;
    set_special[11] = -128.0f;
    set_special[12] = 512.0f;
    set_special[13] = -512.0f;
    set_special[14] = 1024.0f;
    set_special[15] = -1024.0f;

    __m512 bases[] = {
        _mm512_load_ps(set_even),
        _mm512_load_ps(set_edge),
        _mm512_load_ps(set_special)
    };

    const char *labels[] = {"even", "edge", "special"};

    for (uint32_t i = 0; i < ARRAY_SIZE(bases); ++i) {
        if (!execute_case("exponent_zero", labels[i], bases[i], 0u, stats)) {
            ok = FALSE;
        }
    }

    log_message(LOG_INFO, "Exponent zero cases complete (%u vectors)", (unsigned)ARRAY_SIZE(bases));
    return ok;
}

static BOOL test_exponent_one(functional_stats *stats) {
    log_message(LOG_INFO, "Testing exponent==1 path");
    BOOL ok = TRUE;

    alignas(64) float set_mix[16] = {
        -3.0f, 3.0f, -5.0f, 5.0f,
        -7.0f, 7.0f, -9.0f, 9.0f,
        -11.0f, 11.0f, -13.0f, 13.0f,
        -15.0f, 15.0f, -17.0f, 17.0f
    };
    alignas(64) float set_powers[16] = {
        2.0f, 4.0f, 8.0f, 16.0f,
        32.0f, 64.0f, 128.0f, 256.0f,
        -2.0f, -4.0f, -8.0f, -16.0f,
        -32.0f, -64.0f, -128.0f, -256.0f
    };
    alignas(64) float set_special[16] = {0};
    set_special[0] = make_float_from_bits(0x7fc00000u);
    set_special[1] = make_float_from_bits(0xffc00000u);
    set_special[2] = INFINITY;
    set_special[3] = -INFINITY;
    set_special[4] = FLT_MAX;
    set_special[5] = -FLT_MAX;
    set_special[6] = FLT_TRUE_MIN;
    set_special[7] = -FLT_TRUE_MIN;
    set_special[8] = -0.0f;
    set_special[9] = 0.0f;
    set_special[10] = 1.0f;
    set_special[11] = -1.0f;
    set_special[12] = 0.25f;
    set_special[13] = -0.25f;
    set_special[14] = 1024.0f;
    set_special[15] = -1024.0f;

    __m512 bases[] = {
        _mm512_load_ps(set_mix),
        _mm512_load_ps(set_powers),
        _mm512_load_ps(set_special)
    };

    const char *labels[] = {"mix", "powers", "special"};

    for (uint32_t i = 0; i < ARRAY_SIZE(bases); ++i) {
        if (!execute_case("exponent_one", labels[i], bases[i], 1u, stats)) {
            ok = FALSE;
        }
    }

    log_message(LOG_INFO, "Exponent one cases complete (%u vectors)", (unsigned)ARRAY_SIZE(bases));
    return ok;
}

static BOOL test_power_of_two(functional_stats *stats) {
    log_message(LOG_INFO, "Testing power-of-two exponents");
    BOOL ok = TRUE;

    alignas(64) float base_values[16] = {
        -1.5f, 1.5f, -2.5f, 2.5f,
        -3.5f, 3.5f, -4.5f, 4.5f,
        -5.5f, 5.5f, -6.5f, 6.5f,
        -7.5f, 7.5f, -8.5f, 8.5f
    };
    __m512 base = _mm512_load_ps(base_values);

    for (uint32_t bit = 1; bit <= 16; ++bit) {
        uint64_t exponent = 1ull << bit;
        char label[32];
        HRESULT hr = StringCchPrintfA(label, ARRAY_SIZE(label), "pow2_%u", bit);
        if (FAILED(hr)) {
            continue;
        }
        if (!execute_case("power_of_two", label, base, exponent, stats)) {
            ok = FALSE;
        }
    }

    log_message(LOG_INFO, "Power-of-two exponent sweep complete");
    return ok;
}

static BOOL test_mixed_bit_patterns(functional_stats *stats) {
    log_message(LOG_INFO, "Testing mixed-bit exponents");
    BOOL ok = TRUE;

    const uint64_t exponents[] = {
        0x0000000000000003ull,
        0x0000000000008001ull,
        0x000000000000aaaaull,
        0x000000000000f00dull,
        0x0000ffff0000ffffull,
        0x0f0f0f0f0f0f0f0full,
        0x5555555555555555ull,
        0xaaaaaaaaaaaaaaaaull,
        0xffffffff00000001ull,
        0xffffffffffffffffull
    };

    alignas(64) float base_values[16] = {
        0.25f, -0.25f, 0.5f, -0.5f,
        0.75f, -0.75f, 1.25f, -1.25f,
        1.5f, -1.5f, 2.0f, -2.0f,
        3.0f, -3.0f, 4.0f, -4.0f
    };
    __m512 base = _mm512_load_ps(base_values);

    for (uint32_t i = 0; i < ARRAY_SIZE(exponents); ++i) {
        char label[32];
        HRESULT hr = StringCchPrintfA(label, ARRAY_SIZE(label), "pattern_%u", i);
        if (FAILED(hr)) {
            continue;
        }
        if (!execute_case("mixed_bits", label, base, exponents[i], stats)) {
            ok = FALSE;
        }
    }

    log_message(LOG_INFO, "Mixed exponent patterns complete");
    return ok;
}

static __m512 random_uniform_vector(float min_value, float max_value) {
    alignas(64) float values[16];
    float span = max_value - min_value;

    uint32_t rnd[16];
    if (!random_bytes(rnd, sizeof(rnd))) {
        return _mm512_set1_ps(0.0f);
    }

    for (uint32_t i = 0; i < 16; ++i) {
        float unit = (float)((double)rnd[i] / (double)UINT32_MAX);
        values[i] = min_value + span * unit;
    }
    return _mm512_load_ps(values);
}

static __m512 random_wide_vector(void) {
    return random_uniform_vector(-1000.0f, 1000.0f);
}

static __m512 random_special_vector(void) {
    alignas(64) float values[16];
    const uint32_t specials[] = {
        0x7fc00000u, // +qNaN
        0xffc00000u, // -qNaN
        0x7f800000u, // +inf
        0xff800000u, // -inf
        0x00800000u, // smallest normal
        0x00000001u, // +denorm
        0x80000001u, // -denorm
        0x3f800000u, // +1.0
        0xbf800000u, // -1.0
        0x3f000000u, // +0.5
        0xbf000000u, // -0.5
        0x4f000000u, // large positive
        0xcf000000u, // large negative
        0x00000000u, // +0
        0x80000000u, // -0
        0x3fc00000u  // +1.5
    };

    uint32_t choice[16];
    if (!random_bytes(choice, sizeof(choice))) {
        return _mm512_set1_ps(0.0f);
    }

    for (uint32_t lane = 0; lane < 16; ++lane) {
        uint32_t index = choice[lane] % ARRAY_SIZE(specials);
        values[lane] = make_float_from_bits(specials[index]);
    }
    return _mm512_load_ps(values);
}

static void destroy_heatmap(app_state *state) {
    if (!state) {
        return;
    }
    if (state->heat_bitmap) {
        DeleteObject(state->heat_bitmap);
        state->heat_bitmap = NULL;
    }
    state->heat_pixels = NULL;
    state->heat_width = 0;
    state->heat_height = 0;
    ZeroMemory(&state->heat_info, sizeof(state->heat_info));
}

static BOOL ensure_heatmap_surface(app_state *state, UINT width, UINT height) {
    if (!state || width == 0 || height == 0) {
        destroy_heatmap(state);
        return FALSE;
    }

    if (state->heat_bitmap && state->heat_width == width && state->heat_height == height) {
        return TRUE;
    }

    destroy_heatmap(state);

    ZeroMemory(&state->heat_info, sizeof(state->heat_info));
    state->heat_info.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
    state->heat_info.bmiHeader.biWidth = (LONG)width;
    state->heat_info.bmiHeader.biHeight = -(LONG)height; // top-down DIB
    state->heat_info.bmiHeader.biPlanes = 1;
    state->heat_info.bmiHeader.biBitCount = 32;
    state->heat_info.bmiHeader.biCompression = BI_RGB;

    void *pixels = NULL;
    HBITMAP bitmap = CreateDIBSection(
        NULL,
        &state->heat_info,
        DIB_RGB_COLORS,
        &pixels,
        NULL,
        0);
    if (!bitmap || !pixels) {
        if (bitmap) {
            DeleteObject(bitmap);
        }
        return FALSE;
    }

    state->heat_bitmap = bitmap;
    state->heat_pixels = (uint32_t *)pixels;
    state->heat_width = width;
    state->heat_height = height;
    ZeroMemory(state->heat_pixels, width * height * sizeof(uint32_t));
    return TRUE;
}

static void decay_heatmap(app_state *state, double decay) {
    if (!state || !state->heat_pixels) {
        return;
    }
    if (decay < 0.0) {
        decay = 0.0;
    } else if (decay > 1.0) {
        decay = 1.0;
    }

    const uint32_t total_pixels = state->heat_width * state->heat_height;
    uint32_t *pixels = state->heat_pixels;
    for (uint32_t i = 0; i < total_pixels; ++i) {
        uint32_t color = pixels[i];
        uint8_t blue = (uint8_t)(color & 0xffu);
        uint8_t green = (uint8_t)((color >> 8) & 0xffu);
        uint8_t red = (uint8_t)((color >> 16) & 0xffu);

        blue = (uint8_t)(blue * decay);
        green = (uint8_t)(green * decay);
        red = (uint8_t)(red * decay);

        pixels[i] = (uint32_t)(blue | (green << 8) | (red << 16));
    }
}

static void plot_heatmap_samples(app_state *state, int chart_width, int chart_height, int bar_width, int spacing, const double current_values[], const uint64_t sample_counts[], double max_tick) {
    if (!state || !state->heat_pixels || max_tick <= 0.0 || chart_width <= 0 || chart_height <= 0) {
        return;
    }

    const int bar_step = bar_width + spacing;
    for (uint32_t bit = 0; bit < PERF_BAR_COUNT; ++bit) {
        if (sample_counts[bit] == 0) {
            continue;
        }

        double norm = current_values[bit] / max_tick;
        if (norm < 0.0) {
            norm = 0.0;
        } else if (norm > 1.0) {
            norm = 1.0;
        }

        int line_y = chart_height - 1 - (int)(norm * (double)(chart_height - 1));
        if (line_y < 0) {
            line_y = 0;
        } else if (line_y >= chart_height) {
            line_y = chart_height - 1;
        }

        int bar_x = (int)bit * bar_step;
        for (int dx = 0; dx < bar_width; ++dx) {
            int px = bar_x + dx;
            if (px < 0 || px >= (int)state->heat_width) {
                continue;
            }
            const int index = line_y * (int)state->heat_width + px;
            state->heat_pixels[index] = 0x000000FFu;
        }
    }
}

static void blit_heatmap(HDC hdc, int dst_left, int dst_top, const app_state *state) {
    if (!state || !state->heat_pixels || !state->heat_bitmap) {
        return;
    }

    SetDIBitsToDevice(
        hdc,
        dst_left,
        dst_top,
        state->heat_width,
        state->heat_height,
        0,
        0,
        0,
        state->heat_height,
        state->heat_pixels,
        &state->heat_info,
        DIB_RGB_COLORS);
}

static BOOL test_randomized(functional_stats *stats) {
    log_message(LOG_INFO, "Testing randomized exponent/base combinations");
    BOOL ok = TRUE;

    for (uint32_t i = 0; i < 1024; ++i) {
        uint64_t exponent = 0;
        if (!random_bytes(&exponent, sizeof(exponent))) {
            ok = FALSE;
            break;
        }

        __m512 base = random_uniform_vector(-4.0f, 4.0f);
        if (!execute_case("random_uniform", "unit_range", base, exponent, stats)) {
            ok = FALSE;
        }
    }

    for (uint32_t i = 0; i < 512; ++i) {
        uint64_t exponent = 0;
        if (!random_bytes(&exponent, sizeof(exponent))) {
            ok = FALSE;
            break;
        }

        __m512 base = random_wide_vector();
        if (!execute_case("random_wide", "wide_range", base, exponent, stats)) {
            ok = FALSE;
        }
    }

    for (uint32_t i = 0; i < 256; ++i) {
        uint64_t exponent = 0;
        if (!random_bytes(&exponent, sizeof(exponent))) {
            ok = FALSE;
            break;
        }

        __m512 base = random_special_vector();
        if (!execute_case("random_special", "special_range", base, exponent, stats)) {
            ok = FALSE;
        }
    }

    log_message(LOG_INFO, "Randomized testing complete");
    return ok;
}

static BOOL run_functional_tests(app_state *state) {
    functional_stats stats = {0};

    BOOL ok = TRUE;
    ok &= test_exponent_zero(&stats);
    ok &= test_exponent_one(&stats);
    ok &= test_power_of_two(&stats);
    ok &= test_mixed_bit_patterns(&stats);
    ok &= test_randomized(&stats);

    InterlockedExchangeAdd(&state->functional_cases, (LONG)stats.cases_run);
    InterlockedExchangeAdd(&state->functional_failures, (LONG)stats.failures);
    state->functional_done = TRUE;

    if (ok) {
        log_message(LOG_INFO,
                    "Functional testing passed (%u cases, %u failures)",
                    stats.cases_run,
                    stats.failures);
    } else {
        log_message(LOG_ERROR,
                    "Functional testing encountered failures (%u cases, %u failures)",
                    stats.cases_run,
                    stats.failures);
    }
    return ok;
}

static uint64_t generate_exponent_for_bit(uint32_t bit_index) {
    if (bit_index == 0u) {
        return 0u;
    }

    uint64_t exponent = 1ull << (bit_index - 1u);
    uint64_t lower_mask = exponent - 1ull;

    uint64_t random_bits = 0;
    if (!random_bytes(&random_bits, sizeof(random_bits))) {
        random_bits = lower_mask;
    }

    exponent |= random_bits & lower_mask;
    return exponent;
}

static void run_performance_monitor(app_state *state) {
    log_message(LOG_INFO, "Starting performance sampler");

    const uint32_t warmup_iterations = 10000;
    const uint32_t sample_iterations = 20000;

    SetThreadPriority(GetCurrentThread(), THREAD_PRIORITY_ABOVE_NORMAL);
    DWORD_PTR previous_affinity = SetThreadAffinityMask(GetCurrentThread(), 1);

    LARGE_INTEGER freq = {0};
    QueryPerformanceFrequency(&freq);
    state->tick_frequency = (double)freq.QuadPart;

    __m512 base = random_uniform_vector(-3.0f, 3.0f);
    for (uint32_t i = 0; i < warmup_iterations && state->running; ++i) {
        base = vpowups_call(base, (uint64_t)(i | 1u));
    }

    while (state->running) {
        double local_max_avg = 0.0;
        BOOL any_samples = FALSE;

        for (uint32_t bit = 0; bit < PERF_BAR_COUNT && state->running; ++bit) {
            __m512 base_vec = random_uniform_vector(-4.0f, 4.0f);
//            if (bit & 1u) {
//                base_vec = random_special_vector();
//            }

            uint64_t exponent = generate_exponent_for_bit(bit + 1u);

            LARGE_INTEGER start = {0}, end = {0};
            QueryPerformanceCounter(&start);

            __m512 acc = base_vec;
            for (uint32_t iter = 0; iter < sample_iterations; ++iter) {
                acc = vpowups_call(base_vec, exponent);
            }

            QueryPerformanceCounter(&end);
            alignas(64) float spill[16];
            _mm512_store_ps(spill, acc);
            for (uint32_t lane = 0; lane < 16; ++lane) {
                g_sink[lane] = spill[lane];
            }

            double ticks = (double)(end.QuadPart - start.QuadPart);
            double ticks_per_call = ticks / (double)sample_iterations;

            AcquireSRWLockExclusive(&state->perf_lock);
            uint64_t count = ++state->sample_counts[bit];
            double previous_avg = state->avg_ticks[bit];
            double new_avg = (count == 1)
                                 ? ticks_per_call
                                 : previous_avg + (ticks_per_call - previous_avg) / (double)count;
            state->avg_ticks[bit] = new_avg;

            double previous_min = state->min_ticks[bit];
            if (count == 1 || previous_min <= 0.0 || ticks_per_call < previous_min) {
                state->min_ticks[bit] = ticks_per_call;
            }

            state->current_ticks[bit] = ticks_per_call;
            if (new_avg > local_max_avg) {
                local_max_avg = new_avg;
            }
            any_samples = TRUE;
            ReleaseSRWLockExclusive(&state->perf_lock);
        }

        if (!any_samples) {
            continue;
        }

        AcquireSRWLockExclusive(&state->perf_lock);
        if (local_max_avg > state->max_tick) {
            state->max_tick = local_max_avg;
        } else if (state->max_tick > 0.0) {
            state->max_tick = state->max_tick * 0.9 + local_max_avg * 0.1;
        } else {
            state->max_tick = local_max_avg;
        }
        state->perf_ready = TRUE;
        ReleaseSRWLockExclusive(&state->perf_lock);

        if (state->hwnd) {
            PostMessageW(state->hwnd, WM_APP_PERF_UPDATE, 0, 0);
        }
        Sleep(50);
    }

    if (previous_affinity != 0) {
        SetThreadAffinityMask(GetCurrentThread(), previous_affinity);
    }
    log_message(LOG_INFO, "Performance sampler stopped");
}

static DWORD WINAPI worker_thread_proc(LPVOID param) {
    app_state *state = (app_state *)param;
    if (!state) {
        return 1;
    }

    HMODULE kernel = GetModuleHandleW(L"kernel32.dll");
    if (kernel) {
        typedef HRESULT (WINAPI *set_thread_description_fn)(HANDLE, PCWSTR);
        set_thread_description_fn set_description = (set_thread_description_fn)GetProcAddress(kernel, "SetThreadDescription");
        if (set_description) {
            set_description(GetCurrentThread(), L"vpowups worker");
        }
    }

    if (!run_functional_tests(state)) {
        state->running = 0;
        if (state->hwnd) {
            PostMessageW(state->hwnd, WM_CLOSE, 0, 0);
        }
        return 2;
    }

    run_performance_monitor(state);
    return 0;
}

static ATOM register_window_class(HINSTANCE instance) {
    WNDCLASSEXW wc = {
        .cbSize = sizeof(WNDCLASSEXW),
        .style = CS_HREDRAW | CS_VREDRAW,
        .lpfnWndProc = main_wnd_proc,
        .cbClsExtra = 0,
        .cbWndExtra = 0,
        .hInstance = instance,
        .hIcon = LoadIconW(NULL, IDI_APPLICATION),
        .hCursor = LoadCursorW(NULL, IDC_ARROW),
        .hbrBackground = 0, //(HBRUSH)(COLOR_WINDOW + 1),
        .lpszMenuName = NULL,
        .lpszClassName = L"vpowupsWindowClass",
        .hIconSm = LoadIconW(NULL, IDI_APPLICATION)
    };
    return RegisterClassExW(&wc);
}

static HWND create_main_window(HINSTANCE instance, app_state *state) {
    RECT desired = {0, 0, 960, 480};
    AdjustWindowRectEx(&desired, WS_OVERLAPPEDWINDOW, FALSE, WS_EX_APPWINDOW);

    HWND hwnd = CreateWindowExW(
        WS_EX_APPWINDOW,
        L"vpowupsWindowClass",
        L"vpowups Performance Monitor",
        WS_OVERLAPPEDWINDOW,
        CW_USEDEFAULT, CW_USEDEFAULT,
        desired.right - desired.left,
        desired.bottom - desired.top,
        NULL,
        NULL,
        instance,
        state);

    return hwnd;
}

static void draw_performance_chart(HDC hdc, const RECT *client, app_state *state) {
    RECT rect = *client;
    HBRUSH background = CreateSolidBrush(RGB(20, 20, 20));
    FillRect(hdc, &rect, background);
    DeleteObject(background);

    HFONT font = (HFONT)GetStockObject(DEFAULT_GUI_FONT);
    HFONT old_font = (HFONT)SelectObject(hdc, font);
    SetBkMode(hdc, TRANSPARENT);
    SetTextColor(hdc, RGB(230, 230, 230));

    double min_values[PERF_BAR_COUNT] = {0};
    double current_values[PERF_BAR_COUNT] = {0};
    uint64_t sample_counts[PERF_BAR_COUNT] = {0};
    double max_tick = 0.0;
    BOOL ready = FALSE;
    LONG cases = 0;
    LONG failures = 0;
    BOOL done = FALSE;
    double tick_frequency = 0.0;

    AcquireSRWLockShared(&state->perf_lock);
    memcpy(min_values, state->min_ticks, sizeof(min_values));
    memcpy(current_values, state->current_ticks, sizeof(current_values));
    memcpy(sample_counts, state->sample_counts, sizeof(sample_counts));
    max_tick = state->max_tick;
    ready = state->perf_ready;
    tick_frequency = state->tick_frequency;
    ReleaseSRWLockShared(&state->perf_lock);

    cases = state->functional_cases;
    failures = state->functional_failures;
    done = state->functional_done;

    if (!ready || max_tick <= 0.0) {
        const WCHAR *message = L"Collecting performance samples...";
        TextOutW(hdc, 16, 16, message, (int)wcslen(message));
        SelectObject(hdc, old_font);
        return;
    }

    int width = rect.right - rect.left;
    int height = rect.bottom - rect.top;
    int chart_top = 30;
    int chart_bottom = height - 20;
    int chart_height = chart_bottom - chart_top;
    int chart_left = 20;
    int chart_right = width - 20;
    int chart_width = chart_right - chart_left;

    const int spacing = 2;
    int available_bar_width = chart_width - spacing * (int)(PERF_BAR_COUNT - 1);
    if (available_bar_width < 0) {
        available_bar_width = 0;
    }
    int bar_width = max(4, available_bar_width / (int)PERF_BAR_COUNT);

    if (chart_width > 0 && chart_height > 0) {
        if (ensure_heatmap_surface(state, (UINT)chart_width, (UINT)chart_height)) {
            decay_heatmap(state, 1.0 - 1.0/255.0);
            plot_heatmap_samples(state, chart_width, chart_height, bar_width, spacing, current_values, sample_counts, max_tick);
            blit_heatmap(hdc, chart_left, chart_top, state);
        }
    }

    HPEN grid_pen = CreatePen(PS_SOLID, 1, RGB(80, 80, 80));
    HPEN old_pen = (HPEN)SelectObject(hdc, grid_pen);

    MoveToEx(hdc, chart_left, chart_bottom, NULL);
    LineTo(hdc, chart_right, chart_bottom);

    MoveToEx(hdc, chart_left, chart_top, NULL);
    LineTo(hdc, chart_left, chart_bottom);

    MoveToEx(hdc, chart_right, chart_top, NULL);
    LineTo(hdc, chart_right, chart_bottom);

    SelectObject(hdc, old_pen);
    DeleteObject(grid_pen);

    HBRUSH bar_brush = CreateSolidBrush(failures ? RGB(220, 20, 60) : RGB(30, 144, 255));
    HPEN red_pen = CreatePen(PS_SOLID, 2, RGB(220, 20, 60));
    HPEN old_pen_red = (HPEN)SelectObject(hdc, red_pen);

    for (uint32_t bit = 0; bit < PERF_BAR_COUNT; ++bit) {
        if (sample_counts[bit] == 0) {
            continue;
        }

        double normalized = min_values[bit] / max_tick;
        if (normalized > 1.0) {
            normalized = 1.0;
        }
        int bar_height = (int)(normalized * chart_height);
        int bar_x = chart_left + (int)bit * (bar_width + spacing);
        int bar_right = min(bar_x + bar_width, chart_right);
        RECT bar_rect = {
            bar_x,
            chart_bottom - bar_height,
            bar_right,
            chart_bottom
        };
        if (bar_rect.left < chart_left) {
            bar_rect.left = chart_left;
        }
        if (bar_rect.left < bar_rect.right) {
            FillRect(hdc, &bar_rect, bar_brush);
        }

        double current_norm = current_values[bit] / max_tick;
        if (current_norm > 1.0) {
            current_norm = 1.0;
        }
        if (current_norm < 0.0) {
            current_norm = 0.0;
        }
        int line_y = chart_bottom - (int)(current_norm * chart_height);
        MoveToEx(hdc, max(bar_x, chart_left), line_y, NULL);
        LineTo(hdc, bar_right, line_y);

        if (bit % 8u == 0u) {
            WCHAR label[16];
            StringCchPrintfW(label, ARRAY_SIZE(label), L"%u", bit);
            TextOutW(hdc, bar_x, chart_bottom + 4, label, (int)wcslen(label));
        }
    }

    DeleteObject(bar_brush);
    SelectObject(hdc, old_pen_red);
    DeleteObject(red_pen);

    WCHAR summary[128];
    double microseconds = (max_tick / tick_frequency) * 1e6;
    StringCchPrintfW(summary, ARRAY_SIZE(summary),
                     L"Peak avg: %.2f ticks (%.3f µs) | Cases: %ld | Failures: %ld%s",
                     max_tick,
                     microseconds,
                     cases,
                     failures,
                     done ? L" | Functional OK" : L"");
    TextOutW(hdc, chart_left, chart_top - 24, summary, (int)wcslen(summary));

    SelectObject(hdc, old_font);
}

static LRESULT CALLBACK main_wnd_proc(HWND hwnd, UINT message, WPARAM w_param, LPARAM l_param) {
    switch (message) {
        case WM_CREATE: {
            CREATESTRUCTW *create = (CREATESTRUCTW *)l_param;
            app_state *state = (app_state *)create->lpCreateParams;
            SetWindowLongPtrW(hwnd, GWLP_USERDATA, (LONG_PTR)state);
            state->hwnd = hwnd;
            return 0;
        }
        case WM_APP_PERF_UPDATE:
            InvalidateRect(hwnd, NULL, FALSE);
            return 0;
        case WM_ERASEBKGND:
            return 1;
        case WM_PAINT: {
            PAINTSTRUCT ps;
            HDC hdc = BeginPaint(hwnd, &ps);
            app_state *state = (app_state *)GetWindowLongPtrW(hwnd, GWLP_USERDATA);
            if (state) {
                draw_performance_chart(hdc, &ps.rcPaint, state);
            }
            EndPaint(hwnd, &ps);
            return 0;
        }
        case WM_DESTROY: {
            app_state *state = (app_state *)GetWindowLongPtrW(hwnd, GWLP_USERDATA);
            if (state) {
                state->running = 0;
                destroy_heatmap(state);
            }
            PostQuitMessage(0);
            return 0;
        }
        case WM_CLOSE:
            DestroyWindow(hwnd);
            return 0;
        default:
            return DefWindowProcW(hwnd, message, w_param, l_param);
    }
}

int APIENTRY wWinMain(HINSTANCE instance, HINSTANCE prev_instance, LPWSTR cmd_line, int show_flag) {
    UNREFERENCED_PARAMETER(prev_instance);
    UNREFERENCED_PARAMETER(cmd_line);

    init_console();
    InitializeSRWLock(&g_app.perf_lock);
    g_app.running = 1;

    if (!register_window_class(instance)) {
        log_message(LOG_ERROR, "Failed to register window class");
        return -1;
    }

    HWND hwnd = create_main_window(instance, &g_app);
    if (!hwnd) {
        log_message(LOG_ERROR, "Failed to create main window");
        return -1;
    }

    ShowWindow(hwnd, show_flag);
    UpdateWindow(hwnd);

    g_app.worker_thread = CreateThread(NULL, 0, worker_thread_proc, &g_app, 0, NULL);
    if (!g_app.worker_thread) {
        log_message(LOG_ERROR, "Failed to start worker thread");
        DestroyWindow(hwnd);
        return -1;
    }

    MSG msg;
    while (GetMessageW(&msg, NULL, 0, 0) > 0) {
        TranslateMessage(&msg);
        DispatchMessageW(&msg);
    }

    g_app.running = 0;
    if (g_app.worker_thread) {
        WaitForSingleObject(g_app.worker_thread, INFINITE);
        CloseHandle(g_app.worker_thread);
        g_app.worker_thread = NULL;
    }

    return (int)msg.wParam;
}

int main(void) {
    HINSTANCE instance = GetModuleHandleW(NULL);
    return wWinMain(instance, NULL, GetCommandLineW(), SW_SHOWDEFAULT);
}
