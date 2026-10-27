# Working on Solid View

## Layout

- `addons/solid_view/`: the addon, the only folder another project needs. `plugin.gd` builds the toolbar and shortcut; `solid_view_controller.gd` puts the mode on the four editor viewports and takes it off; `solid_view_effect.gd` is the `CompositorEffect` that drives `solid_view.glsl`; `solid_view_settings.gd` reads and writes the Editor Settings; `matcaps/` holds the bundled matcap.
- `test/`: a scene with heavy fog, glow and coloured lights to prove the mode on, and the headless test.
- `tools/`: `run_tests.sh`, `sync_to.sh <project>`, `capture.gd` (windowed screenshots of every mode into `docs/captures/`, gitignored) and `make_matcap.gd` (bakes `matcaps/clay.png`).
- `docs/`: this file and the README images.

## Conventions

- All GDScript is statically typed: every variable, constant, parameter, return value (including `-> void`) and loop variable has a type, explicit or inferred with `:=` where the right-hand side makes it obvious. Typed collections; narrow with `as`.
- Everything in `addons/solid_view/` is editor code: `@tool` on every script, nothing that runs in exported games.
- The addon depends only on Godot. It never touches the edited scene: only the editor cameras and viewports, and it restores what it changed.

## Running the checks

Godot 4.7.2 is assumed at `/Applications/Godot 4.7.2.app/Contents/MacOS/Godot`; set `GODOT` to use another binary.

```bash
tools/run_tests.sh
```

runs `test/plugin_test.gd` with `--headless --editor` under a throwaway `HOME`: the plugin loads, the toggle is in the toolbar, and the controller takes over and restores the viewports. Expect `FAILURES 0`. Headless Godot has no RenderingDevice, so the effect itself is inert there; the shader is only exercised windowed.

For the look, run the capture with a scratch `HOME` and a fixed window size:

```bash
HOME=/tmp/solid_view_home "/Applications/Godot 4.7.2.app/Contents/MacOS/Godot" --editor --resolution 1600x900 --path . -s res://tools/capture.gd
```

It opens `test/test_scene.tscn`, saves `docs/captures/before.png`, then one screenshot per mode, then `after.png` with the mode off again.

After changing `solid_view.glsl`, a windowed run is also the compile check: a bad shader prints `Solid View: the compute shader failed to compile` with the GLSL error.

## Gotchas

- The `.glsl` is loaded, not preloaded: on a project's first scan it isn't imported yet when the scripts compile.
- The normal and roughness prepass only runs when the camera has a valid environment, which is one reason the controller always sets one.
- A post-opaque write only survives without MSAA; with MSAA the colour buffer is resolved after the transparent pass, overwriting it. The controller turns MSAA off per viewport while active, and the editor re-applies project settings to its viewports on a settings change, which is why `apply()` runs every frame while active.
- A `RefCounted` can't be named `_get`, `_set` or any other Object virtual; the settings helper is `_read`.
- Preload constants need addon-specific names (`SolidViewSettings`, not `Settings`): a game project with a global `class_name` of the same name makes the plugin fail to parse there, even though it parses fine here.

## Releasing

1. Bump `version` in `addons/solid_view/plugin.cfg` and add the entry to `CHANGELOG.md`.
2. Run `tools/run_tests.sh` and the capture.
3. `git archive HEAD | tar -t` should list only the addon, `README.md`, `LICENSE` and `CHANGELOG.md`.
4. Commit, tag `vX.Y.Z` and push the tag.
