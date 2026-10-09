## FishingDebug — Autoload khusus cheat/debug memancing
##
## CARA HAPUS SAAT RELEASE:
##   1. Project Settings -> Globals -> Autoload: hapus entri "FishingDebug"
##      (atau beri ENABLED = false di bawah, tanpa menghapus apa pun).
##   2. Hapus file ini.
##   Tidak ada kode game yang bergantung pada autoload ini. Flag cheat-nya
##   disimpan di FishingManager (debug_*) dan nilai bawaannya false, jadi tanpa
##   file ini fitur memancing tetap berjalan normal.
##   Cari semua titik yang membaca flag dengan Ctrl+Shift+F: "debug_"
##
## SHORTCUT (aktif saat game berjalan):
##   Home      -> Ikan langsung menggigit (dan gigitan tidak kabur)
##   End       -> Auto-menang mini game (ikan pasti tertangkap)
##   Page Up   -> Paksa tier ikan (siklus: Normal -> Umum -> ... -> Legendaris)
##   Page Down -> Matikan semua cheat memancing

extends CanvasLayer

const ENABLED := true # Ganti ke false untuk mematikan semua tanpa menghapus kode

var _label: Label

func _ready() -> void:
	if not ENABLED:
		set_process_unhandled_input(false)
		return
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_label()
	print("[FISH DEBUG] Aktif. Home / End / PageUp / PageDown.")

func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return

	match key.physical_keycode:
		KEY_HOME:
			FishingManager.debug_instant_bite = not FishingManager.debug_instant_bite
			_announce("Gigit instan: %s" % _on_off(FishingManager.debug_instant_bite))
		KEY_END:
			FishingManager.debug_auto_win = not FishingManager.debug_auto_win
			_announce("Auto-menang mini game: %s" % _on_off(FishingManager.debug_auto_win))
		KEY_PAGEUP:
			FishingManager.debug_force_tier += 1
			if FishingManager.debug_force_tier > 4:
				FishingManager.debug_force_tier = -1
			#_announce("Tier ikan: %s" % _tier_label())
		KEY_PAGEDOWN:
			FishingManager.debug_instant_bite = false
			FishingManager.debug_auto_win = false
			FishingManager.debug_force_tier = -1
			_announce("Semua cheat memancing dimatikan")
		_:
			return

	get_viewport().set_input_as_handled()

# --- Helper ---

func _announce(message: String) -> void:
	Notify.say("[FISH DEBUG] " + message)
	_refresh()

func _on_off(value: bool) -> String:
	return "ON" if value else "OFF"

#func _tier_label() -> String:
	#if FishingManager.debug_force_tier < 0:
		#return "Normal"
	#return FishTiers.get_tier(FishingManager.debug_force_tier)["name"]

# --- Label status di pojok kanan atas (muncul hanya bila ada cheat aktif) ---

func _build_label() -> void:
	_label = Label.new()
	_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_label.offset_left = -8.0
	_label.offset_right = -8.0
	_label.offset_top = 8.0
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
	_label.visible = false
	add_child(_label)

func _refresh() -> void:
	if _label == null:
		return
	var parts: PackedStringArray = []
	if FishingManager.debug_instant_bite:
		parts.append("Gigit instan")
	if FishingManager.debug_auto_win:
		parts.append("Auto-menang")
	#if FishingManager.debug_force_tier >= 0:
		#parts.append("Tier: %s" % _tier_label())
	_label.visible = not parts.is_empty()
	_label.text = "FISH DEBUG: " + " | ".join(parts)
