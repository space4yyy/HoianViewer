#!/bin/sh
# Build the upstream native shader specialiser for Apple Silicon.
set -eu
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
source_dir=${1:-"${TMPDIR:-/tmp}/HoianViewer-UberSlicer"}
if [ ! -d "$source_dir/.git" ]; then
    git clone https://github.com/nvnprogram/UberSlicer.git "$source_dir"
    git -C "$source_dir" checkout 892d0397197a192740c1a76220a2ebbbdf2ec326
fi
cd "$source_dir"
mkdir -p build-macos out "$script_dir/osx-arm64"
clang -arch arm64 -O3 -std=c11 -w -c src/scheduler.c -o build-macos/scheduler.o
for source in fastalloc xxh3 decode spec alloc emit reorder passes main; do
    clang++ -arch arm64 -O3 -std=c++17 -c "src/$source.cpp" -o "build-macos/$source.o"
done
# macOS links its system runtime dynamically; upstream's -static is unsupported.
clang++ -arch arm64 -O3 build-macos/*.o -o out/uberspec
cp out/uberspec "$script_dir/osx-arm64/uberspec"
chmod +x "$script_dir/osx-arm64/uberspec"
"$script_dir/osx-arm64/uberspec" codegen
