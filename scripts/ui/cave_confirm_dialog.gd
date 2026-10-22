extends ConfirmationDialog

## Konfirmasi singkat di gua (naik ke lobi, keluar gua), bergaya sama dengan dialog tas.
## Pakai CaveConfirm.ask(...) lewat preload; game dijeda (solo) atau pemain dikunci (co-op) selama terbuka.

const DropItemDialogScript = preload("res://scripts/ui/drop_item_dialog.gd")

var _player: Player
var _on_yes: Callable
var _closing := false
## Frame saat dialog dibuka: tombol yang membukanya tidak boleh langsung menjawabnya.
var _opened_frame := 0

static func ask(player: Player, title_text: String, body: String, yes_text: String, on_yes: Callable) -> void:
	var dialog = load("res://scripts/ui/cave_confirm_dialog.gd").new()
	dialog._player = player
	dialog._on_yes = on_yes
	dialog.title = title_text
	dialog.dialog_text = body
	dialog.ok_button_text = yes_text
	dialog.cancel_button_text = "Batal"
	var parent := Coop.ui_parent(player)
	parent.add_child(dialog)
	# Saat jendela dialog belum memegang fokus, tombol gamepad/keyboard berhenti di viewport
	# induk; penjaga ini meneruskannya ke dialog.
	var guard := InputRelay.new()
	guard.dialog = dialog
	parent.add_child(guard)
	dialog.tree_exiting.connect(guard.queue_free)
	dialog.popup_centered()
	dialog.get_ok_button().grab_focus()

func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	exclusive = true
	theme = _make_theme()
	confirmed.connect(_finish.bind(true))
	canceled.connect(_finish.bind(false))

func _ready() -> void:
	_opened_frame = Engine.get_process_frames()
	Coop.set_menu_open(_player, true)

## Jawab langsung dengan tombol pemain: A / Enter / E = ya, B / Esc = batal. Tidak bergantung
## pada fokus tombol GUI, yang bisa hilang saat dialog dibuka dari klik mouse atau gamepad.
func _input(event: InputEvent) -> void:
	if _closing or not event.is_pressed() or event.is_echo():
		return
	if Engine.get_process_frames() <= _opened_frame + 1:
		return
	if is_instance_valid(_player) and not Coop.accepts_event(_player, event):
		return
	if _is(event, &"ui_cancel"):
		set_input_as_handled()
		_finish(false)
	elif _is(event, &"ui_accept") or _is(event, &"interact"):
		# Tombol Batal yang sedang difokus tetap berarti batal.
		var cancel_focused := get_cancel_button().has_focus()
		set_input_as_handled()
		_finish(not cancel_focused)

func _is(event: InputEvent, action: StringName) -> bool:
	if is_instance_valid(_player) and _player.input != null and _player.input.is_event(event, action):
		return true
	return InputMap.has_action(action) and event.is_action_pressed(action)

func _finish(accepted: bool) -> void:
	if _closing:
		return
	_closing = true
	hide()
	Coop.set_menu_open(_player, false)
	# Langsung, bukan deferred: langkah fisika berikutnya bisa saja mengunci pemain sesaat
	# (mis. tombol yang masih ditekan) sehingga use_object menolak pindah lantai.
	if accepted and _on_yes.is_valid():
		_on_yes.call()
	queue_free()

static func _style(bg: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = Color(0.9, 0.7, 0.3, 1.0)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	sb.content_margin_bottom = 1
	return sb

static func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = DropItemDialogScript.FONT
	t.default_font_size = 18
	t.set_color("font_color", "Label", DropItemDialogScript.COLOR_TEXT)
	t.set_color("title_color", "Window", Color("3b2825"))
	var panel := _style(Color("3b2825"))
	panel.set_content_margin_all(14)
	t.set_stylebox("panel", "AcceptDialog", panel)
	t.set_stylebox("embedded_border", "Window", panel)
	for state in ["normal", "hover", "pressed", "focus"]:
		t.set_stylebox(state, "Button", _style(Color("65432d") if state == "normal" else Color("906331")))
	t.set_color("font_color", "Button", DropItemDialogScript.COLOR_TEXT)
	return t

class InputRelay extends Node:
	var dialog: Node

	func _init() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS

	func _input(event: InputEvent) -> void:
		if is_instance_valid(dialog) and dialog.visible:
			dialog._input(event)
			if dialog._closing:
				get_viewport().set_input_as_handled()
