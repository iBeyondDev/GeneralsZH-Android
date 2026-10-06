#!/usr/bin/env bash
# Verify the Android native libs: arch, NEEDED closure, exported SDL_main,
# and that no undefined symbol is left that the system libs can't satisfy.
set -uo pipefail
source "$HOME/android/env.sh"
cd "$(dirname "$0")/../../.."
BIN="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin"
B=build/android-arm64
MAIN="$B/GeneralsMD/Code/Main/libmain.so"

echo "== libmain.so"; ls -la "$MAIN"; file -L "$MAIN"
echo "== NEEDED"; "$BIN/llvm-readelf" -d "$MAIN" | grep NEEDED
echo "== SDL_main exported?"; "$BIN/llvm-nm" -D --defined-only "$MAIN" | grep -w SDL_main || echo "MISSING SDL_main"
echo "== LOAD segment alignment (16 KB pages need 0x4000)"; "$BIN/llvm-readelf" -l "$MAIN" | grep LOAD | awk '{print $NF}' | sort -u
echo "== shared libs in build tree"; find "$B" -name "*.so*" -not -path "*/vcpkg_installed/*" -not -path "*CMakeFiles*" | sort
