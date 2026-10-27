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
mkdir -p "$target/addons/solid_view"
rsync -a --delete "$here/addons/solid_view/" "$target/addons/solid_view/"
echo "Synced addons/solid_view into $target"
