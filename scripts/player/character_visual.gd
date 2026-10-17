class_name CharacterVisual
extends Node

## Mengganti SpriteFrames Player dengan hasil susun layer sesuai GameState.appearance.
## Alat di tangan ikut tier alat yang sedang dipegang (Weapons/<Alat>/1..10).
## Dibuat dari player.gd, jadi Player.tscn tidak perlu diubah.

const CATALOG: CharacterCatalog = preload("res://resources/character/character_catalog.tres")
## Kunci tier senjata di _tool_tiers dan CharacterSheet.tool_type = 100 + ItemData.WeaponType
## (pedang 101, busur 102), supaya tidak bentrok dengan ToolData.ToolType.
const WEAPON_TIER_KEY_BASE := 100

var sprite: AnimatedSprite2D
## {ToolData.ToolType: ToolData.ToolTier}
var _tool_tiers: Dictionary = {}
## {source_sheet: ImageTexture} hasil build terakhir; diperbarui di tempat saat tier alat berubah.
var _textures: Dictionary = {}
var _appearance: CharacterAppearance
var _tool_controller: ToolController

func setup(target: AnimatedSprite2D, tool_controller: ToolController) -> void:
	sprite = target
	_tool_controller = tool_controller
	if tool_controller != null:
		_read_tool_tier(tool_controller.current_tool)
		_read_weapon_tier()
		tool_controller.tool_changed.connect(_on_tool_changed)
	# Co-op: setiap pemain memakai penampilannya sendiri.
	var data: PlayerData = tool_controller.player.data if tool_controller != null and tool_controller.player != null else GameState.p1()
	apply_appearance(data.appearance)
	data.appearance_changed.connect(apply_appearance)

func apply_appearance(appearance: CharacterAppearance) -> void:
	if sprite == null:
		return
	_appearance = CATALOG.sanitize(appearance)
	var result := CharacterSpriteBuilder.build(CATALOG, _appearance, _tool_tiers)
	var frames: SpriteFrames = result["frames"]
	if frames.get_animation_names().is_empty():
		return
	_textures = result["textures"]

	var anim := sprite.animation
	var frame := sprite.frame
	var progress := sprite.frame_progress
	var was_playing := sprite.is_playing()
	sprite.sprite_frames = frames
	if frames.has_animation(anim):
		sprite.animation = anim
		sprite.set_frame_and_progress(frame, progress)
		if was_playing:
			sprite.play(anim)

func _on_tool_changed(action: ActionData) -> void:
	if _read_tool_tier(action):
		_refresh_tool_sheets(action.tool_data.tool_type)
	var weapon_key := _read_weapon_tier()
	if weapon_key >= 0:
		_refresh_tool_sheets(weapon_key)

## Senjata yang dipegang di hotbar: catat tiernya. Mengembalikan kunci yang berubah, -1 = tetap.
func _read_weapon_tier() -> int:
	var item: ItemData = _tool_controller.current_item if _tool_controller != null else null
	if item == null or item.weapon_type == ItemData.WeaponType.NONE or item.weapon_type == ItemData.WeaponType.ARROW:
		return -1
	var key := WEAPON_TIER_KEY_BASE + int(item.weapon_type)
	var tier := int(item.equipment_tier)
	if _tool_tiers.has(key) and int(_tool_tiers[key]) == tier:
		return -1
	_tool_tiers[key] = tier
	return key

## true jika tier alat jenis ini berubah.
func _read_tool_tier(action: ActionData) -> bool:
	if action == null or action.tool_data == null:
		return false
	var tool_type: int = action.tool_data.tool_type
	var tier: int = action.tool_data.tier
	if _tool_tiers.has(tool_type) and int(_tool_tiers[tool_type]) == tier:
		return false
	_tool_tiers[tool_type] = tier
	return true

func _refresh_tool_sheets(tool_type: int) -> void:
	if _appearance == null:
		return
	for sheet in CATALOG.sheets:
		if sheet == null or sheet.tool_type != tool_type:
			continue
		var texture: ImageTexture = _textures.get(sheet.part_folder if not sheet.animation_name.is_empty() else sheet.source_sheet)
		if texture == null:
			continue
		var tier := int(_tool_tiers.get(tool_type, 0))
		var image := CharacterSpriteBuilder.compose_sheet(sheet, CATALOG, _appearance, tier, Vector2i(texture.get_size()))
		texture.update(image)
