#!/usr/bin/env bash
# Runs the headless test with a throwaway HOME so the real editor settings
# are left alone. Set GODOT to use a different Godot binary.
set -uo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
godot="${GODOT:-/Applications/Godot 4.7.2.app/Contents/MacOS/Godot}"
home="$(mktemp -d)"
trap 'rm -rf "$home"' EXIT

HOME="$home" "$godot" --headless --import --path "$here" >/dev/null 2>&1
echo "== plugin_test.gd"
HOME="$home" "$godot" --headless --editor --path "$here" -s res://test/plugin_test.gd 2>&1 \
	| grep -E '^(PASS|FAIL|FAILURES|WATCHDOG)|SCRIPT ERROR|ERROR'
exit "${PIPESTATUS[0]}"
