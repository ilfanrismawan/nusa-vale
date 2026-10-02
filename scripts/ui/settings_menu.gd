extends CanvasLayer
class_name SettingsMenu

@onready var dimmer: ColorRect = %Dimmer
@onready var window_mode_option: OptionButton = %WindowModeOption
@onready var resolution_option: OptionButton = %ResolutionOption
@onready var vsync_check: CheckBox = %VsyncCheck
@onready var master_slider: HSlider = %MasterSlider
@onready var master_label: Label = %MasterLabel
@onready var btn_close: Button = %BtnClose

const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(640, 360),
	Vector2i(1280, 720),
	Vector2i(1366, 768),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440)
]

func _ready() -> void:
	hide()
	_setup_ui()

func _setup_ui() -> void:
	# Window modes
	window_mode_option.clear()
	window_mode_option.add_item("Windowed", 0)
	window_mode_option.add_item("Fullscreen", 1)
	window_mode_option.add_item("Borderless", 2)
	window_mode_option.item_selected.connect(_on_window_mode_selected)

	# Resolutions
	resolution_option.clear()
	for res in RESOLUTIONS:
		var label := "%d x %d" % [res.x, res.y]
		if res.y == 360:
			label += " (360p)"
		elif res.y == 720:
			label += " (HD)"
		elif res.y == 1080:
			label += " (FHD)"
		elif res.y == 1440:
			label += " (2K)"
		resolution_option.add_item(label)
	resolution_option.item_selected.connect(_on_resolution_selected)

	# VSync
	vsync_check.toggled.connect(_on_vsync_toggled)

	# Master volume slider
	master_slider.min_value = 0.0
	master_slider.max_value = 1.0
	master_slider.step = 0.05
	var current_vol: float = db_to_linear(AudioServer.get_bus_volume_db(0))
	master_slider.value = current_vol
	_update_volume_label(current_vol)
	master_slider.value_changed.connect(_on_volume_changed)

	# Close button
	btn_close.pressed.connect(_close)

	_sync_current_settings()

func _sync_current_settings() -> void:
	var win = get_window()
	if win.mode == Window.MODE_FULLSCREEN:
		window_mode_option.select(1)
		resolution_option.disabled = true
	elif win.mode == Window.MODE_EXCLUSIVE_FULLSCREEN:
		window_mode_option.select(2)
		resolution_option.disabled = true
	else:
		window_mode_option.select(0)
		resolution_option.disabled = false

	var current_size = win.size
	for i in range(RESOLUTIONS.size()):
		if RESOLUTIONS[i].x == current_size.x and RESOLUTIONS[i].y == current_size.y:
			resolution_option.select(i)
			break

	var vsync_mode = DisplayServer.window_get_vsync_mode()
	vsync_check.button_pressed = (vsync_mode != DisplayServer.VSYNC_DISABLED)

func _on_window_mode_selected(index: int) -> void:
	print("[Settings] Mengubah mode layar ke: ", index)
	var win = get_window()
	match index:
		0: # Windowed
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			win.mode = Window.MODE_WINDOWED
			resolution_option.disabled = false
			var res_idx = resolution_option.selected
			if res_idx >= 0 and res_idx < RESOLUTIONS.size():
				_apply_resolution(RESOLUTIONS[res_idx])
			else:
				_apply_resolution(Vector2i(640, 360))
		1: # Fullscreen
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			win.mode = Window.MODE_FULLSCREEN
			resolution_option.disabled = true
		2: # Borderless Fullscreen
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
			win.mode = Window.MODE_EXCLUSIVE_FULLSCREEN
			resolution_option.disabled = true
	window_mode_option.select(index)

func _on_resolution_selected(index: int) -> void:
	if index >= 0 and index < RESOLUTIONS.size():
		_apply_resolution(RESOLUTIONS[index])

func _apply_resolution(new_size: Vector2i) -> void:
	print("[Settings] Mengubah resolusi ke: ", new_size)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(new_size)
	var screen_size = DisplayServer.screen_get_size()
	var center_pos = (screen_size - new_size) / 2
	DisplayServer.window_set_position(center_pos)
	
	var win = get_window()
	win.mode = Window.MODE_WINDOWED
	win.size = new_size
	win.position = center_pos
	window_mode_option.select(0)
	resolution_option.disabled = false

func _on_vsync_toggled(enabled: bool) -> void:
	if enabled:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

func _on_volume_changed(val: float) -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(val))
	_update_volume_label(val)

func _update_volume_label(val: float) -> void:
	master_label.text = "%d%%" % int(val * 100)

func toggle() -> void:
	if visible:
		_close()
	else:
		_open()

func _open() -> void:
	_sync_current_settings()
	show()

func _close() -> void:
	hide()

func _toggle_fullscreen() -> void:
	var cur = DisplayServer.window_get_mode()
	if cur == DisplayServer.WINDOW_MODE_FULLSCREEN or cur == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		_on_window_mode_selected(0)
	else:
		_on_window_mode_selected(1)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fullscreen") and not event.is_echo():
		_toggle_fullscreen()
		get_viewport().set_input_as_handled()
		return
	
	if event is InputEventKey and event.pressed and not event.echo:
		var key = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
		if key == KEY_F11 or (key == KEY_ENTER and event.alt_pressed):
			_toggle_fullscreen()
			get_viewport().set_input_as_handled()
			return
	
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		if not visible:
			var inventory_node = get_parent().get_node_or_null("UIInventory")
			if inventory_node and inventory_node.visible:
				return
		toggle()
		get_viewport().set_input_as_handled()
