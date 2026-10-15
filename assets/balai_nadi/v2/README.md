# Balai Nadi — Bale di Telaga

> Earlier art iteration. The playable courtyard now uses v3; see
> [the current layout and tile fixes](../v3/README.md). These source assets are kept
> for reference and are not used by the current exterior scene.

Exterior gameplay is now a native Godot scene at
`res://scenes/world/balai_nadi/exterior.tscn`. The old interior and contribution
system remain connected to its entrance. The village entrance and interior exit
retain their existing spawn anchors.

## Editable scene

- `Terrain`: water, coastal grass, paths, water plants, and lotus clusters.
- `PelataranDanJembatan`: teak TileMapLayer, wooden railings, foundation edges.
- `Objek`: main bale, two resting bales, andesite lamps, ceremonial banners,
  naga guardians, offerings, and mixed mahogany/maple/birch vegetation.
- `CollisionAirDanBatas`: editor-visible water and map collision bodies.
- `RestorationVisual`: abandoned debris versus restored offerings and Daya motes.
- `SuasanaTelaga`: native looping AnimationPlayer for banner sway and lotus bobbing.
- `Entrance`, `ReturnWorld`, `Player`, `spawn`: existing gameplay interfaces.

Layout is serialized in `.tscn`, with reusable objects in `props/*.tscn`.
The gameplay root script only sets the day cycle and camera limits. It does not
create objects, generate terrain, or draw the environment in `_draw()`.
Edit positions, tile cells, collisions, and animation tracks directly in Godot.

Run `res://scenes/world/balai_nadi/courtyard_preview.tscn` with F6.
Space switches the visible restoration decoration without changing contributions
or writing restoration progress. Run `exterior.tscn` for the actual playable area.

## Assets and provenance

| File | Size | Authoring |
|---|---|---|
| `bale_agung.png` | 1254 × 1254 RGBA | Built-in image_gen: sacred open teak bale with joglo-inspired layered roof, ivory cloth, gold carving, bell, and Daya altar |
| `sacred_props.png` | 1536 × 1024 RGBA | Built-in image_gen: small bale, andesite lantern, umbul-umbul, naga guardian, lotus, offering bowl |
| `teak_andesite_tiles.png` | 128 × 64 RGBA | Native headless Godot authoring: new 16-pixel modular teak and andesite tiles |

The exact final image prompts are preserved in [generation_prompts.json](generation_prompts.json).
Generated PNG sources retain their original alpha and dimensions; AtlasTexture
regions select objects without modifying the source images. No complete landscape
is baked into a single background image. Building architecture is a fantasy
interpretation of Nusantara bale/pendopo motifs.

The existing Farm RPG pack supplies water, grassy coast, paths, mahogany, maple,
birch, shrubs, flowers, bridge posts, small water plants, and abandoned planks.
Existing water and grass shader materials are reused. New generated source files
live in this workspace, independently of the generation tool's original outputs.

The native TileSet resource is
`res://resources/balai_nadi/v2/teak_andesite_tileset.tres`; its ImageTexture embeds
the same newly authored pixels, so the first headless bake can save it before PNG
import. Icon AtlasTextures (`icon_bale`, `icon_lotus`, `icon_daya`) are provided
alongside it for future UI use. The icons are not wired into existing inventory UI.

## Authoring and validation

`tools/bake_balai_courtyard.gd` is a one-shot headless authoring tool, not a runtime
dependency. Re-running it replaces the authored exterior, prop scenes, and new
tileset. Prefer editing the saved scene directly after making manual changes.

```
Godot.exe --headless --path E:/nusa-vale --script res://tools/bake_balai_courtyard.gd
```

`tests/balai_courtyard_regression.tscn` checks the continuous bridge route, water
blocking, entrance interaction at both close and normal approach, village exit,
camera bounds, restoration updates, transparent imports, and preview state isolation.
Run tests with isolated `nusa-save-audit-*` APPDATA and `NUSA_SAVE_AUDIT=1`, matching
the repository's existing test harness. `--capture-courtyard` after `--` also writes
native Godot renders of both conditions to `scratch/` when using a graphical renderer.

The existing Balai contribution, wings, and art regressions additionally verify
travel transitions, saved progress, and old interior/asset compatibility.
