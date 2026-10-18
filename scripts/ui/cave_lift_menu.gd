extends CanvasLayer

## Menu lift gua: pilih lobi atau lantai checkpoint yang sudah terbuka (GDD 9).
## Mouse: klik tujuan. Keyboard/gamepad: atas/bawah memilih, terima = berangkat, batal = tutup.

const ServiceTheme = preload("res://scripts/ui/farm_service_theme.gd")
const FONT := preload("res://resources/ui/readable_font.tres")

var cave: Node
var player: Player
var _buttons: Array[Button] = []
var _floors: Array[int] = []
var _index := 0
var _closed := false

func _ready() -> void:
	layer = ServiceTheme.LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.theme = ServiceTheme.make_theme()
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	dim.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	var title := Label.new()
	title.text = "Lift Gua"
	title.add_theme_font_override("font", FONT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var current: int = cave.floor_number if cave != null else 0
	for floor_number in GameState.cave.lift_floors():
		var button := Button.new()
		button.text = "Lobi Gua" if floor_number == 0 else "Lantai %d" % floor_number
		button.custom_minimum_size = Vector2(120, 0)
		button.disabled = floor_number == current
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_choose.bind(floor_number))
		box.add_child(button)
		_buttons.append(button)
		_floors.append(floor_number)
	var close := Button.new()
	close.text = "Tutup"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(close_menu)
	box.add_child(close)
	_buttons.append(close)
	_floors.append(-1)
	if _floors.size() <= 2:
		var hint := Label.new()
		hint.text = "Lift terbuka tiap %d lantai." % CaveManager.DATA.lift_interval
		hint.add_theme_font_override("font", FONT)
		box.add_child(hint)
	Coop.set_menu_open(player, true)
	_index = _first_enabled()
	_highlight()

func _first_enabled() -> int:
	for i in _buttons.size():
		if not _buttons[i].disabled:
			return i
	return _buttons.size() - 1

func _highlight() -> void:
	for i in _buttons.size():
		_buttons[i].modulate = Color(1.25, 1.2, 0.8) if i == _index else Color.WHITE

func _owner_input() -> PlayerInput:
	return player.input if is_instance_valid(player) else PlayerInput.solo()

func _process(_delta: float) -> void:
	var input := _owner_input()
	var step := 0
	if input.just_pressed(&"move_down"):
		step = 1
	elif input.just_pressed(&"move_up"):
		step = -1
	if step == 0:
		return
	for i in _buttons.size():
		_index = wrapi(_index + step, 0, _buttons.size())
		if not _buttons[_index].disabled:
			break
	_highlight()

func _input(event: InputEvent) -> void:
	var input := _owner_input()
	if input.is_event(event, &"ui_cancel"):
		close_menu()
		get_viewport().set_input_as_handled()
	elif input.is_event(event, &"ui_accept") or input.is_event(event, &"interact"):
		if event is InputEventMouseButton:
			return
		get_viewport().set_input_as_handled()
		if _floors[_index] < 0:
			close_menu()
		elif not _buttons[_index].disabled:
			_choose(_floors[_index])

func _choose(floor_number: int) -> void:
	close_menu()
	if cave != null and is_instance_valid(cave):
		cave.go_to_floor(floor_number)

func close_menu() -> void:
	if _closed:
		return
	_closed = true
	hide()
	set_process_input(false)
	set_process(false)
	Coop.set_menu_open(player, false)
	queue_free()

func _exit_tree() -> void:
	if not _closed:
		Coop.set_menu_open(player, false)
