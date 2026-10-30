extends PanelContainer

@export var binding_scene: PackedScene = preload("res://scenes/ui/inventory_binding_row.tscn")
@export var controls_only := false
var inventory_ui: CanvasLayer
var _backend: SettingsMenu
var _syncing := false
var _capture: Dictionary = {}
var _capture_time := 0.0
## Bagian Horor (GDD 4.1, Kesulitan Gaib), node scene pada halaman kiri.
var _horror: Control
var _difficulty: OptionButton
var _difficulty_note: Label
var _jumpscare: OptionButton
var _effects: CheckBox
## Halaman kanan: catatan kontrol (bagian lain) atau Catatan Gaib (bagian Horor).
var _right_note: Label
var _journal: Label
## Bagian Satwa: penjelasan di kiri, Catatan Satwa (GDD 4.10.13) di kanan.
var _wildlife: Control
var _wildlife_journal: Label
## Co-op: P2-P4 hanya melihat setelan pribadi (Skala UI); setelan bersama milik P1.
var _personal_only := false
var _shared_note := ""
const PERSONAL_NOTE := "Skala UI hanya mengubah layarmu dan tersimpan untuk kursi pemain ini.

Layar, audio, simpan, dan horor adalah setelan bersama; hanya P1 yang dapat mengubahnya."

func _ready() -> void:
	inventory_ui = get_parent().get_parent().get_parent()
	%Section.item_selected.connect(_select_section)
	%WindowMode.item_selected.connect(_window_mode)
	%Resolution.item_selected.connect(_resolution)
	%Vsync.toggled.connect(_vsync)
	%UiScale.item_selected.connect(_ui_scale)
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
	if controls_only:
		%GeneralHeading.text = "KONTROL"
		for node in [%Section, %Display, %Audio, %Game]: node.hide()
		%ControlsHelp.show()
		%ControlsNote.hide()
	else:
		_build_horror_section()
		_build_wildlife_section()
		for node in [%ControlsHeading, %Hints, %Reset, %Bindings, %BindingsPager]: node.hide()
		_right_note = %ControlsNote
		_shared_note = _right_note.text

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
	_refresh_horror()
	_refresh_ui_scale()
	if _wildlife_journal != null:
		_wildlife_journal.text = WildlifeJournal.text()
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

func _owner_index() -> int:
	var owner_player: Player = inventory_ui.get("player") if inventory_ui != null else null
	return owner_player.player_index if is_instance_valid(owner_player) else 0

## Skala UI hanya ada saat co-op (layar main sendiri memakai ukuran jendela).
func _refresh_ui_scale() -> void:
	if controls_only:
		return
	var coop := Coop.has_root()
	var index := _owner_index()
	%UiScaleTitle.visible = coop
	%UiScale.visible = coop
	if coop:
		%UiScaleTitle.text = "Skala UI P%d (A: ganti)" % (index + 1) if not Coop.get_input(index).uses_mouse() else "Skala UI P%d" % (index + 1)
		var scales: Array[float] = Coop.root.UI_SCALES
		if %UiScale.item_count != scales.size():
			%UiScale.clear()
			for value in scales:
				%UiScale.add_item("%d%%" % roundi(value * 100.0))
		var current: float = Coop.root.ui_scale_of(index)
		var selected := 0
		for i in scales.size():
			if absf(scales[i] - current) < absf(scales[selected] - current):
				selected = i
		%UiScale.select(selected)
	_set_personal_only(Coop.active and index != 0)

func _ui_scale(selected: int) -> void:
	if _syncing or not Coop.has_root():
		return
	Coop.root.set_ui_scale(_owner_index(), Coop.root.UI_SCALES[selected])
	# Ukuran layar logis berubah: tas menyesuaikan skala bukunya di frame berikutnya.
	if inventory_ui != null and inventory_ui.has_method("_resize_inventory"):
		inventory_ui._resize_inventory.call_deferred()

## Gamepad (tanpa mouse): A menggeser Skala UI ke pilihan berikutnya, berputar.
func _step_ui_scale(event: InputEvent) -> bool:
	if not event is InputEventJoypadButton or not %UiScale.is_visible_in_tree() or not Coop.has_root():
		return false
	var input: PlayerInput = inventory_ui._owner_input() if inventory_ui != null else null
	if input == null or not input.is_event(event, &"ui_accept"):
		return false
	var next: int = (%UiScale.selected + 1) % %UiScale.item_count
	%UiScale.select(next)
	_ui_scale(next)
	return true

