class_name SaveSlotMenu
extends CanvasLayer

## Menu slot save, dibangun lewat kode (pola sama dengan CharacterCreatorUI).
## Menampilkan SaveManager.SLOT_COUNT slot dengan ringkasan (nama, musim/hari, uang, waktu simpan)
## dan aksi sesuai `mode`. Setiap slot terisi punya tombol Hapus (pakai konfirmasi).
##   NEW_GAME : pilih slot untuk game baru; slot terisi minta konfirmasi timpa.
##   LOAD     : pilih slot terisi untuk dimuat.
##   SAVE     : simpan game ke slot (dikerjakan menu ini sendiri); slot lain yang terisi minta konfirmasi.
##   PLAY     : co-op; slot kosong = game baru, slot terisi = lanjutkan.
## Untuk NEW_GAME/LOAD/PLAY pemanggil yang memuat/memulai game lewat sinyal slot_chosen.

signal slot_chosen(slot: int)
signal closed

enum Mode { NEW_GAME, LOAD, SAVE, PLAY }

const FONT := preload("res://resources/ui/readable_font.tres")
const TEX_INVENTORY := preload("res://assets/farm_rpg/ui/inventory/inventory.png")
const TEX_BANNER := preload("res://assets/farm_rpg/ui/inventory/Banner.png")

const COLOR_TEXT := Color(0.36, 0.2, 0.15)
const COLOR_TEXT_LIGHT := Color(0.97, 0.88, 0.78)
const COLOR_DIM := Color(0.97, 0.88, 0.78, 0.55)

const TITLES := {
	Mode.NEW_GAME: "Game Baru: Pilih Slot",
	Mode.LOAD: "Muat Game",
	Mode.SAVE: "Simpan Game",
	Mode.PLAY: "Co-op: Pilih Slot",
}

var mode: Mode = Mode.LOAD
## Minta konfirmasi sebelum memuat (dari menu pause: progres yang belum disimpan hilang).
var confirm_load: bool = false
## Tandai slot aktif dengan "(aktif)" (dipakai saat di dalam game).
var show_active: bool = false

var _theme: Theme
var _list: VBoxContainer
var _confirm_layer: Control
var _confirm_label: Label
var _confirm_yes: Button
var _confirm_no: Button
var _confirm_action: Callable


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_refresh()


# ── Membangun UI ────────────────────────────────────────────────────

func _build_ui() -> void:
	_theme = Theme.new()
	_theme.default_font = FONT
	_theme.default_font_size = 16
	_theme.set_color("font_color", "Label", COLOR_TEXT)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.theme = _theme
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	dim.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(TEX_INVENTORY, Rect2(0, 64, 48, 48), 8, 12))
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)

	var title := Label.new()
	title.text = TITLES.get(mode, "Slot Save")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 4)
	box.add_child(_list)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	box.add_child(buttons)
	buttons.add_child(_make_button("Kembali", _close))

	_build_confirm(dim)

func _build_confirm(parent: Control) -> void:
	_confirm_layer = ColorRect.new()
	(_confirm_layer as ColorRect).color = Color(0, 0, 0, 0.45)
	parent.add_child(_confirm_layer)
	_confirm_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirm_layer.hide()

	var center := CenterContainer.new()
	_confirm_layer.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(TEX_INVENTORY, Rect2(0, 64, 48, 48), 8, 12))
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	_confirm_label = Label.new()
	_confirm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirm_label.custom_minimum_size = Vector2(260, 0)
	_confirm_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_confirm_label)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 10)
	box.add_child(buttons)
	_confirm_no = _make_button("Batal", _hide_confirm)
	_confirm_yes = _make_button("Ya", _on_confirm_yes)
	buttons.add_child(_confirm_no)
	buttons.add_child(_confirm_yes)

func _make_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	return button

func _style(tex: Texture2D, region: Rect2, tex_margin: int, content_margin: int) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.region_rect = region
	sb.set_texture_margin_all(tex_margin)
	sb.set_content_margin_all(content_margin)
	return sb


# ── Daftar slot ─────────────────────────────────────────────────────

func _refresh() -> void:
	for child in _list.get_children():
		child.queue_free()
	var first_focus: Button = null
	for slot in range(1, SaveManager.SLOT_COUNT + 1):
		var action := _build_slot_row(slot)
		if first_focus == null and not action.disabled:
			first_focus = action
	if first_focus != null:
		first_focus.call_deferred("grab_focus")

