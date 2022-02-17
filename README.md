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
        naga: 1554 us
        glslang: 51792 us
SPIRV -> MSL (1 shaders)
        naga: 904 us
        tint: 6938 us
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
