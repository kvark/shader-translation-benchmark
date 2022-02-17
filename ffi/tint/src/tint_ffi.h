#ifndef TINT_FFI
#define TINT_FFI

struct tint_converter_t;

#ifdef __cplusplus
#include <cstddef>
#define TINT_FFI_EXPORT extern "C"
#else
#define TINT_FFI_EXPORT extern
#endif

TINT_FFI_EXPORT struct tint_converter_t* tint_init();
TINT_FFI_EXPORT void tint_exit(struct tint_converter_t*);
// generate WGSL and report its size, assuming it's correct
TINT_FFI_EXPORT size_t tint_convert_spirv_to_wgsl(struct tint_converter_t*, unsigned int const*, size_t);
// generate MSL and report its size, assuming it's correct
TINT_FFI_EXPORT size_t tint_convert_spirv_to_msl(struct tint_converter_t*, unsigned int const*, size_t);
// generate GLSL and report its size, assuming it's correct
TINT_FFI_EXPORT size_t tint_convert_wgsl_to_glsl(struct tint_converter_t*, char const*, char const*);

#endif //TINT_FFI
