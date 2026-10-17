# Blacksmith / tool upgrade UI

Main scene: `scenes/ui/tool_upgrade_ui.tscn`. The old code-built menu is replaced with editable native Control nodes, using the supplied reference composition: seller on the left, tool-tier matrix in the center, cream recipe/cost panel on the right, and blurred world behind.

## Editing

- Design canvas: 1600 × 800, fitted uniformly to each player viewport.
- Layout, font sizes, panel shapes and button positions: Design children in the main scene.
- PortraitLayers: seven native TextureRect layers for the existing Empu Bima portrait (skin, eyes, shirt, apron, hair, beard, arm). Replace their AtlasTexture regions in the Inspector if needed.
- Presentation resource: `resources/ui/blacksmith_presentation.tres`; seller name/dialog, optional full-body vendor_art override, tool ordering, tier labels, fallback descriptions, material availability colors, tiers_per_page.
- Cards: `scenes/ui/blacksmith_tool_card.tscn`.
- Requirement rows: `scenes/ui/blacksmith_material_row.tscn`.
- Theme: shared `resources/ui/cooking_theme.tres`; use local scene overrides for blacksmith-only changes.
- Backdrop ShaderMaterial: adjust blur/tints in the Inspector.

The default shows four tier columns. Q/R or the arrow buttons switch pages; all nine existing upgrade tiers and all seven supported tool types remain accessible. Vertical scrolling reveals the extra tool types below the reference's visible rows. A future tier can be inspected but cannot be purchased without its preceding tool.

Cost and material quantities come from the existing ToolUpgradeManager / ToolData resources (`resources/tool_data/*.tres`), not from UI labels or duplicated prices. ItemData supplies result icons/names/descriptions. Benefits use the before/after ToolData values. Work duration remains the existing backend's WORK_DAYS (2); the reference's four-day/20,000-coin example is not copied into game balance.

An order still holds the old tool, charges exactly once, belongs to its interacting player, survives existing save/load, and can only be collected after its completion day. Full inventory leaves the finished order safely at the blacksmith. Money/material changes refresh the UI without editing the upgrade resources.

Controls: click/focus a card, confirm with the button or Enter. Q/R changes tiers. Gamepad movement selects cards, LB/RB changes tiers, A confirms, B cancels. Esc closes for keyboard owners. Name/image stay Empu Bima and project tool assets, not the screenshot's Pablo/Coral Island art.

Tests: `tests/blacksmith_ui_regression.tscn` and `tests/service_ui_regression.tscn` with `NUSA_SAVE_AUDIT=1` and isolated APPDATA. Graphical mode with `NUSA_BLACKSMITH_SCREENSHOT=1` writes `scratch/blacksmith-ui-preview.png`.
