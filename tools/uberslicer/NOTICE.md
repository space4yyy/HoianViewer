# uberslicer

Prebuilt `uberspec` binaries, one folder per platform.
Source at [https://github.com/nvnprogram/UberSlicer](https://github.com/nvnprogram/UberSlicer)

The `osx-arm64/uberspec` binary is built with Apple Clang from upstream commit
`892d0397197a192740c1a76220a2ebbbdf2ec326` (codegen 3).
Rebuild with `sh tools/uberslicer/build-macos.sh [source-directory]`.
The macOS build omits upstream's unsupported `-static` link flag.
The upstream fragment and vertex examples passed structural gates on Apple Silicon;
the reference-program gate was not run because no independently compiled program
was supplied.
