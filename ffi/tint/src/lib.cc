#include "tint_ffi.h"
#include <cassert>
#include <tint.h>

struct tint_converter_t {};

extern "C" tint_converter_t *tint_init() { return new tint_converter_t{}; }

extern "C" void tint_exit(tint_converter_t *converter) { delete converter; }

extern "C" size_t tint_convert_spirv_to_wgsl(tint_converter_t *,
                                             unsigned int const *spv,
                                             size_t spv_size) {
  std::vector<unsigned int> data;
  data.assign(spv, spv + spv_size); // overhead of C FFI
  auto program = tint::reader::spirv::Parse(data);
  auto diag = program.Diagnostics();
  for (const auto &msg : diag) {
    std::cout << msg.message << std::endl;
  }

  tint::writer::wgsl::Options gen_options;
  auto result = tint::writer::wgsl::Generate(&program, gen_options);
  assert(result.success);
  return result.wgsl.length();
}

extern "C" size_t tint_convert_spirv_to_msl(tint_converter_t *,
                                            unsigned int const *spv,
                                            size_t spv_size) {
  std::vector<unsigned int> data;
  data.assign(spv, spv + spv_size); // overhead of C FFI
  auto program = tint::reader::spirv::Parse(data);
  auto diag = program.Diagnostics();
  for (const auto &msg : diag) {
    std::cout << msg.message << std::endl;
  }

  tint::writer::msl::Options gen_options;
  auto result = tint::writer::msl::Generate(&program, gen_options);
  assert(result.success);
  return result.msl.length();
}
