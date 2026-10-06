#!/usr/bin/env bash
# List engine source files using glibc-only (or late-API-level) functionality
# that Android's bionic libc lacks at our minimum API level (29).
cd "$(dirname "$0")/../../.."
for p in "execinfo.h" "pthread_cancel" "backtrace(" "sys/timeb.h" "<iconv.h>" "wordexp" \
         "getcontext" "fontconfig" "sys/io.h" "mallinfo" "shm_open" "sys/sysinfo.h" \
         "/proc/self" "getpwuid" "XDG_" "glob(" "funopen" "__GLIBC__"; do
  files=$(grep -rlF --include=*.cpp --include=*.h --include=*.c "$p" Core Generals GeneralsMD 2>/dev/null)
  n=$(printf '%s\n' "$files" | grep -c . || true)
  echo "## $p : $n files"
  printf '%s\n' "$files" | grep -v '^$' | grep -v '^Generals/' | head -8 | sed 's/^/   /'
done
