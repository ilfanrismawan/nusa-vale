## DebugManager — Autoload khusus untuk testing/cheat
## 
## Otomatis nonaktif pada release build.
## CARA DISABLE SAAT DEBUG:
##   Hapus baris "DebugManager=..." dari [autoload] di project.godot
##   ATAU beri tanda komentar # di depannya.
##   Tidak ada kode lain yang bergantung pada autoload ini.
##
## SHORTCUT DEFAULT (aktif saat game berjalan):
##   F1     → Toggle panel cheat (buka/tutup)
##   F2     → Tambah 1000 Gold
##   F3     → Isi penuh Stamina
##   F4     → Tambah hari berikutnya
##   F5     → Spawn semua ore & coal ke inventory
##   F6     → Upgrade tas ke level berikutnya
##   F7     → Tambah semua benih musim aktif ×10
##   F8     → Cetak state inventory ke console
##   F9     → Hapus save file (reset total)
##   F10    → Toggle god mode (stamina tidak berkurang)
##   F11    → Upgrade semua tool ke tier maksimal (Obsidian)
##   INSERT → Bahan perbaikan jembatan (+20 Wood, +10 Stone)
##   HOME   → Toggle ikan gigit instan (Fishing)
##   END    → Toggle auto-menang minigame (Fishing)

extends CanvasLayer

## ── Konfigurasi ──────────────────────────────────────────────────────────────
const ENABLED := true   # Ganti ke false untuk matikan semua tanpa hapus kode

var _panel: PanelContainer
var _god_mode: bool = false
var _speed_boost: bool = false
var _equipment_tier: int = 0

## ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	if not ENABLED or not OS.is_debug_build():
		set_process(false)
		set_process_unhandled_input(false)
		return

	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	name = "DebugManager"

	_build_panel()
	print("[DEBUG] DebugManager aktif. Tekan F1 untuk panel cheat.")

func _unhandled_input(event: InputEvent) -> void:
	if not ENABLED or not OS.is_debug_build():
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
			_cheat_add_current_season_seeds()
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
		KEY_HOME:
			_cheat_toggle_instant_bite()
			get_viewport().set_input_as_handled()
		KEY_END:
			_cheat_toggle_auto_win()
			get_viewport().set_input_as_handled()

## ── Process Hooks ─────────────────────────────────────────────────────────────
func _process(_delta: float) -> void:
	if not ENABLED or not OS.is_debug_build():
		return

	# God Mode: stamina selalu penuh
	if _god_mode and GameState:
		if GameState.stamina < GameState.MAX_STAMINA:
			GameState.stamina = GameState.MAX_STAMINA
			GameState.stamina_changed.emit(GameState.stamina, GameState.MAX_STAMINA)

	# Speed Boost: jaga kecepatan player
	if _speed_boost:
		var players = get_tree().get_nodes_in_group("player")
		if players.is_empty():
			var p = get_tree().current_scene.find_child("Player", true, false)
			if p is Player and p.speed < 75.0:
				p.speed = 75.0
		else:
			for p in players:
				if p is Player and p.speed < 75.0:
					p.speed = 75.0

