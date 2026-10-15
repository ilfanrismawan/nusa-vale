# Balai Nadi v3 — native tiles and walkable gardens

Gameplay scene: `res://scenes/world/balai_nadi/exterior.tscn`.
F6 visual preview: `res://scenes/world/balai_nadi/courtyard_preview.tscn`.
The scene contains native editable TileMapLayers, Sprite2Ds, reusable prop scenes,
collision bodies, animated waterfall frames, and exploration Marker2Ds. The playable
root does not generate the map or draw it in code.

## Tile corrections

- `Terrain/TepianBerumput` uses the original Farm RPG grass/water atlas and palette.
  Its plain fill is **(9,2)**. (9,1) and (5,1) are corner-pattern tiles and caused the
  old repeating water/cliff specks throughout otherwise solid ground.
- Inward corners use (5,1), (6,1), (6,2), and (5,2), selected from the eight land
  neighbors. The old large water-hole pieces were not suitable for these corners.
- `JalanSetapak` uses the matching dirt contours in the original grass atlas eight
  rows below the grass set, including a plain (9,10) dirt fill.
- `PapanJati` samples only the clean plank region of the original Bridge Wood
  sprite: 16-pixel cells, atlas margin (0,8), tile (1,1). The old region included a
  fence and repeatedly painted that fence through the floor.
- Platform and bridge coverage is combined before edge selection. Rail lines appear
  only at exposed edges, without separating connected bridge/platform sections.
- Existing trees and shrubs retain their original pixel dimensions and colors.
Trees are kept away from paths and viewing terraces.

## Exploration

World bounds are `Rect2(-320,-128,1504,1024)` on the original 16-pixel map grid.
The main spawn and interior return anchors remain around (427,277)/(427,261).
The village exit is now at (427,840), at the end of a separate southern spur, so
walking around the lake does not automatically send the player out of the map.

The west garden, west guardian dock, southern gardens, east waterside, waterfall
viewing terrace, and northern bridge are connected. Two garden bales provide
additional resting landmarks. `JalurEksplorasi` exposes 16 destination markers for
scene editing and reachability validation. Camera limits include the entire map.
Camera offset is zero: a negative offset could move the rendered view past the
top limit and expose a black strip when visiting the waterfall.

## Art

`bale_agung.png` and `sacred_props.png` were created with built-in image_gen using
the user's original Farm RPG houses, lamp, and statue sheets as style references.
The new direction uses coarse pixel clusters, simple outlines, flat shading, and
slate/sienna/cream colors instead of v2's intricate illustrated gold ornamentation.
The full original transparent source images are retained. AtlasTextures select
individual objects without altering their source pixels.

Exact final prompts: [generation_prompts.json](generation_prompts.json).
Reusable gameplay props: `res://scenes/world/balai_nadi/props/`.
Optional matching icon AtlasTextures: `res://resources/balai_nadi/v3/`.

Ground, water, native-scale vegetation, flowers, road lamps, planks, stone paving,
and all eight waterfall frames come from the existing Farm RPG pack. Gameplay no
longer references the v2 building, prop, or generated floor assets. v2 is preserved
as the earlier art iteration.

## Validation and authoring

`tools/bake_balai_courtyard.gd` is a one-shot headless authoring tool. It saves the
editor scene and prop scenes; re-running it replaces manual changes to those files.
Normal design edits can be made directly in Godot after baking.

`tests/balai_courtyard_regression.tscn` checks grass fill pixels, inward corners,
native vegetation scale, bridge passage, lake blocking, both entrance approach
distances, extended camera bounds, restoration visuals, alpha imports, and preview
state isolation. It builds an AStarGrid using actual player-shape physics queries
and verifies every exploration destination is reachable from the Balai.

Use the repository's isolated `nusa-save-audit-*` APPDATA and `NUSA_SAVE_AUDIT=1` for
tests. `--capture-courtyard` after `--` captures the full map, playable camera view,
west garden, and waterfall view in `scratch/` with the native Godot renderer.