func _set_personal_only(value: bool) -> void:
	_personal_only = value
	for node in [%Section, %WindowMode, %Resolution, %Vsync]:
		node.visible = not value
	if value:
		%GeneralHeading.text = "SETELAN P%d" % (_owner_index() + 1)
		_select_section(0)
		if _journal != null:
			_journal.hide()
			_wildlife_journal.hide()
		_right_note.show()
		_right_note.text = PERSONAL_NOTE
	else:
		%GeneralHeading.text = "SETELAN"
		_right_note.text = _shared_note
		_select_section(%Section.selected)

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
			button.tooltip_text = "Keyboard / Mouse" if kind == "kb" else "Gamepad"
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
	if _capture.is_empty(): return _step_ui_scale(event)
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
	var sections: Array[Control] = [%Display, %Audio, %Game]
	if _horror != null:
		sections.append(_horror)
	if _wildlife != null:
		sections.append(_wildlife)
	for i in sections.size():
		sections[i].visible = i == index
	if _journal != null:
		_journal.visible = sections[index] == _horror
		_wildlife_journal.visible = sections[index] == _wildlife
		_right_note.visible = not _journal.visible and not _wildlife_journal.visible

# ── Horor: Kesulitan Gaib (per save, P1/host) + aksesibilitas (semua save) ───

func _build_horror_section() -> void:
	_horror = %Horror
	_difficulty = %HorrorDifficulty
	_difficulty_note = %DifficultyNote
	_jumpscare = %JumpscareMode
	_effects = %HorrorEffects
	_journal = %HorrorJournal
	for i in GameState.horror.difficulties.size():
		_difficulty.add_item(GameState.horror.difficulties[i].display_name, i)
	_difficulty.item_selected.connect(func(index: int):
		if not _syncing:
			GameState.horror.set_difficulty(GameState.horror.difficulties[index].id)
			_refresh_horror())
	_jumpscare.item_selected.connect(func(index: int):
		if not _syncing: GameState.horror.set_jumpscare_mode(index))
	_effects.toggled.connect(func(on: bool):
		if not _syncing: GameState.horror.set_screen_effects(on))

func _build_wildlife_section() -> void:
	_wildlife = %Wildlife
	_wildlife_journal = %WildlifeJournal
	%WildlifeHelp.text = %WildlifeHelp.text % [WildlifeJournal.FIRST_EXP, WildlifeJournal.COMPLETE_EXP]

## Catatan Gaib: makhluk yang belum pernah dihadapi tampil sebagai "???".
static func journal_text() -> String:
	var lines: PackedStringArray = ["CATATAN GAIB"]
	var catalog: Array[PackedScene] = []
	var night: Node = load("res://scenes/effects/night_horror.tscn").instantiate()
	catalog.assign(night.stalker_scenes)
	night.free()
	var known := 0
	for scene in catalog:
		var ghost := scene.instantiate() as NightStalker
		if ghost == null:
			continue
		var count := GameState.horror.survived_count(ghost.ghost_id)
		if count > 0:
			known += 1
			lines.append("%s · selamat %dx\n%s" % [ghost.display_name, count, ghost.journal_hint])
		else:
			lines.append("???\n-")
		ghost.free()
	# Penunggu Area (ritual di altar): satu baris tiap Penunggu.
	for id: String in HorrorManager.PENUNGGU:
		var count := GameState.horror.survived_count(StringName(id))
		if count > 0:
			known += 1
			lines.append("%s · tenang %dx" % [HorrorManager.PENUNGGU[id], count])
		else:
			lines.append("Penunggu ???")
	lines[0] = "CATATAN GAIB (%d/%d)%s" % [known, catalog.size() + HorrorManager.PENUNGGU.size(), " · lengkap" if GameState.horror.journal_rewarded else ""]
	# Makhluk = nama + petunjuk satu baris, Penunggu = satu baris, agar semua muat satu halaman.
	return lines[0] + "\n" + "\n".join(lines.slice(1))

func _refresh_horror() -> void:
	if _horror == null or GameState.horror == null:
		return
	var was_syncing := _syncing
	_syncing = true
	var current := GameState.horror.difficulty()
	_difficulty.select(maxi(0, GameState.horror.difficulties.find(current)))
	# Co-op: Kesulitan Gaib milik save, jadi hanya P1 (host) yang mengubahnya.
	var owner_player: Player = inventory_ui.get("player") if inventory_ui != null else null
	_difficulty.disabled = owner_player != null and owner_player.player_index != 0
	_difficulty_note.text = current.description
	_jumpscare.select(int(GameState.horror.jumpscare_mode))
	_effects.button_pressed = GameState.horror.screen_effects
	_journal.text = journal_text()
	_syncing = was_syncing
