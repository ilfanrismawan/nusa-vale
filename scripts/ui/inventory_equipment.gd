extends PanelContainer

@export var entry_scene: PackedScene = preload("res://scenes/ui/inventory_action.tscn")
@export var empty_scene: PackedScene = preload("res://scenes/ui/inventory_empty.tscn")

const CATALOG = preload("res://resources/character/character_catalog.tres")
## Slot yang bisa dipakai + ikon samar saat kosong (kunci = PlayerData.EQUIPMENT_KEYS).
const EMPTY_ICONS := {
	"helmet": preload("res://resources/icons/icon_helmet_wood.tres"),
	"armor": preload("res://resources/icons/icon_armor_wood.tres"),
	"leggings": preload("res://resources/icons/icon_leggings_wood.tres"),
	"boots": preload("res://resources/icons/icon_boots_wood.tres"),
	"necklace": preload("res://resources/icons/icon_amulet_wood.tres"),
	"ring": preload("res://resources/icons/icon_ring_wood.tres"),
	"accessory": preload("res://resources/icons/icon_gloves_leather.tres"),
}
## Senjata tidak dipasang di sini: slot Weapon hanya menampilkan senjata yang dipegang di hotbar.
const WEAPON_ICON: Texture2D = preload("res://resources/icons/icon_sword_wood.tres")
var inventory_ui: CanvasLayer
var _available: VBoxContainer
var _stats: Label
var _message: Label
var _name: Label
var _portrait: TextureRect
var _preview_key := ""
var _entries: Array[Button] = []
var _remove_buttons: Dictionary = {}
var _weapon_button: Button

func _ready() -> void:
	inventory_ui = get_parent().get_parent().get_parent()
	_available = %Available
	_stats = %Stats
	_message = %Message
	_name = %Name
	_portrait = %Portrait
	_weapon_button = find_child("Slot_weapon", true, false)
	for key in EMPTY_ICONS:
		var button := find_child("Slot_" + key, true, false) as Button
		_remove_buttons[key] = button
		button.pressed.connect(_unequip.bind(key))
	refresh()

func refresh() -> void:
	if not visible or not is_instance_valid(_available):
		return
	var data: PlayerData = inventory_ui.data
	for child in _available.get_children():
		_available.remove_child(child)
		child.queue_free()
	_entries.clear()
	var stats := data.equipment_stats()
	var weapon := _held_weapon()
	_stats.text = "ATK %d   DEF %d" % [stats.x + (weapon.attack_bonus if weapon != null else 0), stats.y]
	if _weapon_button != null:
		var weapon_icon: TextureRect = _weapon_button.get_node("Icon")
		weapon_icon.texture = weapon.icon if weapon != null else WEAPON_ICON
		weapon_icon.modulate.a = 1.0 if weapon != null else 0.25
		var held_text := "%s (dipegang)\nATK +%d" % [weapon.display_name, weapon.attack_bonus] if weapon != null else "Tidak memegang senjata."
		_weapon_button.tooltip_text = held_text + "\nSenjata dipegang dari hotbar, tidak dipasang di sini."
	_name.text = data.player_name if not data.player_name.is_empty() else "Petani P%d" % (data.index + 1)
	var look_key := data.appearance.get_key()
	if _preview_key != look_key:
		_preview_key = look_key
		var result := CharacterSpriteBuilder.build(CATALOG, data.appearance, {}, PackedStringArray(["idle_down", "idle"]))
		var frames: SpriteFrames = result["frames"]
		var anim: StringName = &"idle_down" if frames.has_animation(&"idle_down") else &"idle"
		if frames.has_animation(anim) and frames.get_frame_count(anim) > 0:
			var image := frames.get_frame_texture(anim, 0).get_image()
			var bounds := image.get_used_rect().grow(2).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
			if bounds.has_area():
				_portrait.texture = ImageTexture.create_from_image(image.get_region(bounds))
	for key in _remove_buttons:
		var item: ItemData = data.equipment[key]
		var button: Button = _remove_buttons[key]
		var icon: TextureRect = button.get_node("Icon")
		icon.texture = item.icon if item != null else EMPTY_ICONS[key]
		icon.modulate.a = 1.0 if item != null else 0.25
		button.disabled = item == null
		button.tooltip_text = "%s\nATK +%d / DEF +%d\nKlik untuk melepas ke tas." % [item.display_name, item.attack_bonus, item.defense_bonus] if item != null else "Slot kosong — pasang perlengkapan dari tas."
	for slot in data.bag_size:
		var entry: Variant = data.inventory[slot]
		if entry == null or PlayerData.equipment_key(entry["item"]).is_empty():
			continue
		var item: ItemData = entry["item"]
		var button := entry_scene.instantiate() as Button
		button.text = "Pasang " + item.display_name
		button.icon = item.icon
		button.tooltip_text = "%s\nATK +%d / DEF +%d\n%s" % [item.display_name, item.attack_bonus, item.defense_bonus, item.description]
		button.pressed.connect(_equip.bind(slot))
		_available.add_child(button)
		_entries.append(button)
	if _entries.is_empty():
		var empty := empty_scene.instantiate() as Label
		_available.add_child(empty)
	%EquipmentPager.refresh()
	_message.text = "Kalung, cincin & aksesori\nmenambah ATK/DEF. Senjata\ndipegang di hotbar."

func _held_weapon() -> ItemData:
	var player: Player = inventory_ui.player
	if not is_instance_valid(player) or player.tool_controller == null:
		return null
	var item := player.tool_controller.current_item
	return item if Combat.is_weapon(item) else null

func _equip(slot: int) -> void:
	if not inventory_ui.data.equip_from_slot(slot):
		_message.text = "Perlengkapan tidak dapat dipasang."

func _unequip(key: String) -> void:
	if not inventory_ui.data.unequip(key):
		_message.text = "Tas penuh. Kosongkan satu slot sebelum melepas equipment."
