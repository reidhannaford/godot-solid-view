# Changelog

## Unreleased

- Fixed: the outline, crease and cavity tests worked from wrong distances. The projection the effect receives is Godot's reversed-Z render matrix, and `Projection.get_z_near()` / `get_z_far()` return nonsense for it (-0.05 and 0.05), which squashed every depth to about the same value. The silhouette only ever fired against the sky or on very close objects, which the small test scene hid. Distances now come from the matrix's own depth entries, in perspective and orthographic views.
- **Crease Lines** option: with Outline on, a line along creases sharper than 45 degrees within a surface, so a box's corner edges get lines, not only its silhouette.
- **Outline width** setting (`solid_view/outline_width`, in points), scaled to the display and to the 3D render scale, so the outline is no longer a single device pixel on a 2x display. X-ray's hidden-silhouette lines follow the same width.
- Edits in Editor Settings > Solid View apply at once instead of at the next editor start.
- **X-ray**: see through the front surfaces to the geometry behind them, as Blender's X-ray does. In the options menu, Alt+Shift+Z by default (`solid_view/toggle_xray`), opacity under `solid_view/xray_alpha` in Editor Settings. Hidden geometry comes from a hidden per-viewport overdraw render, so it shows as a ghost with silhouette lines rather than shaded.
- The editor cameras also get neutral camera attributes during the draw, so a scene's exposure or auto-exposure no longer changes the solid shading.

## 1.0.2, 2026-10-27

- Fixed: a scene saved while Solid was on reopened with the editor's View Environment off and a grey background. The addon now only puts its environment, compositor and debug draw on the editor cameras while a frame is being drawn, so the editor's own view state is what gets saved. Scenes already affected: tick View Environment in the viewport's View menu once and save.

## 1.0.1, 2026-10-27

- The outline now draws on smaller depth steps, so a box top against the floor behind it keeps its edge from a steep view. Flat surfaces are still edge-free.
- README images retaken with cavity and outline on.

## 1.0.0, 2026-10-27

First release.

- A **Solid** toggle in the 3D toolbar, Alt+Z by default.
- Studio lighting or a matcap, flat or texture colour, cavity and outline.
- A bundled clay matcap and a file picker for any other image.
- Options kept in Editor Settings under `solid_view/`; the options menu stays open while ticking them.
