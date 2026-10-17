# Livestock shop UI

Open `scenes/ui/livestock_shop_ui.tscn` in Godot's 2D editor. This replaces the old code-built menu with native editable controls. The reference composition is a large seller illustration on the left, four-column animal cards in the center, cream detail panel on the right, and variant swatches under the panel.

- Design canvas: 1280 × 960 (matching the supplied reference's 4:3 ratio), fitted uniformly inside the player's viewport. The blurred game backdrop fills the whole viewport, including widescreen margins.
- Main layout: Design children. Edit positions, sizes, text sizes, cards, detail panel, housing/name fields and footer directly in the scene.
- Repeated cards: `scenes/ui/livestock_animal_card.tscn`.
- Variant buttons: `scenes/ui/livestock_variant_swatch.tscn`.
- Theme: `resources/ui/cooking_theme.tres`, shared with cooking. Local node overrides can style this screen without changing cooking.
- Backdrop: native ShaderMaterial on Backdrop; blur and tint can be edited in the Inspector.
- Presentation: `resources/ui/livestock_shop_presentation.tres`. Edit seller art/name/dialog, species order, descriptions, housing labels, optional animal icon overrides, slot count and supported variant swatch labels/colors here.

The screen intentionally uses Rian's existing pixel portrait and the project's Farm Animals head-icon sheet, not the supplied screenshot's Jack illustration or Coral Island animal art. Assign a full-body illustrated Texture2D to vendor_art to replace the seller artwork without changing code. Icon overrides use species IDs and optional species_variant keys; missing overrides fall back to the world-sprite frame.

Only the five existing supported species are purchasable. Empty slots are disabled placeholders, not new animals. Only white/brown chicken variants are currently implemented; unsupported colors are not presented as purchasable options. Adding arbitrary colors to presentation alone does not add animal variants to the husbandry backend.

Prices, production intervals, products, capacities, and purchases continue to use the existing RanchHusbandry/StructureManager backend; this visual redesign does not change economic balance or save format. Housing selection, optional animal names, shared money, full-barn rollback, and per-player menu ownership are preserved.

Controls: click/focus an animal card; choose a housing destination, optional name, and supported color; click Buy or press Enter. Enter in the name field does not buy accidentally. Gamepad/numpad movement selects animals and Accept buys exactly once. Gamepad LB/RB cycles housing and Y cycles supported colors (the equivalent owner input actions work for numpad). Esc/Cancel closes.

Validation: run `tests/livestock_shop_ui_regression.tscn` with isolated APPDATA and `NUSA_SAVE_AUDIT=1`. Graphical mode plus `NUSA_LIVESTOCK_SCREENSHOT=1` saves `scratch/livestock-shop-ui-preview.png`. The existing `tests/doors_livestock_shop_regression.tscn` also checks the real Rian interaction and purchase flow.
