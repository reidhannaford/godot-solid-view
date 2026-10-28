#!/usr/bin/env bash
# Takes the README screenshots: runs tools/capture.gd in a windowed editor
# under a throwaway HOME. The view comes from the test scene's Camera3D. Set GODOT to use a different Godot binary.
set -euo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
godot="${GODOT:-/Applications/Godot 4.7.2.app/Contents/MacOS/Godot}"
home="$(mktemp -d)"
trap 'rm -rf "$home"' EXIT

HOME="$home" "$godot" --headless --import --path "$here" >/dev/null 2>&1
HOME="$home" "$godot" --editor --resolution 1600x900 --path "$here" -s res://tools/capture.gd 2>&1 \
	| grep -E "^shot|^view|^DONE|^FAIL|WATCHDOG|Workbench|SCRIPT ERROR" || true