## ── Panel UI ──────────────────────────────────────────────────────────────────
func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.visible = false
	_panel.z_index = 200
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var ctrl := Control.new()
	ctrl.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	ctrl.offset_left = 8
	ctrl.offset_top = 8
	add_child(ctrl)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.04, 0.08, 0.94)
	style.set_border_width_all(2)
	style.border_color = Color(1.0, 0.65, 0.15)
	style.set_corner_radius_all(6)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	_panel.add_theme_stylebox_override("panel", style)
	ctrl.add_child(_panel)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)

	var font := preload("res://assets/fonts/m5x7.ttf")
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 14
	_panel.theme = theme

	var root_box := VBoxContainer.new()
	root_box.custom_minimum_size = Vector2(260, 0)
	_panel.add_child(root_box)

	# Header Panel
	var header := HBoxContainer.new()
	var title := Label.new()
	title.text = "🛠  DEBUG / CHEAT MENU"
	title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.2))
	title.add_theme_font_size_override("font_size", 16)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "✖"
	close_btn.custom_minimum_size = Vector2(22, 20)
	close_btn.pressed.connect(_toggle_panel)
	header.add_child(close_btn)
	root_box.add_child(header)
	root_box.add_child(HSeparator.new())

	# Scroll Container agar muat di layar tanpa terpotong
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(260, 340)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_box.add_child(scroll)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 3)
	scroll.add_child(box)

	# ── Kategori: Pemain & Stats ──
	_add_category_header(box, "👑  PEMAIN & KARAKTER")
	_add_cheat_row(box, "F2", "Tambah 1.000 Gold", _cheat_add_gold.bind(1000))
	_add_cheat_row(box, "", "Tambah 10.000 Gold", _cheat_add_gold.bind(10000))
	_add_cheat_row(box, "F3", "Isi Penuh Stamina", _cheat_fill_stamina)
	_add_cheat_row(box, "F10", "Toggle God Mode (Stamina Tak Terbatas)", _cheat_toggle_god_mode)
	_add_cheat_row(box, "", "Toggle Speed Boost (2.5x)", _cheat_toggle_speed_boost)
	_add_cheat_row(box, "F6", "Upgrade Tas (+12 Slot)", _cheat_upgrade_bag)
	_add_cheat_row(box, "F11", "Upgrade Semua Tool ke Obsidian", _cheat_upgrade_tools)
	_add_cheat_row(box, "", "Set Senjata & Armor (tier berikutnya)", _cheat_add_equipment_set)

	# ── Kategori: Waktu & Musim ──
	_add_category_header(box, "⏰  WAKTU & MUSIM")
	_add_cheat_row(box, "F4", "Maju ke Hari Berikutnya", _cheat_next_day)
	_add_cheat_row(box, "", "Maju Waktu +2 Jam", _cheat_advance_hours.bind(2))
	_add_cheat_row(box, "", "Maju ke Musim Berikutnya", _cheat_next_season)

	# ── Kategori: Pertanian & Kebun ──
	_add_category_header(box, "🌾  PERTANIAN & HASIL KEBUN")
	_add_cheat_row(box, "F7", "Benih Musim Aktif ×10", _cheat_add_current_season_seeds)
	_add_cheat_row(box, "", "Semua 39 Jenis Benih ×5", _cheat_add_all_seeds)
	_add_cheat_row(box, "", "Koleksi Hasil Panen (Crops) ×5", _cheat_add_all_crops)
	_add_cheat_row(box, "", "Siram Semua Tanah (Water All)", _cheat_water_all_crops)
	_add_cheat_row(box, "", "Tumbuhkan Semua Tanaman (Panen Instan)", _cheat_instant_grow_crops)

	# ── Kategori: Memancing ──
	_add_category_header(box, "🎣  MEMANCING")
	_add_cheat_row(box, "Home", "Toggle Ikan Gigit Instan", _cheat_toggle_instant_bite)
	_add_cheat_row(box, "End", "Toggle Auto-Menang Minigame", _cheat_toggle_auto_win)
	_add_cheat_row(box, "", "Spawn Koleksi Ikan & Biota Laut ×3", _cheat_add_fish)

	# ── Kategori: Material & Eksplorasi ──
	_add_category_header(box, "⛏  MINING, MATERIAL & DUNIA")
	_add_cheat_row(box, "F5", "Spawn Semua Ore & Coal ×10", _cheat_add_ores)
	_add_cheat_row(box, "", "Spawn Semua Bar Batangan ×5", _cheat_add_bars)
	_add_cheat_row(box, "Ins", "Bahan Jembatan (+20 Wood, +10 Stone)", _cheat_add_bridge_materials)
	_add_cheat_row(box, "", "Buka Semua Area (Forest/Cave/School/Bridge)", _cheat_unlock_all_areas)

	# ── Kategori: Sistem ──
	_add_category_header(box, "⚙  SISTEM")
	_add_cheat_row(box, "F8", "Cetak Inventory ke Console", _cheat_print_inventory)
	_add_cheat_row(box, "F9", "Hapus Save File (Reset Total)", _cheat_delete_save)

	root_box.add_child(HSeparator.new())
	var hint := Label.new()
	hint.text = "Tekan F1 kapan saja untuk buka/tutup menu ini."
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	hint.add_theme_font_size_override("font_size", 12)
	root_box.add_child(hint)

func _add_category_header(parent: Control, title_text: String) -> void:
	var sep := HSeparator.new()
	sep.custom_minimum_size = Vector2(0, 4)
	parent.add_child(sep)
	var lbl := Label.new()
	lbl.text = title_text
	lbl.add_theme_color_override("font_color", Color(1.0, 0.75, 0.3))
	lbl.add_theme_font_size_override("font_size", 13)
	parent.add_child(lbl)

