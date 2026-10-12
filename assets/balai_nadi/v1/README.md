# Balai Nadi art pack v1

Generated with the built-in image_gen tool using the supplied concept sheet as a
style/architecture reference. Exact prompts are in `generation_prompts.json`.
The source outputs are preserved without resizing or alpha processing.

| Asset | Dimensions | Contents |
|---|---|---|
| exterior_ruined.png | 1374 × 1145 | Damaged roof, vines, worn banners, unlit lamps |
| exterior_restored.png | 1374 × 1145 | Repaired roof, lotus emblem, blue banners, flowers |
| interior_ruined.png | 1448 × 1086 | Neglected room, worn desk, faded rugs and map |
| interior_restored.png | 1448 × 1086 | Welcoming room, contribution desk, map and bookshelf |
| props_atlas.png | 1536 × 1024 | Desk, bookshelf, village map, banner, lantern, flowerpot |

All five PNGs have RGBA transparency. The exterior pair has identical canvas dimensions;
the interior pair also has identical canvas dimensions and corresponding room layout.
No characters, labels, UI or landscape were baked into the building images.
Interior furniture is baked into the room images; use the separate prop resources when
assembling a modular room. These are detailed pixel-style source images, not an exact
16 × 16 terrain tileset. Check readability at the intended game scale before final placement.

## Godot usage

Run `res://scenes/world/balai_nadi/art_preview.tscn` with F6. Space toggles both asset
pairs between ruined and restored. This preview consumes the new textures without
changing gameplay state, inventory, project completion, existing maps or collision.
The existing gameplay scenes remain available independently.

Use nearest texture filtering on Sprite2D/Node2D (`texture_filter = 1`). The six
AtlasTexture resources in `res://resources/balai_nadi/v1/` expose each prop without
editing the source atlas. Rectangles deliberately follow the actual generated object
bounds rather than assuming a uniform grid:

| Resource | Atlas region (x, y, width, height) | Suggested starting logical size |
|---|---|---|
| contribution_table.tres | 0, 0, 608, 520 | 64 × 55 |
| bookshelf.tres | 608, 0, 368, 520 | 32 × 45 |
| village_map.tres | 976, 0, 560, 520 | 64 × 59 |
| banner.tres | 0, 520, 608, 504 | 32 × 27 (includes padding) |
| lantern.tres | 608, 520, 368, 504 | 16 × 22 |
| flowerpot.tres | 976, 520, 560, 504 | 24 × 22 |

For gameplay integration, the existing restoration flag is `balai_nadi_restored` and
the project ID is `balai_nadi_restoration`. Switch the matching texture pair using the
existing manager's state_changed signal. Align each state's south-facing door to the
same interaction/collision anchor. The preview is not a replacement for collider placement.

## Verification

Dimensions, PNG alpha, paired canvas sizes and transparent margins were inspected.
The source images were visually reviewed. Godot preview and AtlasTexture loading are
checked by `tests/balai_nadi_art_regression.tscn` in an isolated audit user directory.
