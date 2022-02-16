cmake_minimum_required(VERSION 3.13)
project(shader-translation-benchmark)

# https://github.com/corrosion-rs/corrosion/issues/145
#add_subdirectory(mod/corrosion)
#find_package(Corrosion REQUIRED)

add_executable(bench src/main.c)

# Configure dependencies
set(ENABLE_GLSLANG_BINARIES OFF CACHE BOOL "")
set(TINT_THIRD_PARTY_DIR ${shader-translation-benchmark_SOURCE_DIR}/mod)
set(TINT_BUILD_SAMPLES OFF)
set(SPIRV-Headers_SOURCE_DIR ${shader-translation-benchmark_SOURCE_DIR}/mod/spirv-headers)
# the caching is needed because SPIRV-Cross doesn't use `option_if_not_defined`
set(SPIRV_CROSS_CLI OFF CACHE BOOL "")
set(SPIRV_CROSS_ENABLE_CPP OFF CACHE BOOL "")
set(SPIRV_CROSS_ENABLE_TESTS OFF CACHE BOOL "")
set(SPIRV_CROSS_ENABLE_REFLECT OFF CACHE BOOL "")

# Add dependencies
add_subdirectory(mod/glslang glslang)
add_subdirectory(mod/tint tint)
add_subdirectory(mod/spirv-cross spirv-cross)

# Register Naga-FFI
#corrosion_import_crate(MANIFEST_PATH ${CMAKE_SOURCE_DIR}/naga-ffi)
add_custom_target(
    naga-ffi
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}/naga-ffi
    COMMAND cargo build --release
)
set_target_properties (bench PROPERTIES IMPORTED_LOCATION {CMAKE_SOURCE_DIR}/naga-ffi/target)
add_dependencies(bench naga-ffi)
target_link_directories(bench PRIVATE ${CMAKE_SOURCE_DIR}/naga-ffi/target/release)

# Add headers
target_include_directories(bench PRIVATE mod/glslang/glslang/Include/)
#target_include_directories(bench PRIVATE mod/tint")
target_include_directories(bench PRIVATE naga-ffi)

# Link
target_link_libraries(bench PRIVATE
  # Glslang
  glslang OSDependent OGLCompiler HLSL glslang SPIRV
  # Tint
  libtint
  # SPIRV-Cross
  spirv-cross-c
  # Naga FFI
  -Wl,--no-as-needed ${CMAKE_DL_LIBS}
  naga_ffi
)