## Mengembalikan tombol aksi slot (untuk fokus keyboard/gamepad).
func _build_slot_row(slot: int) -> Button:
	var summary := SaveManager.get_slot_summary(slot)
	var filled := not summary.is_empty()

	var row_panel := PanelContainer.new()
	row_panel.add_theme_stylebox_override("panel", _style(TEX_INVENTORY, Rect2(7, 9, 18, 18), 4, 6))
	_list.add_child(row_panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row_panel.add_child(row)

	var info := VBoxContainer.new()
	info.custom_minimum_size = Vector2(300, 0)
	# Teks terang di atas kotak slot yang gelap.
	info.theme = Theme.new()
	info.theme.set_color("font_color", "Label", COLOR_TEXT_LIGHT)
	info.add_theme_constant_override("separation", 0)
	row.add_child(info)

	var header := Label.new()
	header.text = "Slot %d" % slot
	if show_active and slot == SaveManager.current_slot:
		header.text += " (aktif)"
	info.add_child(header)

	if filled:
		info.add_child(_line("%s  ·  %s hari %d, Tahun %d" % [
			summary["name"], summary["season_name"], summary["day_of_season"], summary["year"]]))
		var saved := "Disimpan %s" % _format_time(int(summary["saved_at"]))
		if summary["from_backup"]:
			saved += " (cadangan)"
		info.add_child(_line("%s G  ·  %s" % [_format_money(int(summary["money"])), saved]))
	else:
		var empty := _line("Kosong")
		empty.add_theme_color_override("font_color", COLOR_DIM)
		info.add_child(empty)

	var buttons := VBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 2)
	row.add_child(buttons)

	var action := _make_button(_action_text(filled), _on_slot_pressed.bind(slot, filled))
	action.custom_minimum_size = Vector2(64, 0)
	action.disabled = mode == Mode.LOAD and not filled
	buttons.add_child(action)

	if filled:
		var delete_button := _make_button("Hapus", _on_delete_pressed.bind(slot))
		delete_button.custom_minimum_size = Vector2(64, 0)
		buttons.add_child(delete_button)
	return action

func _line(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label

func _action_text(filled: bool) -> String:
	match mode:
		Mode.NEW_GAME:
			return "Mulai"
		Mode.SAVE:
			return "Simpan"
		Mode.PLAY:
			return "Lanjut" if filled else "Mulai"
	return "Muat"


# ── Aksi ────────────────────────────────────────────────────────────

func _on_slot_pressed(slot: int, filled: bool) -> void:
	match mode:
		Mode.NEW_GAME:
			if filled:
				_ask("Timpa save di Slot %d dengan game baru?\nProgres di slot ini akan hilang." % slot, _choose.bind(slot))
			else:
				_choose(slot)
		Mode.LOAD:
			if confirm_load:
				_ask("Muat Slot %d?\nProgres yang belum disimpan akan hilang." % slot, _choose.bind(slot))
			else:
				_choose(slot)
		Mode.SAVE:
			if filled and slot != SaveManager.current_slot:
				_ask("Timpa save di Slot %d?" % slot, _save_to.bind(slot))
			else:
				_save_to(slot)
		Mode.PLAY:
			_choose(slot)

func _on_delete_pressed(slot: int) -> void:
	_ask("Hapus save di Slot %d?\nTidak bisa dibatalkan." % slot, _delete.bind(slot))

func _choose(slot: int) -> void:
	SaveManager.select_slot(slot)
	slot_chosen.emit(slot)
	_close()

func _save_to(slot: int) -> void:
	var previous := SaveManager.current_slot
	SaveManager.select_slot(slot)
	if SaveManager.save_game():
		Notify.say("Game tersimpan di Slot %d." % slot)
		slot_chosen.emit(slot)
		_close()
	else:
		SaveManager.select_slot(previous)
		Notify.say("Gagal menyimpan ke Slot %d." % slot)
		_refresh()

func _delete(slot: int) -> void:
	if SaveManager.delete_slot(slot):
		Notify.say("Save Slot %d dihapus." % slot)
	else:
		Notify.say("Gagal menghapus save Slot %d." % slot)
	_refresh()


# ── Konfirmasi ──────────────────────────────────────────────────────

func _ask(text: String, action: Callable) -> void:
	_confirm_label.text = text
	_confirm_action = action
	_confirm_layer.show()
	_confirm_no.grab_focus()

func _hide_confirm() -> void:
	_confirm_layer.hide()
	_confirm_action = Callable()
	_refresh()

func _on_confirm_yes() -> void:
	var action := _confirm_action
	_confirm_layer.hide()
	_confirm_action = Callable()
	if action.is_valid():
		action.call()


# ── Input / tutup ───────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if not Coop.is_p1_event(event):
		return
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		get_viewport().set_input_as_handled()
		if _confirm_layer.visible:
			_hide_confirm()
		else:
			_close()

func _close() -> void:
	closed.emit()
	queue_free()


# ── Format ──────────────────────────────────────────────────────────

## 1234567 -> "1.234.567"
static func _format_money(value: int) -> String:
	var digits := str(absi(value))
	var out := ""
	while digits.length() > 3:
		out = "." + digits.substr(digits.length() - 3) + out
		digits = digits.substr(0, digits.length() - 3)
	return digits + out

## Unix (UTC) -> "11/10/2026 22:30" waktu lokal.
static func _format_time(unix_time: int) -> String:
	if unix_time <= 0:
		return "-"
	var bias_minutes: int = int(Time.get_time_zone_from_system().get("bias", 0))
	var t := Time.get_datetime_dict_from_unix_time(unix_time + bias_minutes * 60)
	return "%02d/%02d/%d %02d:%02d" % [t.day, t.month, t.year, t.hour, t.minute]
