cmake_minimum_required(VERSION 2.8.12)
project(shader-translation-benchmark)

add_executable(bench src/main.c)

set(ENABLE_GLSLANG_BINARIES OFF CACHE BOOL "")
set(TINT_THIRD_PARTY_DIR ${shader-translation-benchmark_SOURCE_DIR}/mod)
set(TINT_BUILD_SAMPLES OFF)
set(SPIRV-Headers_SOURCE_DIR ${shader-translation-benchmark_SOURCE_DIR}/mod/spirv-headers)
# the caching is needed because SPIRV-Cross doesn't use `option_if_not_defined`
set(SPIRV_CROSS_CLI OFF CACHE BOOL "")
set(SPIRV_CROSS_ENABLE_CPP OFF CACHE BOOL "")
set(SPIRV_CROSS_ENABLE_TESTS OFF CACHE BOOL "")
set(SPIRV_CROSS_ENABLE_REFLECT OFF CACHE BOOL "")

add_subdirectory(mod/glslang glslang)
add_subdirectory(mod/tint tint)
add_subdirectory(mod/spirv-cross spirv-cross)

target_include_directories(bench PRIVATE mod/glslang/glslang/Public/)
#target_include_directories(bench PRIVATE mod/tint")

target_link_libraries(bench PRIVATE
  # Glslang
  glslang OSDependent OGLCompiler HLSL glslang SPIRV
  # Tint
  libtint
  # SPIRV-Cross
  spirv-cross-c
)
