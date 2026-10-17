# Cooking catalog UI

Open `scenes/ui/cooking_ui.tscn` in Godot's 2D editor. The layout uses editable native Control nodes, not a baked screenshot. Its design canvas is 1920 × 1080 and scales uniformly to the player's viewport (including split-screen).

## Reference layout

- Title: top center.
- EquipmentScroll: horizontal equipment tabs, Q/R navigation.
- Panel/Layout/Scroll: seven-column recipe grid, scrollable independently.
- Detail: cream recipe panel with preview, name, equipment, description, stamina, food effects, ingredient counts, required equipment, and cooking/learning action.
- Footer: sorting, status, debug controls in debug builds, and Back.

## Editing

- Adjust positions/sizes directly in the main scene. Keep the exported `design_size` consistent with the design canvas.
- Edit card spacing and column count on `Rows`.
- Edit repeated cards in `scenes/ui/cooking_recipe_card.tscn`, equipment tabs in `scenes/ui/cooking_equipment_tab.tscn`, and ingredient/tool rows in `scenes/ui/cooking_ingredient_line.tscn`.
- Edit colors, rounded corners, font sizes and font in `resources/ui/cooking_theme.tres`. The default uses the installed Comic Sans MS bold system font with Segoe UI/Arial fallback; no font download is required. Assign a bundled FontFile here if consistent typography on other platforms is needed.
- Edit background blur/tints in the Backdrop ShaderMaterial inspector; shader: `resources/ui/cooking_backdrop.gdshader`.
- Recipe names/icons/ingredients/tool requirements remain in RecipeData resources. Descriptions, stamina and buffs remain in ItemData/FoodEffectData. Equipment tabs are generated from the exported catalog path, not a list of recipe IDs in code.
- The All tab and title use editable SVG book/pot icons; equipment/food pictures use the project's existing pixel assets, not the reference's illustrations.
- Tool filtering never grants equipment. Learning, inventory transactions, missing-tool validation, and per-player pause behavior still use the existing cooking service.
- Tab cycles Default / Nama / Siap masak. Click a card or focus it to inspect; select the action in the detail panel to learn/cook.

## Validation

Run `tests/cooking_ui_layout_regression.tscn` with `NUSA_SAVE_AUDIT=1` and an isolated APPDATA directory. Headless mode checks layout/data bindings. With a graphical renderer, `NUSA_COOKING_SCREENSHOT=1` also saves `scratch/cooking-ui-preview.png`.
