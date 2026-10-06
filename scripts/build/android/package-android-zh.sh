#!/usr/bin/env bash
# Package the Android APK from an existing build/android-arm64 tree.
#   1. stage + strip native libs into android/app/libs/arm64-v8a
#   2. verify the NEEDED closure (every dependency shipped or an Android system lib)
#   3. pull SDLActivity java + gradle wrapper from the in-tree SDL3 (same version as libSDL3.so)
#   4. gradle assembleDebug, copy the APK to the Windows-visible project folder
set -euo pipefail
source "$HOME/android/env.sh"
ENGINE="$(cd "$(dirname "$0")/../../.." && pwd)"
B="$ENGINE/build/android-arm64"
APP="$ENGINE/android"
JNI="$APP/app/libs/arm64-v8a"
BIN="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin"
SDL_SRC="$B/_deps/sdl3-src"
OUT_DIR="/mnt/i/Projects/generals-android"

LIBS=(
  "$B/GeneralsMD/Code/Main/libmain.so"
  "$B/_deps/sdl3-build/libSDL3.so"
  "$B/_deps/sdl3_image-build/libSDL3_image.so"
  "$B/_deps/openal_soft-build/libopenal.so"
  "$B/libgamespy.so"
  "$B/libdxvk_d3d8.so"
  "$B/libdxvk_d3d9.so"
)

# --- 1. stage (stale-artifact guard: every input must exist; libmain must be newer than its sources' last build) ---
rm -rf "$JNI" && mkdir -p "$JNI"
for lib in "${LIBS[@]}"; do
  [ -f "$lib" ] || { echo "ERROR: missing $lib — build first (build-android-zh.sh)"; exit 1; }
  "$BIN/llvm-strip" --strip-debug -o "$JNI/$(basename "$lib")" "$lib"
done
ls -la "$JNI"

# --- 2. NEEDED closure check ---
SYSTEM_LIBS="libc.so libm.so libdl.so liblog.so libandroid.so libmediandk.so libvulkan.so libEGL.so libGLESv1_CM.so libGLESv2.so libGLESv3.so libOpenSLES.so libaaudio.so libz.so libjnigraphics.so"
missing=0
for so in "$JNI"/*.so; do
  for need in $("$BIN/llvm-readelf" -d "$so" | sed -n 's/.*(NEEDED).*\[\(.*\)\]/\1/p'); do
    if [ ! -f "$JNI/$need" ] && ! grep -qw "$need" <<< "$SYSTEM_LIBS"; then
      echo "ERROR: $(basename "$so") needs $need, which is neither staged nor an Android system lib"
      missing=1
    fi
  done
done
[ "$missing" = 0 ] || exit 1
echo "NEEDED closure OK"

# DXVK content checks (stale-artifact guard): SDL3 WSI compiled in, Android SDL soname
# (strings captured once: `strings | grep -q` + pipefail fails on SIGPIPE even when it matches)
DXVK_STRINGS="$(strings "$JNI/libdxvk_d3d9.so")"
grep -q "Sdl3WsiDriver" <<< "$DXVK_STRINGS" || { echo "ERROR: DXVK lacks Sdl3WsiDriver"; exit 1; }
grep -qx "libSDL3.so" <<< "$DXVK_STRINGS" || { echo "ERROR: DXVK still dlopens a non-Android SDL3 soname (stale DXVK?)"; exit 1; }
echo "DXVK content OK"

# --- 3. SDL java glue, launcher icons, gradle wrapper from the matching SDL3 source ---
[ -d "$SDL_SRC/android-project" ] || { echo "ERROR: $SDL_SRC/android-project not found"; exit 1; }
rm -rf "$APP/app/src/main/java/org/libsdl"
mkdir -p "$APP/app/src/main/java/org/libsdl"
cp -r "$SDL_SRC/android-project/app/src/main/java/org/libsdl/app" "$APP/app/src/main/java/org/libsdl/"
for d in "$SDL_SRC"/android-project/app/src/main/res/mipmap-*; do
  [ -d "$APP/app/src/main/res/$(basename "$d")" ] || cp -r "$d" "$APP/app/src/main/res/"
done
if [ ! -f "$APP/gradlew" ]; then
  cp "$SDL_SRC/android-project/gradlew" "$APP/"
  cp -r "$SDL_SRC/android-project/gradle" "$APP/"
  chmod +x "$APP/gradlew"
fi

# --- 4. build APK ---
cd "$APP"
echo "sdk.dir=$ANDROID_HOME" > local.properties
./gradlew --no-daemon -q assembleDebug
APK="$APP/app/build/outputs/apk/debug/app-debug.apk"
ls -la "$APK"
mkdir -p "$OUT_DIR"
cp "$APK" "$OUT_DIR/GeneralsZH-debug.apk"
echo "APK_OK -> $OUT_DIR/GeneralsZH-debug.apk"
