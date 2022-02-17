# shader-translation-benchmark
[![Build Status](https://github.com/kvark/shader-translation-benchmark/workflows/CI/badge.svg)](https://github.com/kvark/shader-translation-benchmark/actions)

Benchmarking tools for shader translators:
  - [naga](https://github.com/gfx-rs/naga)
  - [tint](https://dawn.googlesource.com/tint/)
  - [glslang](https://github.com/KhronosGroup/glslang)
  - [spirv-cross](https://github.com/KhronosGroup/SPIRV-Cross)

## Results

```
GLSL -> SPIRV (2 shaders)
        naga: 1692 us
        glslang: 49548 us
WGSL -> GLSL (2 shaders)
        naga: 315 us
        tint: 5712 us
SPIRV -> MSL (1 shaders)
        naga: 895 us
        tint: 6957 us
```

## Building

On NixOS, just `nix-shell` into the current folder to pick up the included `default.nix` environment.
On other Linux systems, install packages listed in this file (see `buildInputs`).
On Windows... use Linux for development.

```bash
mkdir build
cd build
cmake .. -DCMAKE_BUILD_TYPE=RelWithDebugInfo
make -j
```

## Running
```bash
build/bench
```
