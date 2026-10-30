# Balai Nadi MVP

Update: proyek kedua **Pemulihan Greenhouse** sekarang terhubung ke greenhouse di farm.
Lihat `docs/GREENHOUSE.md` untuk kebutuhan, alur bermain, versi save 9 dan perubahan farming.
Detail MVP awal berikut merupakan catatan implementasi pertama.

Update 2026-10-30: `exterior.tscn` dan `interior.tscn` sudah diganti satu scene
`scenes/world/balai_nadi/balai.tscn` (telaga, jembatan, Bale Agung). Pintu Kota
(`scenes/world/exterior/town/balai_access.tscn`) membawa pemain ke ujung selatan jembatan;
kontribusi dibuka lewat `BaleAgung/BalaiInteractionArea` di prop `bale_agung.tscn`;
`ReturnTown` di tepi selatan kembali ke Kota. Bagian "Play and integrate" di bawah
menggambarkan dua scene lama dan hanya tersisa sebagai riwayat.

Balai Nadi is an optional, persistent community restoration. Its first project accepts
100 `wood` (Kayu) and 50 `stone` (Stone), using existing ItemData resources.

## File inventory

Created (Godot-generated `.gd.uid` companions included):

* `scripts/resources/restoration_project.gd`
* `resources/restoration/balai_nadi_restoration.tres`
* `scripts/system/balai_nadi_manager.gd`
* `scripts/ui/balai_nadi_ui.gd`
* `scripts/world/balai_nadi_interactable.gd`
* `scripts/world/balai_nadi_visual.gd`
* `scripts/world/balai_nadi_area.gd`
* `scenes/world/balai_nadi/exterior.tscn`
* `scenes/world/balai_nadi/interior.tscn`
* `tests/balai_nadi_regression.gd`
* `tests/balai_nadi_regression.tscn`
* `docs/BALAI_NADI.md`

Modified: `autoload/game_state.gd` (manager lifetime/reset),
`autoload/save_manager.gd` (version 8 serialize/load),
`scripts/system/world_state.gd` (default restoration flag), and
`tools/verify_mvp.ps1` (scene smoke checks and Balai regression).
Player, inventory, existing map scenes and TileMap data were not edited for this feature.

## Play and integrate

Open `scenes/world/balai_nadi/exterior.tscn` in Godot and run the current scene (F6).
Walk toward the front door and press the existing interact action (E). Inside, approach
the workbench from below, face up and press E. Each material has a contribution button
that donates as much as the bag holds, capped at the remaining requirement. Close with
Tutup, Esc or the inventory action. Face down near the interior exit and press E to
return to the exterior. Existing F1 debug inventory tools can supply test materials.
This scene loads the selected save slot through the normal SaveManager startup;
contributions save that slot. Use a spare slot for manual testing.

The exterior and interior are a standalone playable slice. The existing town scene is
generated (`scripts/world/town.gd`); no safe dedicated plot was established, so no existing
map/TileMap was changed. For final placement, add an entrance Area2D using
`scripts/world/balai_nadi_interactable.gd`, `interaction_type = 1`,
`target_scene = res://scenes/world/balai_nadi/interior.tscn`,
`spawn_position = Vector2(427, 296)`. Set the interior Exit's target scene/spawn to the
chosen world doorway. The scene root `spawn` marker also supports the existing co-op
area loader. The standalone exterior can be reached via the same Transition API.

## Architecture

* `RestorationProject` is a Resource: ID, title, description, item-ID requirements and
  completion flag. The first definition is `resources/restoration/balai_nadi_restoration.tres`.
* `GameState.balai_nadi` is a child Node manager, rather than a new autoload. It owns all
  validation, contributions, completion and serialization. Its definitions array supports
  more projects, and the UI selector reads this array.
* `BalaiNadiUI` displays state and inventory; it invokes the manager with the actual
  player's PlayerData, using existing inventory button styling, m5x7 font and Coop modal
  behavior. The contribution table tracks one menu per player.
* `balai_nadi_visual.gd` switches the `Unrestored` and `Restored` children on state changes.
  `balai_nadi_area.gd` draws replaceable pixel-style floor/building placeholders. The
  table uses the existing workbench art. Replace visual children/drawing independently
  of interactions, collision and state.

The manager exposes `contribution_added(project_id, item_id, amount)`,
`project_completed(project_id)` and `state_changed`. Only new successful completion
emits `project_completed`. The MVP reward is the restored building/interior itself;
no item/currency rewards or reward configuration are implemented.

## Saves and transaction behavior

Save version 8 adds a plain dictionary `balai_nadi.projects`, with each project's
`contributions` and `completed` fields. Saves from versions 1–7 remain supported;
missing project data initializes to zero. Loading normalizes quantities, reconciles
`balai_nadi_restored` with completion and emits state refresh without completion events.
GameState.new_game() resets this subsystem and its flags. Other world flags are preserved.

Contributions clamp to the requested amount, available active bag contents and remaining
requirement. Inventory deduction, progress and the flag are written in one existing
SaveManager snapshot. A save failure rolls back inventory, progress and flag and displays
a retry notification. A reentrancy guard prevents duplicate deductions during synchronous
inventory/save signal callbacks. Restoration events are published only after saving.
All tests redirect APPDATA; real saves are never used by automated validation.

## Validation

Run `tools/verify_mvp.ps1` (default engine: `E:\Godot\Godot.exe`). The suite includes
the Balai scenes and `tests/balai_nadi_regression.tscn`, alongside the existing parser,
gameplay, inventory, crafting, structures, crops, co-op, character and save regressions.
The Balai test deliberately forces one backup write error to prove rollback; expected
I/O errors are allowed, while script errors and failed assertions still fail the run.

Manual check: inspect the parchment modal at 854×480, walk through both doors with E,
contribute gathered materials, close the modal and check movement/tool use, then reopen
the scene after completion to inspect both restored visual states.

Executed with Godot 4.7.2: editor/parser, main menu, eight world-scene smoke checks,
co-op, crafting, structures/furnace, gameplay, all 39 crops, character animations and
save regressions passed. Balai regression covers actual disk saves/reloads, rollback,
real mouse clicks, Escape close, per-player co-op modal locks and both doorway transitions.
The 854×480 modal and restored interior were rendered and visually inspected.
The existing inventory-menu regression has two recipe-grid pointer/selection failures.
Both were reproduced in an isolated copy with Balai modifications removed. Consequently
the aggregate verification command still stops at that existing menu regression failure;
the remaining suites were run individually and passed.

## MVP limits and next milestone

No NPCs, quests, cutscenes, festivals or additional restoration projects. Art is temporary,
and the permanent town/farm doorway location still needs a map placement decision.
Next: choose a town plot and connect its doorway to this interior while replacing the
exterior placeholder with dedicated Balai Nadi pixel art.
