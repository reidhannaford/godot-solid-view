# Changelog

## Unreleased

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
