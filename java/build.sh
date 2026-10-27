#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ZB="${ZB_JAR:-$HERE/../../ZombieBuddy/libs/ZombieBuddy.jar}"
OUT="$HERE/../42/media/java/client/WTAGarouVisuals.jar"
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT
mkdir -p "$(dirname "$OUT")"
mapfile -t SOURCES < <(find "$HERE/src" "$HERE/stubs" -name '*.java' | sort)
javac --release 17 -cp "$ZB" -d "$BUILD" "${SOURCES[@]}"
jar --create --file "$OUT" --date=2026-09-21T00:00:00Z -C "$BUILD" wtagarou
echo "Built $OUT"
