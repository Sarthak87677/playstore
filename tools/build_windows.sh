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
"$GODOT" --headless --path "$ROOT/project" -- \
    --autotest --chapters=1,2,3,4,5,6,7,8 | tail -3

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