func _add_cheat_row(parent: Control, shortcut_key: String, description: String, callback: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var key_lbl := Label.new()
	key_lbl.text = ("[%s]" % shortcut_key) if not shortcut_key.is_empty() else "    "
	key_lbl.custom_minimum_size = Vector2(48, 0)
	key_lbl.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0) if not shortcut_key.is_empty() else Color(0.3, 0.3, 0.3))
	row.add_child(key_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = description
	desc_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.85))
	desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(desc_lbl)

	var btn := Button.new()
	btn.text = "▶"
	btn.custom_minimum_size = Vector2(26, 20)
	btn.pressed.connect(callback)
	row.add_child(btn)

	parent.add_child(row)

func _toggle_panel() -> void:
	if is_instance_valid(_panel):
		_panel.visible = not _panel.visible

## ── Cheat Functions ───────────────────────────────────────────────────────────

# --- Pemain & Keuangan ---
func _cheat_add_gold(amount: int) -> void:
	GameState.add_money(amount)
	_notify("💰 +%s Gold  (Total: %s G)" % [_format_money(amount), _format_money(GameState.money)])

func _cheat_fill_stamina() -> void:
	GameState.stamina = GameState.MAX_STAMINA
	GameState.stamina_changed.emit(GameState.stamina, GameState.MAX_STAMINA)
	_notify("⚡ Stamina penuh!")

func _cheat_toggle_god_mode() -> void:
	_god_mode = not _god_mode
	if _god_mode:
		_notify("🛡  God Mode ON — Stamina tidak akan pernah berkurang.")
	else:
		_notify("🛡  God Mode OFF.")

func _cheat_toggle_speed_boost() -> void:
	_speed_boost = not _speed_boost
	var target_speed := 75.0 if _speed_boost else 30.0
	var players = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		var p = get_tree().current_scene.find_child("Player", true, false)
		if p is Player:
			p.speed = target_speed
	else:
		for p in players:
			if p is Player:
				p.speed = target_speed
	_notify("👟 Speed Boost: %s (%d speed)" % ["ON" if _speed_boost else "OFF", int(target_speed)])

func _cheat_upgrade_bag() -> void:
	if GameState.bag_level >= GameState.BAG_SIZES.size() - 1:
		_notify("👜 Tas sudah level maksimal (%d slot)." % GameState.bag_size)
		return
	GameState.bag_level += 1
	GameState.bag_upgraded.emit(GameState.bag_size)
	GameState.inventory_changed.emit()
	_notify("👜 Tas di-upgrade → %d slot" % GameState.bag_size)

func _cheat_upgrade_tools() -> void:
	var max_tier = ToolUpgradeManager.TIERS.back()
	var upgraded_count = 0
	
	for i in range(GameState.bag_size):
		var slot = GameState.inventory[i]
		if slot != null and slot["item"] != null:
			var item: ItemData = slot["item"]
			if item.is_tool():
				var parsed := ToolUpgradeManager._parse_tool(item.item_id)
				var new_tool_id := ""
				if not parsed.is_empty():
					new_tool_id = "%s_%s" % [parsed["type"], max_tier]
				else:
					var last_underscore = item.item_id.rfind("_")
					var tool_type = item.item_id.substr(0, last_underscore) if last_underscore != -1 else item.item_id
					new_tool_id = tool_type + "_" + max_tier
				
				var new_item: ItemData = GameState._resolve_item(new_tool_id)
				if new_item != null:
					GameState.inventory[i]["item"] = new_item
					upgraded_count += 1
				else:
					push_warning("[DEBUG] Gagal resolve tool upgrade: %s" % new_tool_id)
	
	if upgraded_count > 0:
		GameState.inventory_changed.emit()
		_notify("⚒ Semua %d tool di-upgrade ke tier %s!" % [upgraded_count, max_tier.capitalize()])
	else:
		_notify("⚒ Tidak ada tool di inventory untuk di-upgrade.")

# --- Waktu & Musim ---
## Tiap klik: 1 set tier berikutnya (Wood -> Obsidian, lalu ulang).
func _cheat_add_equipment_set() -> void:
	var tiers := ["wood", "copper", "iron", "gold", "platinum", "crimson", "frost", "shadow", "fairy", "obsidian"]
	var tier: String = tiers[_equipment_tier]
	_equipment_tier = (_equipment_tier + 1) % tiers.size()
	for kind in ["sword", "bow", "staff", "helmet", "armor", "leggings", "boots"]:
		GameState.add_item("%s_%s" % [kind, tier], 1)
	GameState.add_item("arrow_%s" % tier, 20)
	_notify("⚔  Set senjata & armor tier %s masuk tas" % tier.capitalize())

