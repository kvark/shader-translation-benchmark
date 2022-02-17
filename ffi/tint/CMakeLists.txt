set(CMAKE_CXX_STANDARD 17)

add_compile_definitions(
    TINT_BUILD_SPV_READER=1
    TINT_BUILD_WGSL_READER=1
    TINT_BUILD_WGSL_WRITER=1
    TINT_BUILD_MSL_WRITER=1
    TINT_BUILD_GLSL_WRITER=1
)

add_library(tint-ffi STATIC
    src/lib.cc
)

target_include_directories(tint-ffi PRIVATE ${CMAKE_SOURCE_DIR}/mod/tint/include/tint/ ${CMAKE_SOURCE_DIR}/mod/tint/)
