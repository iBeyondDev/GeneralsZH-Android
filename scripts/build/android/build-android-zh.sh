#!/usr/bin/env bash
# Configure + build Zero Hour for Android arm64 (produces build/android-arm64/.../libmain.so
# plus DXVK/SDL3 shared libs). Usage: build-android-zh.sh [--configure-only] [--fresh]
set -euo pipefail
source "$HOME/android/env.sh"
cd "$(dirname "$0")/../../.."

CONFIGURE_ONLY=0
FRESH=""
for arg in "$@"; do
  case "$arg" in
    --configure-only) CONFIGURE_ONLY=1 ;;
    --fresh) FRESH="--fresh" ;;
  esac
done

cmake --preset android-arm64 $FRESH
[ "$CONFIGURE_ONLY" = 1 ] && { echo "CONFIGURE_OK"; exit 0; }

# -k 0: keep going past failures so one run reports every broken translation unit
cmake --build build/android-arm64 --target z_generals dxvk_d3d8_install -- -k 0
echo "BUILD_OK"
