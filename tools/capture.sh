#!/usr/bin/env bash
# Takes the README screenshots: pins the editor's view of the test scene by
# writing its edit-state file, then runs tools/capture.gd in a windowed
# editor under a throwaway HOME. Set GODOT to use a different Godot binary.
set -euo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
godot="${GODOT:-/Applications/Godot 4.7.2.app/Contents/MacOS/Godot}"
home="$(mktemp -d)"
trap 'rm -rf "$home"' EXIT

scene="res://test/test_scene.tscn"
md5="$(printf '%s' "$scene" | md5 -q 2>/dev/null || printf '%s' "$scene" | md5sum | cut -d' ' -f1)"
mkdir -p "$here/.godot/editor"
cat > "$here/.godot/editor/test_scene.tscn-editstate-$md5.cfg" <<'STATE'
[editor_states]

3D={
"viewport_mode": 1,
"viewports": [{
"distance": 8.0,
"orthogonal": false,
"position": Vector3(0.2, 0.9, 0.0),
"x_rotation": 0.42,
"y_rotation": -0.45
}, {}, {}, {}]
}
STATE

HOME="$home" "$godot" --headless --import --path "$here" >/dev/null 2>&1
HOME="$home" "$godot" --editor --resolution 1600x900 --path "$here" -s res://tools/capture.gd 2>&1 \
	| grep -E "^shot|^DONE|^FAIL|WATCHDOG|Solid View|SCRIPT ERROR" || true
