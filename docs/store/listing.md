# Asset Store listing

What to paste into each field of the Godot Asset Store (store.godotengine.org) when uploading or updating Workbench. The store's own rules are at https://store.godotengine.org/guidelines/ and the flow at https://docs.godotengine.org/en/latest/community/asset_store/submitting_to_asset_store.html.

## Upload Asset

- **Publisher**: Reid Hannaford
- **Publisher URL slug**: reidhannaford
- **Asset name**: Workbench
- **Asset URL**: workbench

## Settings

**Summary** (one line):

> Blender's Workbench shading for the 3D editor viewport: studio lighting or matcaps, flat or texture colour, cavity, outlines and x-ray, with the scene's lights, fog and post-processing out of the way.

**Description**:

> Workbench gives Godot's 3D editor viewport the shading of Blender's Solid mode, the one its Workbench engine draws. A Workbench toggle in the viewport toolbar (Alt+Z) lights every surface with a fixed studio light or a matcap, with the scene's own lights, fog, glow, ambient light and tonemapping out of the way. It is for laying out levels in a scene whose real lighting is dark, foggy or otherwise hard to see through.
>
> What it does:
>
> - Studio lighting: a warm key, a cool fill and a faint rim, fixed to the view, so nothing is ever in the dark.
> - MatCaps: seven bundled (clay, normal, contrast, toon, zebra, wax and chrome), or any image in the project, including the matcaps that ship with Blender.
> - Flat or texture colour: a plain grey, or each surface's own albedo.
> - Cavity: ridges brighten and valleys darken, like Blender's screen-space cavity.
> - Outline and crease lines: a dark line where depth jumps, and optionally along sharp creases, at a width in points that looks the same on any display.
> - X-ray (Alt+Shift+Z): see through the front surfaces to the geometry behind them.
>
> The editor's grid, gizmos, selection outline and transparent objects still draw on top. Nothing in the scene is touched: the addon only drives the editor cameras and viewports while a frame is being drawn, and puts everything back when it is off. Options live in the menu beside the toggle and under Editor Settings > Workbench, so they follow you between projects.
>
> Requirements: Godot 4.7 or later with the Forward+ renderer. Mobile and Compatibility have no normal buffer for the effect to read.
>
> Source, screenshots and changelog: https://github.com/reidhannaford/godot-workbench

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