func _cheat_next_day() -> void:
	DayCycle.advance_day()
	_notify("📅 Hari %d dimulai (%s)" % [DayCycle.current_day, DayCycle.get_season_display_name() if DayCycle.has_method("get_season_display_name") else ""])

func _cheat_advance_hours(hours: int = 2) -> void:
	DayCycle.advance_minute(hours * 60)
	_notify("⏰ Waktu maju %d jam (Sekarang %02d:%02d)" % [hours, DayCycle.hour, DayCycle.minute])

func _cheat_next_season() -> void:
	var days_per_season := DayCycle.DAYS_PER_SEASON if "DAYS_PER_SEASON" in DayCycle else 28
	var current_season_day := (DayCycle.current_day - 1) % days_per_season
	var remaining := days_per_season - current_season_day
	for i in range(remaining):
		DayCycle.advance_day()
	var sname := DayCycle.get_season_display_name() if DayCycle.has_method("get_season_display_name") else ""
	_notify("🌸 Pindah Musim → %s (Hari %d)" % [sname, DayCycle.current_day])

# --- Pertanian & Kebun ---
func _cheat_add_current_season_seeds(amount: int = 10) -> void:
	var season: String = DayCycle.get_current_season() if DayCycle.has_method("get_current_season") else "spring"
	var seeds := []
	match season:
		"spring":
			seeds = ["seed_strawberry", "seed_carrot", "seed_potato", "seed_parsnip", "seed_cabbage", "seed_cauliflower", "seed_leek", "seed_garlic", "seed_pea"]
		"summer":
			seeds = ["seed_tomato", "seed_chili", "seed_corn", "seed_blueberry", "seed_melon", "seed_watermelon", "seed_pineapple", "seed_cucumber"]
		"fall":
			seeds = ["seed_pumpkin", "seed_eggplant", "seed_grape", "seed_wheat", "seed_apple", "seed_beet", "seed_broccoli"]
		_:
			seeds = ["seed_strawberry", "seed_carrot", "seed_potato"]

	for s in seeds:
		GameState.add_item(s, amount)
	_notify("🌱 +%d Benih Musim %s (%d jenis)" % [amount, season.capitalize(), seeds.size()])

func _cheat_add_all_seeds(amount: int = 5) -> void:
	var all_seeds := [
		"seed_cherry", "seed_apricot", "seed_strawberry", "seed_leek", "seed_potato", "seed_onion", "seed_carrot",
		"seed_blueberry", "seed_parsnip", "seed_cabbage", "seed_cauliflower", "seed_rice", "seed_broccoli", "seed_rhubarb",
		"seed_banana", "seed_orange", "seed_mango", "seed_peach", "seed_tomato", "seed_sunflower", "seed_chili",
		"seed_green_apple", "seed_red_pepper", "seed_yellow_pepper", "seed_melon", "seed_watermelon", "seed_cucumber",
		"seed_pineapple", "seed_pea", "seed_garlic", "seed_blackberry", "seed_wheat", "seed_apple", "seed_beet",
		"seed_pumpkin", "seed_grape", "seed_corn", "seed_eggplant", "seed_zucchini"
	]
	for s in all_seeds:
		GameState.add_item(s, amount)
	_notify("🌱 +%d Semua 39 Jenis Benih!" % amount)

func _cheat_add_all_crops(amount: int = 5) -> void:
	var sample_crops := [
		"strawberry", "carrot", "potato", "cabbage", "cauliflower",
		"tomato", "chili", "corn", "melon", "watermelon", "pineapple",
		"pumpkin", "eggplant", "grape", "wheat", "apple", "banana", "mango"
	]
	for c in sample_crops:
		GameState.add_item(c, amount)
	_notify("🧺 +%d Berbagai Hasil Panen / Crops (%d jenis)" % [amount, sample_crops.size()])

func _cheat_water_all_crops() -> void:
	if not FarmManager:
		return
	var count := 0
	for cell in FarmManager.farm_data.keys():
		if FarmManager.water(cell):
			count += 1
	_notify("💧 %d petak tanah berhasil disiram!" % count)

