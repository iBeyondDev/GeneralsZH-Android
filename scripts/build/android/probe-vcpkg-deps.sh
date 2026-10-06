#!/usr/bin/env bash
# Probe: build every vcpkg dependency for arm64-android standalone (manifest mode,
# same baseline/overrides as the real build) before integrating with the engine.
set -euo pipefail
source "$HOME/android/env.sh"

ENGINE_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
PROBE_DIR="$HOME/generals-android/vcpkg-probe"
mkdir -p "$PROBE_DIR"
cp "$ENGINE_DIR/vcpkg.json" "$PROBE_DIR/vcpkg.json"
cd "$PROBE_DIR"

vcpkg install --triplet=arm64-android --x-install-root="$PROBE_DIR/installed"
echo "PROBE_OK"
ls "$PROBE_DIR/installed/arm64-android/lib"
