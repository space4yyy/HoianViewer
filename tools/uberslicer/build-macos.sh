#!/bin/sh
# Build the upstream native shader specialiser for Apple Silicon.
set -eu
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
source_dir=${1:-"${TMPDIR:-/tmp}/HoianViewer-UberSlicer"}
if [ ! -d "$source_dir/.git" ]; then
    git clone https://github.com/nvnprogram/UberSlicer.git "$source_dir"
    git -C "$source_dir" checkout c32fcf2a7dd6cc19d733dc156f755197e486c880
fi
cd "$source_dir"
mkdir -p build-macos out "$script_dir/osx-arm64"
clang -arch arm64 -O3 -std=c11 -w -iquote src/sm50 -c src/sm50/sched/scheduler.c -o build-macos/scheduler.o
objects="build-macos/scheduler.o"
for source in fastalloc xxh3 decode spec sm86/spec86 alloc emit reorder passes sm86/isa_sm86 sm86/sched86 main; do
    object="build-macos/$(basename "$source").o"
    clang++ -arch arm64 -O3 -std=c++17 -c "src/$source.cpp" -o "$object"
    objects="$objects $object"
done
clang++ -arch arm64 -O2 -std=c++17 -c src/sm86/sm86.cpp -o build-macos/sm86.o
objects="$objects build-macos/sm86.o"
for source in classify deps ext issue machine opex owo phase_a phase_b prog sb sb_cfg validate varying; do
    object="build-macos/sched_$source.o"
    clang++ -arch arm64 -O2 -std=c++17 -c "src/sm86/sched/$source.cpp" -o "$object"
    objects="$objects $object"
done
# macOS links its system runtime dynamically; upstream's -static is unsupported.
clang++ -arch arm64 -O3 $objects -o out/uberspec
cp out/uberspec "$script_dir/osx-arm64/uberspec"
chmod +x "$script_dir/osx-arm64/uberspec"
"$script_dir/osx-arm64/uberspec" codegen
