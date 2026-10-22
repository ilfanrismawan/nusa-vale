extends PanelContainer

@export var binding_scene: PackedScene = preload("res://scenes/ui/inventory_binding_row.tscn")
var inventory_ui: CanvasLayer
var _backend: SettingsMenu
var _syncing := false
var _capture: Dictionary = {}
var _capture_time := 0.0

func _ready() -> void:
	inventory_ui = get_parent().get_parent().get_parent()
	%Section.item_selected.connect(_select_section)
	%WindowMode.item_selected.connect(_window_mode)
	%Resolution.item_selected.connect(_resolution)
	%Vsync.toggled.connect(_vsync)
	%Master.value_changed.connect(_volume.bind("master_slider"))
	%Music.value_changed.connect(_volume.bind("music_slider"))
	%Sfx.value_changed.connect(_volume.bind("sfx_slider"))
	%Hints.toggled.connect(func(on: bool):
		if not _syncing:
			ActionHints.set_enabled(on))
	%Reset.pressed.connect(func():
		PlayerInput.reset_bindings()
		_rebuild_bindings())
	%Save.pressed.connect(func():
		if _backend != null: _backend._on_save_pressed())
	%Load.pressed.connect(func():
		if _backend != null: _backend._on_load_pressed())
	%MainMenu.pressed.connect(func():
		if _backend != null: _backend._confirm_exit(false))
	%Quit.pressed.connect(func():
		if _backend != null: _backend._confirm_exit(true))
	visibility_changed.connect(_visibility_changed)

func refresh() -> void:
	_backend = inventory_ui.get_parent().get_node_or_null("SettingsMenu") as SettingsMenu
	_syncing = true
	if _backend != null:
		_backend.layer = inventory_ui.layer + 1
		_backend._sync_current_settings()
		%WindowMode.select(_backend.window_mode_option.selected)
		%Resolution.select(_backend.resolution_option.selected)
		%Resolution.disabled = _backend.resolution_option.disabled
		%Vsync.button_pressed = _backend.vsync_check.button_pressed
		%Master.value = _backend.master_slider.value
		%Music.value = _backend.music_slider.value
		%Sfx.value = _backend.sfx_slider.value
	for entry in [[%Master, %MasterValue], [%Music, %MusicValue], [%Sfx, %SfxValue]]:
		entry[1].text = "%d%%" % roundi(entry[0].value * 100)
	%Hints.button_pressed = ActionHints.is_enabled()
	%Load.disabled = Coop.active or _backend == null
	%Save.disabled = _backend == null
	%MainMenu.disabled = _backend == null
	%Quit.disabled = _backend == null
	_syncing = false
	_rebuild_bindings()

func _window_mode(index: int) -> void:
	if _syncing or _backend == null: return
	_backend._on_window_mode_selected(index)
	%Resolution.disabled = _backend.resolution_option.disabled

func _resolution(index: int) -> void:
	if _syncing or _backend == null: return
	_backend.resolution_option.select(index)
	_backend._on_resolution_selected(index)

func _vsync(on: bool) -> void:
	if not _syncing and _backend != null:
		_backend.vsync_check.button_pressed = on

func _volume(value: float, target: String) -> void:
	if _syncing or _backend == null: return
	_backend.get(target).value = value
	var label: Label = %MasterValue if target == "master_slider" else %MusicValue if target == "music_slider" else %SfxValue
	label.text = "%d%%" % roundi(value * 100)

func _rebuild_bindings() -> void:
	_cancel_capture()
	for child in %Bindings.get_children():
		%Bindings.remove_child(child)
		child.queue_free()
	for row: Dictionary in PlayerInput.rows():
		if not row["show"]: continue
		var entry := binding_scene.instantiate() as VBoxContainer
		%Bindings.add_child(entry)
		entry.get_node("Action").text = row["label"]
		entry.tooltip_text = str(row["group"])
		for kind: String in ["kb", "pad"]:
			var button := entry.get_node("Buttons/Keyboard" if kind == "kb" else "Buttons/Gamepad") as Button
			button.text = _binding_text(row, kind)
			button.pressed.connect(_begin_capture.bind(row["id"], kind, button))

	%BindingsPager.refresh()

func _binding_text(row: Dictionary, kind: String) -> String:
	var parts: PackedStringArray = []
	for spec in row[kind]: parts.append(InputLayout.spec_label(spec[0]))
	return " / ".join(parts) if not parts.is_empty() else "—"

func _begin_capture(id: String, kind: String, button: Button) -> void:
	_cancel_capture()
	_capture = {"id": id, "kind": kind, "button": button}
	_capture_time = SettingsMenu.CAPTURE_TIMEOUT
	button.text = "Tekan tombol..."

func _cancel_capture() -> void:
	if _capture.is_empty(): return
	for row: Dictionary in PlayerInput.rows():
		if row["id"] == _capture["id"] and is_instance_valid(_capture["button"]):
			_capture["button"].text = _binding_text(row, _capture["kind"])
	_capture.clear()

func capture_input(event: InputEvent) -> bool:
	if _capture.is_empty(): return false
	if event is InputEventKey and event.pressed and (event.physical_keycode == KEY_ESCAPE or event.keycode == KEY_ESCAPE):
		_cancel_capture()
		return true
	var spec := InputLayout.from_event(event)
	if spec.is_empty() or InputLayout.is_pad_spec(spec) != (_capture["kind"] == "pad"):
		return event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton
	if _backend != null:
		_backend._apply_binding(_capture["id"], _capture["kind"], spec)
	_capture.clear()
	_rebuild_bindings.call_deferred()
	return true

func _process(delta: float) -> void:
	if _capture.is_empty(): return
	_capture_time -= delta
	if _capture_time <= 0: _cancel_capture()

func _visibility_changed() -> void:
	if not is_visible_in_tree(): _cancel_capture()

func _select_section(index: int) -> void:
	for i in 3:
		[%Display, %Audio, %Game][i].visible = i == index
