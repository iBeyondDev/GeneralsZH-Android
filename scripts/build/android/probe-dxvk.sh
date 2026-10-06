#!/usr/bin/env bash
# Probe: cross-compile SDL3 + DXVK (d3d8/d3d9, SDL3 WSI) for Android arm64-v8a
# standalone, then verify the artifacts (arch, WSI driver, Vulkan loader name).
set -euo pipefail
source "$HOME/android/env.sh"

ENGINE_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
WORK="$HOME/generals-android/dxvk-probe"
API=29
LLVM_BIN="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin"
SDL3_VERSION=3.4.2
mkdir -p "$WORK"
cd "$WORK"

# --- SDL3 for Android (shared) ---
if [ ! -f sdl3-install/lib/libSDL3.so ]; then
  [ -f SDL3-$SDL3_VERSION.tar.gz ] || curl -sLO "https://github.com/libsdl-org/SDL/releases/download/release-$SDL3_VERSION/SDL3-$SDL3_VERSION.tar.gz"
  rm -rf SDL3-$SDL3_VERSION && tar xzf SDL3-$SDL3_VERSION.tar.gz
  cmake -S SDL3-$SDL3_VERSION -B sdl3-build -G Ninja \
    -DCMAKE_TOOLCHAIN_FILE="$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake" \
    -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=android-$API \
    -DCMAKE_BUILD_TYPE=Release -DSDL_SHARED=ON -DSDL_STATIC=OFF -DSDL_TEST_LIBRARY=OFF \
    -DCMAKE_INSTALL_PREFIX="$WORK/sdl3-install"
  cmake --build sdl3-build
  cmake --install sdl3-build
fi

# --- pkg-config file meson resolves dependency('SDL3') with ---
# Named SDL3.pc: pkg-config lookup is case-sensitive on Linux hosts (the
# lowercase sdl3.pc only ever worked on case-insensitive macOS filesystems).
mkdir -p pc
rm -f pc/sdl3.pc
cat > pc/SDL3.pc <<EOF
prefix=$WORK/sdl3-install
libdir=\${prefix}/lib
includedir=\${prefix}/include
Name: sdl3
Description: SDL3 (Android arm64 probe)
Version: $SDL3_VERSION
Libs: -L\${libdir} -lSDL3
Cflags: -I\${includedir}
EOF

# --- meson cross file from the in-tree template ---
sed -e "s|@ANDROID_LLVM_BIN@|$LLVM_BIN|g" -e "s|@ANDROID_API@|$API|g" \
  "$ENGINE_DIR/cmake/meson-aarch64-android-cross.ini.in" > android-cross.ini

# --- DXVK ---
rm -rf dxvk-build
PKG_CONFIG_LIBDIR="$WORK/pc" PKG_CONFIG_PATH="" \
  meson setup dxvk-build "$ENGINE_DIR/references/fbraz3-dxvk" \
    --cross-file android-cross.ini -Ddxvk_native_wsi=sdl3 --buildtype=release \
    -Denable_dxgi=false -Denable_d3d10=false -Denable_d3d11=false
ninja -C dxvk-build src/d3d9/libdxvk_d3d9.so src/d3d8/libdxvk_d3d8.so

# --- verify artifacts, never trust the exit code alone ---
for lib in dxvk-build/src/d3d9/libdxvk_d3d9.so dxvk-build/src/d3d8/libdxvk_d3d8.so; do
  echo "== $lib"
  file -L "$lib"
  "$LLVM_BIN/llvm-readelf" -d "$lib" | grep -E "NEEDED|SONAME" || true
done
echo "WSI drivers compiled in:"; strings dxvk-build/src/d3d9/libdxvk_d3d9.so | grep -oE "Sdl[23]WsiDriver|GlfwWsiDriver" | sort -u
echo "Vulkan loader names:"; strings dxvk-build/src/d3d9/libdxvk_d3d9.so | grep -E "^libvulkan" | sort -u
echo "PROBE_OK"
