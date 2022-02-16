with import <nixpkgs> {};
mkShell {
  buildInputs = [
    # rust
    cargo
    rustc
    # tools
    gdb
    cmake
    cmakeCurses
    meson
    ninja
    pkgconfig
    python
    (python3.withPackages(ps: [
      ps.setuptools
      ps.Mako
    ]))
    bison
    flex
    zip
  ];
}
