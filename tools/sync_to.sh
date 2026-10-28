#!/usr/bin/env bash
# Copy the addon into another Godot project, replacing any older copy.
# Usage: tools/sync_to.sh /path/to/other/project
set -euo pipefail

target="${1:?usage: tools/sync_to.sh /path/to/godot/project}"
if [[ ! -f "$target/project.godot" ]]; then
	echo "No project.godot in $target" >&2
	exit 1
fi

here="$(cd "$(dirname "$0")/.." && pwd)"
if [ -d "$target/addons/solid_view" ]; then
	rm -rf "$target/addons/solid_view"
	echo "Removed the old addons/solid_view from $target; enable Workbench under Project Settings > Plugins"
fi
mkdir -p "$target/addons/workbench"
rsync -a --delete "$here/addons/workbench/" "$target/addons/workbench/"
echo "Synced addons/workbench into $target"
