class_name SaveSlotMenu
extends CanvasLayer

signal slot_chosen(slot: int)
signal closed
enum Mode { NEW_GAME, LOAD, SAVE, PLAY }

@export var design_size := Vector2(1280, 720)
@export var card_scene: PackedScene = preload("res://scenes/ui/save_slot_card.tscn")
@export var titles := PackedStringArray(["Game Baru · Pilih Slot", "Muat Permainan", "Simpan Permainan", "Co-op · Pilih Slot"])
var mode: Mode = Mode.LOAD
var confirm_load := false
var show_active := false
var _confirm_action: Callable
var _closed := false
@onready var _list: GridContainer = %Slots
@onready var _confirm_layer: Control = %Confirmation
@onready var _confirm_label: Label = %ConfirmText
@onready var _confirm_yes: Button = %ConfirmYes
@onready var _confirm_no: Button = %ConfirmNo

func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	%Title.text = titles[int(mode)] if int(mode) < titles.size() else "Slot Save"
	%Close.pressed.connect(_close)
	_confirm_yes.pressed.connect(_on_confirm_yes)
	_confirm_no.pressed.connect(_hide_confirm)
	get_viewport().size_changed.connect(_resize)
	_resize()
	_refresh()

func _resize() -> void:
	var view := get_viewport().get_visible_rect().size
	var fit := minf(view.x / design_size.x, view.y / design_size.y)
	$Design.scale = Vector2.ONE * fit
	$Design.position = (view - design_size * fit) * 0.5

func _refresh() -> void:
	if _closed:
		return
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var first: Button
	for slot in range(1, SaveManager.SLOT_COUNT + 1):
		var summary := SaveManager.get_slot_summary(slot)
		var filled := not summary.is_empty()
		var card := card_scene.instantiate()
		_list.add_child(card)
		card.get_node("Header").text = "SLOT %02d" % slot
		card.get_node("Active").visible = show_active and slot == SaveManager.current_slot
		card.get_node("PlayerName").text = str(summary.get("name", "Cerita baru"))
		card.get_node("FarmName").text = str(summary.get("farm_name", "")) if filled else "Mulai kehidupan di Nusa Vale"
		if filled:
			card.get_node("Date").text = "%s · Hari %d\nTahun %d" % [summary.season_name, summary.day_of_season, summary.year]
			card.get_node("Money").text = "%s G" % _format_money(int(summary.money))
			card.get_node("Saved").text = "Disimpan %s%s" % [_format_time(int(summary.saved_at)), "\nDipulihkan dari cadangan" if summary.from_backup else ""]
		else:
			card.get_node("Date").text = "Slot kosong"
			card.get_node("Money").text = "Petualangan menantimu"
			card.get_node("Saved").text = "Belum ada data tersimpan"
		var action: Button = card.get_node("Action")
		action.text = _action_text(filled)
		action.disabled = mode == Mode.LOAD and not filled
		action.set_meta("available", not action.disabled)
		action.pressed.connect(_on_slot_pressed.bind(slot, filled))
		var remove: Button = card.get_node("Delete")
		remove.visible = filled
		remove.set_meta("available", filled)
		remove.pressed.connect(_on_delete_pressed.bind(slot))
		if first == null and not action.disabled:
			first = action
	if first != null:
		_focus_action.call_deferred(first)

func _focus_action(button: Button) -> void:
	if _closed or _confirm_layer.visible or not is_instance_valid(button):
		return
	if button.is_inside_tree() and not button.disabled:
		button.grab_focus()

func _set_card_actions_disabled(value: bool) -> void:
	%Close.disabled = value
	for card in _list.get_children():
		for button_name in ["Action", "Delete"]:
			var button: Button = card.get_node(button_name)
			button.disabled = value or not button.get_meta("available", false)

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

func _on_slot_pressed(slot: int, _filled: bool) -> void:
	if _closed or _confirm_layer.visible or slot < 1 or slot > SaveManager.SLOT_COUNT:
		return
	var filled := SaveManager.has_save(slot)
	if mode == Mode.LOAD and not filled:
		return
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
	_set_card_actions_disabled(true)
	_confirm_no.grab_focus()

func _hide_confirm() -> void:
	_confirm_layer.hide()
	_confirm_action = Callable()
	%Close.disabled = false
	_refresh()

func _on_confirm_yes() -> void:
	var action := _confirm_action
	_confirm_layer.hide()
	_confirm_action = Callable()
	_set_card_actions_disabled(false)
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
	if _closed:
		return
	_closed = true
	hide()
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
