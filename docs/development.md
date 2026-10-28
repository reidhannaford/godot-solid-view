# Working on Workbench

## Layout

- `addons/workbench/`: the addon, the only folder another project needs. `plugin.gd` builds the toolbar and shortcut; `workbench_controller.gd` puts the mode on the four editor viewports and takes it off, and runs the hidden overdraw viewports for x-ray; `workbench_effect.gd` is the `CompositorEffect` that drives `workbench.glsl`; `workbench_settings.gd` reads and writes the Editor Settings; `matcaps/` holds the bundled matcap.
- `test/`: a scene with heavy fog, glow and coloured lights to prove the mode on, and the headless test.
- `tools/`: `run_tests.sh`, `sync_to.sh <project>`, `capture.sh` with `capture.gd` (windowed screenshots of every mode into `docs/captures/`, gitignored) and `make_matcap.gd` (bakes every image in `matcaps/`).
- `docs/`: this file and the README images.

## Conventions

- All GDScript is statically typed: every variable, constant, parameter, return value (including `-> void`) and loop variable has a type, explicit or inferred with `:=` where the right-hand side makes it obvious. Typed collections; narrow with `as`.
- Everything in `addons/workbench/` is editor code: `@tool` on every script, nothing that runs in exported games.
- The addon depends only on Godot. It never touches the edited scene: only the editor cameras and viewports, and it restores what it changed.

## Running the checks

Godot 4.7.2 is assumed at `/Applications/Godot 4.7.2.app/Contents/MacOS/Godot`; set `GODOT` to use another binary.

```bash
tools/run_tests.sh
```

runs `test/plugin_test.gd` with `--headless --editor` under a throwaway `HOME`: the plugin loads, the toggle is in the toolbar, and the controller takes over and restores the viewports. Expect `FAILURES 0`. Headless Godot has no RenderingDevice, so the effect itself is inert there; the shader is only exercised windowed.

For the look:

```bash
tools/capture.sh
```

It runs `tools/capture.gd` in a windowed editor under a scratch `HOME` at 1600x900. The script reads the Camera3D in `test/test_scene.tscn` and writes the scene's edit-state file (`.godot/editor/test_scene.tscn-editstate-<md5>.cfg`, which the editor reads when it opens the scene) so the editor looks through that camera, with camera and light gizmos hidden; the scene is then opened in distraction-free mode so the viewport fills the window. It saves `docs/captures/before.png`, `studio.png`, `studio_texture.png`, `matcap_normal.png`, `matcap_contrast.png` and `studio_xray.png` with cavity, outline and crease lines on, `studio_ortho.png` in the orthographic view, and `after.png` with the mode off again; each also as `<name>_view.png`, the viewport alone trimmed to a centred 16:9, the framing of the camera's own preview. The README images in `docs/images/` are taken by hand from the editor, as WebP, framed through the scene's camera; the capture's `_view` crops are a check, not the README set.

After changing `workbench.glsl`, a windowed run is also the compile check: a bad shader prints `Workbench: the compute shader failed to compile` with the GLSL error.

## Gotchas

- The `.glsl` is loaded, not preloaded: on a project's first scan it isn't imported yet when the scripts compile.
- The normal and roughness prepass only runs when the camera has a valid environment, which is one reason the controller always sets one.
- A post-opaque write only survives without MSAA; with MSAA the colour buffer is resolved after the transparent pass, overwriting it. The controller turns MSAA off per viewport while active, and the editor re-applies project settings to its viewports on a settings change, which is why MSAA is re-asserted before every draw.
- The editor saves its View Environment toggle in the per-scene edit state as `use_environment = camera->get_environment().is_valid()`, and on load toggles the menu item whenever that differs from the camera. An environment left on the camera between frames is therefore saved as the user's choice, and the scene reopens with View Environment off and a grey background. So the controller only puts its environment, compositor and debug draw on the cameras between `RenderingServer.frame_pre_draw` and `frame_post_draw`; the editor renders single-threaded, so both fire synchronously around the draw and no editor code runs in between.
- A `RefCounted` can't be named `_get`, `_set` or any other Object virtual; the settings helper is `_read`.
- Preload constants need addon-specific names (`WorkbenchSettings`, not `Settings`): a game project with a global `class_name` of the same name makes the plugin fail to parse there, even though it parses fine here.
- X-ray rests on three editor facts, all checked in the 4.7.2 source: the Overdraw debug draw replaces every material with `blend_add, unshaded`, ALBEDO (0.4, 0.8, 0.8) and ALPHA 0.1 on a black clear, so each surface adds 0.08 of green and the layer count is `g / 0.08`; the editor cameras cull the game's 20 layers plus their own gizmo, grid and tool layers at bits 24 to 30, which the x-ray camera masks out; and the RenderingServer draws child viewports before their parents, so a SubViewport added under the editor's viewport is current in the same frame. The hidden viewport renders in HDR (`use_hdr_2d`) so its texture is linear and read as stored.
- The overdraw material override only exists in builds with `DEBUG_ENABLED`, which every editor build is.
- Lines are drawn in pixels of the internal render buffer. The setting is in points: the plugin multiplies it by `EditorInterface.get_editor_scale()` (2 on a 2x display) and the effect by internal size over target size, so a 3D render scale below 1 doesn't thin them. The silhouette and crease tests look up to `outline_width` pixels along +x and +y (and -x, -y for the silhouette) so the line lands on one side of an edge at that width.
- `RenderSceneData.get_cam_projection()` is the reversed-Z render projection, and `Projection.get_z_near()` / `get_z_far()` return -0.05 and 0.05 for it. The effect passes the matrix's `z.z` and `w.z` entries and the shader inverts the depth row itself: perspective `depth = w.z / d - z.z`, orthographic `depth = w.z - z.z * d`. The capture's `studio_ortho.png` checks the orthographic branch; it switches the view through the viewport's own view menu, since an `orthogonal` flag in the edit-state file is not honoured.

## Releasing

1. Bump `version` in `addons/workbench/plugin.cfg` and add the entry to `CHANGELOG.md`.
2. Run `tools/run_tests.sh` and the capture.
3. `git archive HEAD | tar -t` should list only the addon, `README.md`, `LICENSE` and `CHANGELOG.md`.
4. Commit, tag `vX.Y.Z` and push the tag.
5. `git archive --format=zip --prefix=workbench-X.Y.Z/ vX.Y.Z -o workbench-X.Y.Z.zip` makes the Asset Store upload: the addon folder with the licence and README copies, plus the root README, LICENSE and CHANGELOG. Attach it to the GitHub release and upload it on the store's Versions tab.
6. `tools/make_thumbnail.sh` rebuilds `docs/store/thumbnail.png` (16:9, the store's listing image) from the README images, if they changed.
