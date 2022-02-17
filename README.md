# shader-translation-benchmark
[![Build Status](https://github.com/kvark/shader-translation-benchmark/workflows/CI/badge.svg)](https://github.com/kvark/shader-translation-benchmark/actions)

Benchmarking tools for shader translators:
  - [naga](https://github.com/gfx-rs/naga)
  - [tint](https://dawn.googlesource.com/tint/)
  - [glslang](https://github.com/KhronosGroup/glslang)
  - [spirv-cross](https://github.com/KhronosGroup/SPIRV-Cross)

## Results

These are some of the conversion paths, in ms (lower is better):

<img width=30% src="visual/products/GLSL2SPIRV.svg" alt="GLSL->SPIRV"><img width=30% src="visual/products/WGSL2GLSL.svg" alt="WGSL->GLSL"><img width=30% src="visual/products/SPIRV2MSL.svg" alt="SPIRV->MSL">

## Building

On NixOS, just `nix-shell` into the current folder to pick up the included `default.nix` environment.
On other Linux systems, install packages listed in this file (see `buildInputs`).
On Windows... use Linux for development.

```bash
mkdir build
cd build
cmake .. -DCMAKE_BUILD_TYPE=RelWithDebInfo
make -j
```

## Running
```bash
build/bench
```
