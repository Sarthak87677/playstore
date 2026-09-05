#!/usr/bin/env bash
# Build the Windows release of VEILFORGE and package the distributable ZIP.
#
# Requires Godot 4.3 stable on PATH (or GODOT set) with the 4.3 Windows export
# templates installed. Run from anywhere; paths are resolved from this script.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-godot}"
OUT_DIR="$ROOT/release/VEILFORGE"
ZIP_PATH="$ROOT/release/VEILFORGE-Windows-x86_64.zip"

if ! command -v "$GODOT" >/dev/null 2>&1; then
  echo "error: '$GODOT' not found. Install Godot 4.3 or set GODOT=/path/to/godot" >&2
  exit 1
fi

echo "==> Godot: $("$GODOT" --version)"

echo "==> Importing project"
"$GODOT" --headless --path "$ROOT/project" --editor --quit >/dev/null 2>&1 || true

echo "==> Running the automated playtest before packaging"
# Keep the whole transcript: the per-chapter timings and node counts quoted in
# QA_REPORT.md come from here, and tail -3 threw them away.
mkdir -p "$ROOT/build"
"$GODOT" --headless --path "$ROOT/project" -- \
    --autotest --chapters=1,2,3,4,5,6,7,8 | tee "$ROOT/build/autotest.log" | tail -3

# The playtest above runs with the harness present. The shipped build does not
# have it: `tests/*` is excluded. That difference once cost a release -- a type
# annotation naming a class from tests/ made Boot.gd fail to PARSE in the export,
# so the main scene never loaded and the game opened an empty window. Nothing in
# the suite could see it, because the suite ran against a build that still had
# the file. So: export a Linux build with exactly the release filters, start it
# with no flags, and require it to reach the main menu.
echo "==> Smoke-testing the shipped configuration (tests excluded)"
rm -rf "$ROOT/build/shipcheck"
mkdir -p "$ROOT/build/shipcheck"
"$GODOT" --headless --path "$ROOT/project" \
    --export-release "Linux Ship Check" ../build/shipcheck/VEILFORGE_shipcheck.x86_64 >/dev/null 2>&1
SHIPBIN="$ROOT/build/shipcheck/VEILFORGE_shipcheck.x86_64"
if [ ! -f "$SHIPBIN" ]; then
  echo "error: ship-check export produced no binary" >&2
  exit 1
fi
SMOKE_HOME="$ROOT/build/shipcheck/home"
rm -rf "$SMOKE_HOME"; mkdir -p "$SMOKE_HOME"
HOME="$SMOKE_HOME" timeout 120 "$SHIPBIN" --headless > "$ROOT/build/shipcheck/boot.log" 2>&1 || true
SMOKE_LOG="$SMOKE_HOME/.local/share/godot/app_userdata/VEILFORGE - THE THREEFOLD EARTH/veilforge.log"
if grep -q "Main menu ready" "$SMOKE_LOG" 2>/dev/null; then
  echo "    shipped configuration reaches the main menu"
else
  echo "error: the shipped configuration never reached the main menu." >&2
  echo "       This is what a player sees as an empty window. Engine output:" >&2
  grep -E "SCRIPT ERROR|Parse Error|Failed to load|ERROR" "$ROOT/build/shipcheck/boot.log" 2>/dev/null | head -20 >&2
  exit 1
fi

echo "==> Exporting Windows x86-64"
rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"
"$GODOT" --headless --path "$ROOT/project" \
    --export-release "Windows Desktop" "../release/VEILFORGE/VEILFORGE.exe"

if [ ! -f "$OUT_DIR/VEILFORGE.exe" ]; then
  echo "error: export produced no executable" >&2
  exit 1
fi

echo "==> Staging documentation"
cp "$ROOT/README.md" "$ROOT/CONTROLS.md" "$ROOT/THIRD_PARTY_LICENSES.md" \
   "$ROOT/KNOWN_LIMITATIONS.md" "$OUT_DIR/"

echo "==> Packaging $ZIP_PATH"
rm -f "$ZIP_PATH"
( cd "$ROOT/release" && zip -q -r "$(basename "$ZIP_PATH")" VEILFORGE )

echo
echo "Executable : $OUT_DIR/VEILFORGE.exe"
echo "Archive    : $ZIP_PATH"
ls -lh "$OUT_DIR/VEILFORGE.exe" "$ZIP_PATH" | awk '{print "  " $5 "\t" $9}'
