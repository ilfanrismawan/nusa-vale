## DebugManager — Autoload khusus untuk testing/cheat
## 
## CARA DISABLE SAAT RELEASE:
##   Hapus baris "DebugManager=..." dari [autoload] di project.godot
##   ATAU beri tanda komentar # di depannya.
##   Tidak ada kode lain yang bergantung pada autoload ini.
##
## SHORTCUT DEFAULT (aktif saat game berjalan):
##   F1  → Toggle panel cheat (buka/tutup)
##   F2  → Tambah 1000 Gold
##   F3  → Isi penuh Stamina
##   F4  → Tambah hari berikutnya
##   F5  → Spawn semua ore (copper, iron, gold) ke inventory
##   F6  → Upgrade tas ke level berikutnya
##   F7  → Tambah semua seed (strawberry, carrot) ×10
##   F8  → Cetak state inventory ke console
##   F9  → Hapus save file (reset total)
##   F10 → Toggle god mode (stamina tidak berkurang)

extends CanvasLayer
#class_name DebugManager

## ── Konfigurasi ──────────────────────────────────────────────────────────────
const ENABLED := true   # Ganti ke false untuk matikan semua tanpa hapus kode

var _panel: PanelContainer
var _god_mode: bool = false
var _stamina_backup: int = -1

## ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	if not ENABLED:
		return

	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	name = "DebugManager"

	_build_panel()
	print("[DEBUG] DebugManager aktif. Tekan F1 untuk panel cheat.")

func _unhandled_input(event: InputEvent) -> void:
	if not ENABLED:
		return
	if not event is InputEventKey or not event.pressed or event.is_echo():
		return

	match event.physical_keycode:
		KEY_F1:
			_toggle_panel()
			get_viewport().set_input_as_handled()
		KEY_F2:
			_cheat_add_gold(1000)
			get_viewport().set_input_as_handled()
		KEY_F3:
			_cheat_fill_stamina()
			get_viewport().set_input_as_handled()
		KEY_F4:
			_cheat_next_day()
			get_viewport().set_input_as_handled()
		KEY_F5:
			_cheat_add_ores()
			get_viewport().set_input_as_handled()
		KEY_F6:
			_cheat_upgrade_bag()
			get_viewport().set_input_as_handled()
		KEY_F7:
			_cheat_add_seeds()
			get_viewport().set_input_as_handled()
		KEY_F8:
			_cheat_print_inventory()
			get_viewport().set_input_as_handled()
		KEY_F9:
			_cheat_delete_save()
			get_viewport().set_input_as_handled()
		KEY_F10:
			_cheat_toggle_god_mode()
			get_viewport().set_input_as_handled()
		KEY_F11:
			_cheat_upgrade_tools()
			get_viewport().set_input_as_handled()
		KEY_INSERT:
			_cheat_add_bridge_materials()
			get_viewport().set_input_as_handled()

## ── God Mode Hook ─────────────────────────────────────────────────────────────
func _process(_delta: float) -> void:
	if not ENABLED or not _god_mode:
		return
	# Paksa stamina tetap penuh saat god mode aktif
	if GameState.stamina < GameState.MAX_STAMINA:
		GameState.stamina = GameState.MAX_STAMINA
		GameState.stamina_changed.emit(GameState.stamina, GameState.MAX_STAMINA)

## ── Panel UI ──────────────────────────────────────────────────────────────────
func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.visible = false
	_panel.z_index = 200
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	# Posisi kiri atas
	var ctrl := Control.new()
	ctrl.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	ctrl.offset_left = 8
	ctrl.offset_top = 8
	add_child(ctrl)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.1, 0.92)
	style.set_border_width_all(2)
	style.border_color = Color(1.0, 0.6, 0.1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 10
	_panel.add_theme_stylebox_override("panel", style)
	ctrl.add_child(_panel)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)

	var font := preload("res://assets/fonts/m5x7.ttf")
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 14
	_panel.theme = theme

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(220, 0)
	_panel.add_child(box)

	# Judul
	var title := Label.new()
	title.text = "🛠  DEBUG / CHEAT PANEL"
	title.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
	title.add_theme_font_size_override("font_size", 16)
	box.add_child(title)
	box.add_child(HSeparator.new())

	# Daftar shortcut
	var shortcuts := [
		["F2", "Tambah 1.000 Gold",        _cheat_add_gold.bind(1000)],
		["F3", "Isi penuh Stamina",         _cheat_fill_stamina],
		["F4", "Maju ke hari berikutnya",   _cheat_next_day],
		["F5", "Spawn Ore (Copper/Iron/Gold)", _cheat_add_ores],
		["F6", "Upgrade Tas",               _cheat_upgrade_bag],
		["F7", "Tambah Seeds ×10",          _cheat_add_seeds],
		["F8", "Print Inventory (console)", _cheat_print_inventory],
		["F9", "Hapus Save File",           _cheat_delete_save],
		["F10","Toggle God Mode",           _cheat_toggle_god_mode],
		["F11","Upgrade Semua Tool",        _cheat_upgrade_tools],
	]

	for entry in shortcuts:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var key_lbl := Label.new()
		key_lbl.text = "[%s]" % entry[0]
		key_lbl.custom_minimum_size = Vector2(42, 0)
		key_lbl.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))
		row.add_child(key_lbl)

		var desc_lbl := Label.new()
		desc_lbl.text = entry[1]
		desc_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.85))
		desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(desc_lbl)

		var btn := Button.new()
		btn.text = "▶"
		btn.custom_minimum_size = Vector2(28, 0)
		btn.pressed.connect(entry[2])
		row.add_child(btn)

		box.add_child(row)

	box.add_child(HSeparator.new())

	var hint := Label.new()
	hint.text = "F1 = tutup panel ini"
	hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	hint.add_theme_font_size_override("font_size", 12)
	box.add_child(hint)

