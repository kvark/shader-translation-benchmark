#include "tint_ffi.h"
#include <cassert>
#include <cstring>
#include <tint.h>

struct tint_converter_t {};

extern "C" tint_converter_t *tint_init() { return new tint_converter_t{}; }

extern "C" void tint_exit(tint_converter_t *converter) { delete converter; }

extern "C" size_t tint_convert_spirv_to_wgsl(tint_converter_t *,
                                             uint32_t const *spv,
                                             size_t word_count) {
  std::vector<uint32_t> data;
  data.assign(spv, spv + word_count); // overhead of C FFI
  auto program = tint::reader::spirv::Parse(data);
  if (!program.IsValid()) {
    auto diag = program.Diagnostics();
    for (const auto &msg : diag) {
      std::cerr << msg.message << std::endl;
    }
    return 0;
  }

  tint::writer::wgsl::Options gen_options;
  auto result = tint::writer::wgsl::Generate(&program, gen_options);
  assert(result.success);
  return result.wgsl.length();
}

extern "C" size_t tint_convert_spirv_to_msl(tint_converter_t *,
                                            uint32_t const *spv,
                                            size_t word_count) {
  std::vector<uint32_t> data;
  data.assign(spv, spv + word_count); // overhead of C FFI
  auto program = tint::reader::spirv::Parse(data);
  if (!program.IsValid()) {
    auto diag = program.Diagnostics();
    for (const auto &msg : diag) {
      std::cerr << msg.message << std::endl;
    }
    return 0;
  }

  tint::writer::msl::Options gen_options;
  auto result = tint::writer::msl::Generate(&program, gen_options);
  assert(result.success);
  return result.msl.length();
}

extern "C" size_t tint_convert_wgsl_to_glsl(tint_converter_t *,
                                            char const *source,
                                            char const *entry_point) {
  auto file = tint::Source::File("unknown", std::string(source));

  auto program = tint::reader::wgsl::Parse(&file);
  if (!program.IsValid()) {
    auto diag = program.Diagnostics();
    for (const auto &msg : diag) {
      std::cerr << msg.message << " at line " << msg.source.range.begin.line
              << std::endl;
    }
    return 0;
  }

  tint::writer::glsl::Options gen_options;
  auto result = tint::writer::glsl::Generate(&program, gen_options,
                                             std::string(entry_point));
  assert(result.success);
  return result.glsl.length();
}
