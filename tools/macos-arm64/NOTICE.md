# macOS arm64 native libraries

`cimgui.dylib` was built from [cimgui 1.82dock](https://github.com/cimgui/cimgui/tree/ccdae842e40f35ebf40167918175deb9af8c2a16), including its Dear ImGui submodule at `256594575d95d56dda616c544c509740e74906b4`. Its exported symbols were compared with the existing x86_64 `cimgui.dylib`. Both projects use the MIT license; see `LICENSE.cimgui` and `LICENSE.imgui`.

`tinyfiledialogs.dylib` was built from the [official tinyfiledialogs source](https://sourceforge.net/p/tinyfiledialogs/code/ci/58f4a241a9afb2996e2beefc938fc8d5002da601/tree/) at commit `58f4a241a9afb2996e2beefc938fc8d5002da601`. It uses the zlib license; see `LICENSE.tinyfiledialogs`.

Both libraries were compiled on Apple Silicon with the system Clang. The cimgui build used `make CXX=clang++`; tinyfiledialogs used `clang -dynamiclib -O2 -o tinyfiledialogs.dylib tinyfiledialogs.c`.

The `osx-arm64` publish also needs SDL2-compat and SDL3. The project copies their arm64 libraries from Homebrew by default. These are build inputs and are not stored here. Their zlib license texts are included as `LICENSE.SDL2-compat` and `LICENSE.SDL3` and copied into the publish output.
