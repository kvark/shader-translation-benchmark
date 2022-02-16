set(CMAKE_CXX_STANDARD 17)

add_library(tint-ffi STATIC
    src/lib.cc
)

target_include_directories(tint-ffi PRIVATE ${CMAKE_SOURCE_DIR}/mod/tint/include/tint/ ${CMAKE_SOURCE_DIR}/mod/tint/)
