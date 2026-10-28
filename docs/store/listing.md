# Asset Store listing

What to paste into each field of the Godot Asset Store (store.godotengine.org) when uploading or updating Workbench. The store's own rules are at https://store.godotengine.org/guidelines/ and the flow at https://docs.godotengine.org/en/latest/community/asset_store/submitting_to_asset_store.html.

## Upload Asset

- **Publisher**: Reid Hannaford
- **Publisher URL slug**: reidhannaford
- **Asset name**: Workbench
- **Asset URL**: workbench

## Settings

**Summary** (up to 500 characters, 422 used):

> Blender's Workbench shading for the 3D editor viewport. A toolbar toggle lights every surface with a fixed studio light or a matcap, in flat or texture colour, with cavity, outlines, crease lines and x-ray, and keeps the scene's own lights, fog, glow and tonemapping out of the way. For laying out levels in scenes whose real lighting is dark, foggy or otherwise hard to see through. Godot 4.7 or later, Forward+ renderer.

**Description** (Markdown, up to 20000 characters, 4827 used):

> Workbench gives Godot's 3D editor viewport the shading of Blender's **Solid** mode, the one its Workbench engine draws. A **Workbench** toggle in the viewport toolbar (Alt+Z) lights every surface with a fixed studio light or a matcap, with the scene's own lights, fog, glow, ambient light and tonemapping out of the way. It is for laying out levels in a scene whose real lighting is dark, foggy or otherwise hard to see through, and for checking forms and surfaces without the material getting in the way.
>
> ## What it does
>
> - **Studio lighting**: a warm key, a cool fill and a faint rim, fixed to the view, so nothing is ever in the dark.
> - **MatCaps**: a sphere image sampled by view-space normal. Seven are bundled: clay, normal (each surface coloured by the direction it faces), contrast (two tones with a rim), toon (three cel bands), zebra (a reflection check), wax and chrome. **Choose MatCap…** takes any image in the project, including the matcaps that ship with Blender.
> - **Flat or texture colour**: a plain grey, or each surface's own albedo under the studio light or matcap.
> - **Cavity**: screen-space ridges brighten and valleys darken, like Blender's screen cavity.
> - **Outline**: a dark line where a surface drops away to something farther, or to the sky. The width is set in points, so it looks the same on any display.
> - **Crease lines**: with the outline on, a line along creases sharper than 45 degrees, so a box's corner edges get lines as well as its silhouette.
> - **X-ray** (Alt+Shift+Z): see through the front surfaces to the geometry behind them. Alt+click in the viewport lists everything under the cursor, so hidden objects can be picked.
>
> The editor's grid, gizmos, selection outline and any transparent objects still draw on top, as they would normally.
>
> ## Nothing in the scene is touched
>
> The addon only drives the editor cameras and viewports, and only while a frame is being drawn: the camera gets a neutral environment and a compositor for the duration of the draw and has its own values back before the editor runs again. Nothing is saved into your scenes, the View Environment toggle keeps its setting, and switching Workbench off, or disabling the plugin, leaves the editor exactly as it was.
>
> ## Options
>
> The menu beside the toggle holds Studio Lighting or MatCap, Flat or Texture Colour, Cavity, Outline, Crease Lines, X-Ray, the bundled matcaps and **Choose MatCap…**. Several options can be changed with the menu open. Editor Settings > Workbench holds the outline width and the x-ray opacity, and changes there apply at once. All options are Editor Settings, so they follow you between projects; the toggle itself starts off every session.
>
> The shortcuts are `workbench/toggle` (Alt+Z) and `workbench/toggle_xray` (Alt+Shift+Z) in Editor Settings > Shortcuts.
>
> ## How it works
>
> A `CompositorEffect` on each editor camera runs a compute shader after the opaque pass and before the sky: for every pixel with geometry, it reads the view-space normal from the normal and roughness buffer and writes studio or matcap shading over the colour buffer. Because that happens before the transparent pass, gizmos and see-through objects land on top. X-ray comes from a hidden viewport per editor viewport that renders the same world in the editor's Overdraw debug draw, which gives the number of surfaces under each pixel; the shader blends the front shading over that many ghosted layers.
>
> ## Requirements
>
> - Godot 4.7 or later.
> - The Forward+ renderer. Mobile and Compatibility have no normal buffer for a compositor effect to read.
>
> ## Install
>
> 1. Copy `addons/workbench/` into your project's `addons/` folder.
> 2. Open **Project → Project Settings → Plugins** and enable **Workbench**.
> 3. The **Workbench** toggle and its options menu appear at the right of the 3D viewport's toolbar.
>
> ## Limitations
>
> - Forward+ only.
> - Objects whose material skips the depth prepass (transparent, `depth_draw_never`) keep their own look.
> - The outline is depth-based, not object-based: two touching objects at the same depth have no line between them; crease lines cover the edge between them when their normals differ.
> - X-ray knows how many surfaces are behind a pixel, not what they look like, so hidden geometry is a flat ghost with silhouette lines rather than shaded as Blender draws it. It costs a second, unshaded render of the scene per editor viewport while it is on.
> - The View menu's **View Environment** toggle has no visible effect while Workbench is on; its setting is kept and comes back when Workbench is off.
>
> ## Source and support
>
> Source, screenshots and changelog: https://github.com/reidhannaford/godot-workbench. Issues and pull requests are welcome; please say which Godot version and platform you're on.
>
> MIT licence. Claude Code was used to assist in the research and writing of code.

- **Asset type**: Addon
- **Licence**: MIT (matches `LICENSE` in the repository and the copy inside `addons/workbench/`)
- **Source code**: https://github.com/reidhannaford/godot-workbench
- **Tags** (not the asset's name; one form of each word): editor, viewport, shading, matcap, lighting, level-design, blockout, blender, 3d
- **AI usage disclosure**: the store calls this mandatory when AI was used. The code and documentation were written with Claude, Anthropic's AI assistant, directed and reviewed by the author. Say so in whatever form the field takes.

## Media

- **Thumbnail** (16:9, required): `docs/store/thumbnail.png`, 1280x720. The scene as lit on the left, in Workbench on the right. Rebuild with `tools/make_thumbnail.sh` after the README images change.
- **Screenshots**: `docs/store/screenshots/`, PNG copies of the README images, in this order with these captions:
  1. `01_before.png`: The test scene under its own lights and fog.
  2. `02_workbench.png`: The same view in Workbench: studio light, cavity, outline and crease lines.
  3. `03_texture.png`: Texture colour: each surface's own albedo under the studio light.
  4. `04_xray.png`: X-ray: the geometry behind the wall and inside the crate shows through.
  5. `05_matcap_normal.png`: The normal matcap, colouring each surface by the direction it faces.
  6. `06_matcap_contrast.png`: The contrast matcap, two tones with a rim.

## Versions

- **Version name**: 1.3.0
- **Minimum Godot version**: 4.7
- **File**: `workbench-1.3.0.zip` from the GitHub release (made with `git archive`, step 5 of Releasing in `docs/development.md`). It holds `addons/workbench/` with its licence and README copies, plus the root README, LICENSE and CHANGELOG.
- **Changelog**: the 1.3.0 section of `CHANGELOG.md`.

## Pricing

Free. Reviews on. A donation link is optional.

## Before pressing Submit

- The listed Godot version matches what the addon was tested on (4.7.2).
- The thumbnail and screenshots show only what the addon does.
- The licence on the listing is MIT, the same as in the ZIP.
