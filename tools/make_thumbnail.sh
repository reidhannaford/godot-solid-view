#!/usr/bin/env bash
# Bakes docs/store/thumbnail.png, the Asset Store listing image, from the
# README images, headless under a throwaway HOME. Set GODOT to use a different
# Godot binary.
set -euo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
godot="${GODOT:-/Applications/Godot 4.7.2.app/Contents/MacOS/Godot}"
home="$(mktemp -d)"
trap 'rm -rf "$home"' EXIT

HOME="$home" "$godot" --headless --path "$here" -s res://tools/make_thumbnail.gd 2>&1 \
	| grep -E "^Wrote|^FAIL|SCRIPT ERROR" || true