func _cheat_instant_grow_crops() -> void:
	if not FarmManager:
		return
	var count := 0
	for cell in FarmManager.farm_data.keys():
		var data: Dictionary = FarmManager.farm_data[cell]
		if data.get("crop") != null:
			var crop: CropData = data["crop"]
			var max_stage = crop.get_total_stages() - 1
			data["stage"] = max_stage
			data["days_in_stage"] = 0
			if is_instance_valid(FarmManager.crop_layer):
				FarmManager._update_crop_tile(cell, crop, max_stage)
			count += 1
	if count > 0:
		_notify("🌾 %d tanaman langsung matang & siap panen!" % count)
	else:
		_notify("🌾 Tidak ada tanaman yang tertanam di kebun.")

# --- Memancing ---
func _cheat_toggle_instant_bite() -> void:
	if FishingManager:
		FishingManager.debug_instant_bite = not FishingManager.debug_instant_bite
		_notify("🎣 Gigit Instan: %s" % ("ON" if FishingManager.debug_instant_bite else "OFF"))

func _cheat_toggle_auto_win() -> void:
	if FishingManager:
		FishingManager.debug_auto_win = not FishingManager.debug_auto_win
		_notify("🏆 Auto-Menang Mancing: %s" % ("ON" if FishingManager.debug_auto_win else "OFF"))

func _cheat_add_fish(amount: int = 3) -> void:
	var fishes := [
		"fish_carp", "fish_salmon", "fish_tuna", "fish_pufferfish", 
		"fish_golden_fish", "fish_crab", "fish_squid", "fish_gurame", "fish_lele"
	]
	for f in fishes:
		GameState.add_item(f, amount)
	_notify("🐟 +%d Berbagai Ikan & Biota Laut (%d jenis)" % [amount, fishes.size()])

# --- Material & Eksplorasi ---
func _cheat_add_ores(amount: int = 10) -> void:
	var ores := ["copper_ore", "iron_ore", "gold_ore", "platinum_ore", "coal"]
	for ore in ores:
		GameState.add_item(ore, amount)
	_notify("⛏  +%d Copper, Iron, Gold, Platinum Ore & Coal" % amount)

func _cheat_add_bars(amount: int = 5) -> void:
	var bars := ["copper_bar", "iron_bar", "gold_bar", "platinum_bar", "obsidian_bar"]
	for bar in bars:
		GameState.add_item(bar, amount)
	_notify("🔥 +%d Copper, Iron, Gold, Platinum, Obsidian Bar" % amount)

func _cheat_add_bridge_materials() -> void:
	GameState.add_item("wood", 20)
	GameState.add_item("stone", 10)
	_notify("🌉 +20 Wood & +10 Stone (cukup untuk perbaiki jembatan)")

func _cheat_unlock_all_areas() -> void:
	if UnlockManager:
		for area in UnlockManager.DEFAULT_UNLOCKS.keys():
			UnlockManager.unlock(area)
	if WorldState:
		WorldState.set_flag("bridge_repaired", true)
		WorldState.set_flag("school_open", true)
	_notify("🗺 Semua area & jembatan berhasil dibuka!")

# --- Sistem ---
func _cheat_print_inventory() -> void:
	print("\n══════════════ INVENTORY DEBUG ══════════════")
	print("Bag Level : %d  |  Bag Size : %d" % [GameState.bag_level, GameState.bag_size])
	print("Money     : %d G" % GameState.money)
	print("Stamina   : %d / %d" % [GameState.stamina, GameState.MAX_STAMINA])
	print("Day       : %d (%s)  |  Time : %02d:%02d" % [
		DayCycle.current_day,
		DayCycle.get_season_display_name() if DayCycle.has_method("get_season_display_name") else "",
		DayCycle.hour,
		DayCycle.minute
	])
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
	_notify("🗑  Save slot %d dihapus. Restart game untuk new game." % SaveManager.current_slot)

func _delete_save_fallback() -> void:
	var path := "user://nusa_vale_save.json"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
		print("[DEBUG] Save file dihapus: %s" % path)
	else:
		print("[DEBUG] Tidak ada save file ditemukan.")

func _notify(msg: String) -> void:
	print("[DEBUG] %s" % msg)
	if Notify:
		Notify.say("[DEBUG] " + msg)

func _format_money(amount: int) -> String:
	var s := str(amount)
	var formatted := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			formatted = "." + formatted
		formatted = s[i] + formatted
		count += 1
	return formatted