func _toggle_panel() -> void:
	if is_instance_valid(_panel):
		_panel.visible = not _panel.visible

## ── Cheat Functions ───────────────────────────────────────────────────────────

func _cheat_add_bridge_materials() -> void:
	GameState.add_item("wood", 20)
	GameState.add_item("stone", 10)
	_notify("🌉 +20 Wood & +10 Stone (cukup untuk perbaiki jembatan)")

#func _cheat_reset
func _cheat_add_gold(amount: int) -> void:
	GameState.add_money(amount)
	_notify("💰 +%d Gold  (Total: %d G)" % [amount, GameState.money])

func _cheat_fill_stamina() -> void:
	GameState.stamina = GameState.MAX_STAMINA
	GameState.stamina_changed.emit(GameState.stamina, GameState.MAX_STAMINA)
	_notify("⚡ Stamina penuh!")

func _cheat_next_day() -> void:
	DayCycle.advance_day()
	_notify("📅 Hari %d dimulai." % DayCycle.current_day)

func _cheat_add_ores() -> void:
	var ores := ["copper_ore", "iron_ore", "gold_ore", "platinum_ore"]
	for ore in ores:
		GameState.add_item(ore, 8)
	_notify("⛏  +8 Copper/Iron/Gold/Platinum Ore")

func _cheat_upgrade_bag() -> void:
	if GameState.bag_level >= GameState.BAG_SIZES.size() - 1:
		_notify("👜 Tas sudah level maksimal (%d slot)." % GameState.bag_size)
		return
	GameState.bag_level += 1
	GameState.bag_upgraded.emit(GameState.bag_size)
	GameState.inventory_changed.emit()
	_notify("👜 Tas di-upgrade → %d slot" % GameState.bag_size)

func _cheat_add_seeds() -> void:
	GameState.add_item("seed_strawberry", 10)
	GameState.add_item("seed_carrot", 10)
	_notify("🌱 +10 Seed Strawberry & Carrot")

func _cheat_print_inventory() -> void:
	print("\n══════════════ INVENTORY DEBUG ══════════════")
	print("Bag Level : %d  |  Bag Size : %d" % [GameState.bag_level, GameState.bag_size])
	print("Money     : %d G" % GameState.money)
	print("Stamina   : %d / %d" % [GameState.stamina, GameState.MAX_STAMINA])
	print("Day       : %d  |  Time : %02d:%02d" % [DayCycle.current_day, DayCycle.hour, DayCycle.minute])
	print("─────────────────────────────────────────────")
	for i in GameState.bag_size:
		var slot = GameState.inventory[i]
		if slot == null:
			print("  [%02d] (kosong)" % i)
		else:
			print("  [%02d] %s  ×%d" % [i, slot["item"].item_id, slot["count"]])
	print("═════════════════════════════════════════════\n")
	_notify("📋 Inventory dicetak ke Output console.")

func _cheat_delete_save() -> void:
	SaveManager.delete_save() if SaveManager.has_method("delete_save") else _delete_save_fallback()
	_notify("🗑  Save file dihapus. Restart game untuk new game.")

func _delete_save_fallback() -> void:
	var path := "user://nusa_vale_save.json"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
		print("[DEBUG] Save file dihapus: %s" % path)
	else:
		print("[DEBUG] Tidak ada save file ditemukan.")

func _cheat_upgrade_tools() -> void:
	var max_tier = ToolUpgradeManager.TIERS.back()
	var upgraded_count = 0
	
	for i in range(GameState.bag_size):
		var slot = GameState.inventory[i]
		if slot != null and slot["item"] != null:
			var item: ItemData = slot["item"]
			if item.is_tool():
				# Ambil tipe dasar tool (misal "axe" dari "axe_wood")
				var parts = item.item_id.split("_")
				var tool_type = parts[0]
				var new_tool_id = tool_type + "_" + max_tier
				
				# Load item baru
				var new_item: ItemData = GameState._resolve_item(new_tool_id)
				if new_item != null:
					GameState.inventory[i]["item"] = new_item
					upgraded_count += 1
	
	if upgraded_count > 0:
		GameState.inventory_changed.emit()
		_notify("⚒ Semua %d tool di-upgrade ke tier %s!" % [upgraded_count, max_tier.capitalize()])
	else:
		_notify("⚒ Tidak ada tool di inventory untuk di-upgrade.")

func _cheat_toggle_god_mode() -> void:
	_god_mode = not _god_mode
	if _god_mode:
		_notify("🛡  God Mode ON — Stamina tidak berkurang.")
	else:
		_notify("🛡  God Mode OFF.")

func _notify(msg: String) -> void:
	print("[DEBUG] %s" % msg)
	if Notify:
		Notify.say("[DEBUG] " + msg)
