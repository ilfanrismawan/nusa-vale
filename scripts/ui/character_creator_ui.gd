class_name CharacterCreatorUI
extends CanvasLayer

signal finished(appearance: CharacterAppearance)
signal cancelled

const CATALOG: CharacterCatalog = preload("res://resources/character/character_catalog.tres")
## Urutan putar preview: depan, kanan, belakang, kiri.
const DIRECTIONS: Array[String] = ["down", "right", "up", "left"]

const COLOR_NAMES := {
	"black": "Hitam",
	"blue": "Biru",
	"brown": "Cokelat",
	"green": "Hijau",
	"navy": "Biru Tua",
	"yellow": "Kuning",
	"blonde": "Pirang",
	"ginger": "Jingga",
	"pink": "Merah Muda",
	"purple": "Ungu",
	"red": "Merah",
}

## Baris pilihan. kind "part" memilih CharacterPart, kind "color" memilih warna dari part di `part_field`.
const ROWS := [
	{"label": "Kulit", "kind": "part", "field": "skin", "layer": CharacterPart.Layer.SKIN, "optional": false},
	{"label": "Mata", "kind": "part", "field": "eyes", "layer": CharacterPart.Layer.EYES, "optional": false},
	{"label": "Warna Mata", "kind": "color", "field": "eye_color", "part_field": "eyes"},
	{"label": "Rambut", "kind": "part", "field": "hair", "layer": CharacterPart.Layer.HAIR, "optional": false},
	{"label": "Warna Rambut", "kind": "color", "field": "hair_color", "part_field": "hair"},
	{"label": "Baju", "kind": "part", "field": "outfit", "layer": CharacterPart.Layer.OUTFIT, "optional": false},
	{"label": "Warna Baju", "kind": "color", "field": "outfit_color", "part_field": "outfit"},
	{"label": "Wajah", "kind": "part", "field": "face", "layer": CharacterPart.Layer.FACE, "optional": true},
	{"label": "Topi", "kind": "part", "field": "head", "layer": CharacterPart.Layer.HEAD, "optional": true},
	{"label": "Warna Topi", "kind": "color", "field": "head_color", "part_field": "head"},
	{"label": "Celana", "kind": "part", "field": "pants", "layer": CharacterPart.Layer.PANTS, "optional": true},
]

## Tampilkan tombol Batal dan izinkan Esc. false saat New Game.
@export var allow_cancel: bool = true
## Pause game selama layar terbuka (dari lemari). false di Main Menu.
@export var pause_game: bool = true
## Tampilkan profil wajib saat Game Baru.
@export var ask_name: bool = false

var appearance: CharacterAppearance
## Pemain yang mengganti penampilan (lemari co-op). Kosong = P1.
var player: Player
var data: PlayerData:
	get: return player.data if is_instance_valid(player) else GameState.p1()
@onready var _preview: AnimatedSprite2D = %Preview
var _direction_index := 0
var _value_labels: Dictionary = {}
var _row_nodes: Dictionary = {}
@onready var _name_edit: LineEdit = %PlayerName
var _preview_action := "walk"


const PetOption = preload("res://scripts/resources/starter_pet_option.gd")
@export var pet_options: Array[PetOption] = [preload("res://resources/pets/dog.tres"), preload("res://resources/pets/dog_brown.tres"), preload("res://resources/pets/dog_caramel.tres"), preload("res://resources/pets/dog_dark.tres"), preload("res://resources/pets/cat.tres"), preload("res://resources/pets/cat_gray.tres"), preload("res://resources/pets/cat_brown.tres"), preload("res://resources/pets/cat_white.tres")]
@export var pet_card_scene: PackedScene = preload("res://scenes/ui/starter_pet_card.tscn")
@export var no_pet_icon: Texture2D = preload("res://resources/ui/btn_close_x.tres")
@export_range(1, 8) var pet_cards_per_page := 8
@export_range(1, 6) var options_per_page := 6
@export_range(1, 32) var pet_name_max_length := 16
@export var design_size := Vector2(1280, 720)
@export var option_scene: PackedScene = preload("res://scenes/ui/character_option_row.tscn")
@export_range(1, 48) var name_max_length := 16
@export_range(1, 48) var farm_name_max_length := 24
@export var preview_max_scale := 7.0
@export var preview_bounds := Vector2(224, 224)
@export var season_labels := PackedStringArray(["Musim Semi", "Musim Panas", "Musim Gugur", "Musim Dingin"])
@export_multiline var required_message := "Lengkapi nama, nama farm, serta musim dan tanggal ulang tahun."
@onready var _farm_edit: LineEdit = %FarmName
var _birthday_season := -1
var _birthday_day := 0
var _pet_id := ""
var _pet_entries: Array[PetOption] = []
var _pet_page := 0
var _option_page := 0
var _page := 0
var _pet_tween: Tween
var _preview_actions := PackedStringArray()
var _action_index := 0
@onready var _pet_name: LineEdit = %PetName
@onready var _calendar: Control = %BirthdayCalendar
@onready var _animation_label: Label = %Animation
var _closed := false
var _menu_open := false
var _background_focus: Dictionary = {}

func _ready() -> void:
	layer = FarmServiceTheme.LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	appearance = CATALOG.sanitize(data.appearance)
	%ProfileTab.visible = ask_name
	%PetTab.visible = ask_name
	%Cancel.visible = allow_cancel
	_name_edit.max_length = name_max_length
	_farm_edit.max_length = farm_name_max_length
	_name_edit.text = data.player_name
	_farm_edit.text = GameState.farm_name
	_set_birthday(DayCycle.SEASONS.find(data.birthday_season), data.birthday_day)
	_calendar.season_labels = season_labels
	_calendar.date_selected.connect(_set_birthday)
	_calendar.visibility_changed.connect(_calendar_visibility_changed)
	%BirthdayButton.pressed.connect(func(): _calendar.open(_birthday_season, _birthday_day))
	_pet_name.max_length = pet_name_max_length
	_pet_name.text = data.pet_name
	_pet_entries.append(null)
	for option in pet_options:
		if option != null and not option.pet_id.is_empty() and not _pet_entries.any(func(entry): return entry != null and entry.pet_id == option.pet_id):
			_pet_entries.append(option)
	var selected := 0
	for index in range(1, _pet_entries.size()):
		if _pet_entries[index].pet_id == data.pet_id:
			selected = index
	_pet_page = selected / pet_cards_per_page
	_select_pet(selected, false)
	%ProfileTab.pressed.connect(_show_page.bind(0))
	%AppearanceTab.pressed.connect(_show_page.bind(1))
	%PetTab.pressed.connect(_show_page.bind(2))
	%PreviousOptions.pressed.connect(_change_option_page.bind(-1))
	%NextOptions.pressed.connect(_change_option_page.bind(1))
	%PreviousPets.pressed.connect(_change_pet_page.bind(-1))
	%NextPets.pressed.connect(_change_pet_page.bind(1))
	%PreviousAnimation.pressed.connect(_cycle_action.bind(-1))
	%NextAnimation.pressed.connect(_cycle_action.bind(1))
	_name_edit.text_changed.connect(_profile_changed)
	_farm_edit.text_changed.connect(_profile_changed)
	_pet_name.text_changed.connect(_profile_changed)
	%Confirm.pressed.connect(_confirm)
	%Cancel.pressed.connect(_cancel)
	%Randomize.pressed.connect(_randomize)
	%TurnLeft.pressed.connect(_turn.bind(-1))
	%TurnRight.pressed.connect(_turn.bind(1))
	_preview.animation_finished.connect(func(): _preview.play())
	_build_options()
	_build_actions()
	get_viewport().size_changed.connect(_resize)
	_resize()
	_refresh()
	_validate_profile()
	_show_page(0 if ask_name else 1)
	if pause_game:
		Coop.set_menu_open(player, true)
		_menu_open = true

func _resize() -> void:
	var view := get_viewport().get_visible_rect().size
	var fit := minf(view.x / design_size.x, view.y / design_size.y)
	$Design.scale = Vector2.ONE * fit
	$Design.position = (view - design_size * fit) * 0.5

func _build_options() -> void:
	for index in ROWS.size():
		var row := option_scene.instantiate()
		%Options.add_child(row)
		row.get_node("Name").text = ROWS[index].label
		row.get_node("Controls/Previous").pressed.connect(_cycle.bind(index, -1))
		row.get_node("Controls/Next").pressed.connect(_cycle.bind(index, 1))
		_value_labels[index] = row.get_node("Controls/Value")
		_row_nodes[index] = [row]

func _build_actions() -> void:
	_preview_actions = PackedStringArray(["walk"])
	var template := CharacterSpriteBuilder.get_template(CATALOG)
	for animation in template.get_animation_names():
		var action := String(animation).trim_suffix("_down").trim_suffix("_right").trim_suffix("_up").trim_suffix("_left")
		if not _preview_actions.has(action):
			_preview_actions.append(action)
	for sheet in CATALOG.sheets:
		if not sheet.animation_name.is_empty() and not _preview_actions.has(String(sheet.animation_name)):
			_preview_actions.append(String(sheet.animation_name))
	_animation_label.text = _preview_actions[0].capitalize()

func _cycle_action(direction: int) -> void:
	_change_action(posmod(_action_index + direction, _preview_actions.size()))

func _change_action(index: int) -> void:
	_action_index = index
	_preview_action = _preview_actions[index]
	_animation_label.text = _preview_action.capitalize()
	_animation_label.tooltip_text = _animation_label.text
	_refresh_preview()

func _show_page(index: int) -> void:
	_page = index if ask_name else 1
	%Identity.visible = ask_name and _page == 0
	%AppearancePage.visible = _page == 1
	%PetPage.visible = ask_name and _page == 2
	%ProfileTab.set_pressed_no_signal(_page == 0)
	%AppearanceTab.set_pressed_no_signal(_page == 1)
	%PetTab.set_pressed_no_signal(_page == 2)
	%Randomize.visible = _page == 1
	if _page == 1:
		_update_option_page()

func _eligible_options() -> Array[int]:
	var eligible: Array[int] = []
	for index in ROWS.size():
		if ROWS[index].kind == "part" or not _options_for(ROWS[index]).is_empty():
			eligible.append(index)
	return eligible

func _change_option_page(direction: int) -> void:
	var pages := maxi(1, ceili(float(_eligible_options().size()) / options_per_page))
	_option_page = posmod(_option_page + direction, pages)
	_update_option_page()

func _update_option_page() -> void:
	var eligible := _eligible_options()
	var pages := maxi(1, ceili(float(eligible.size()) / options_per_page))
	_option_page = clampi(_option_page, 0, pages - 1)
	for index in ROWS.size():
		var position := eligible.find(index)
		for row in _row_nodes.get(index, []):
			row.visible = position >= _option_page * options_per_page and position < (_option_page + 1) * options_per_page
	%OptionPage.text = "Pilihan %d / %d" % [_option_page + 1, pages]
	%PreviousOptions.disabled = pages <= 1
	%NextOptions.disabled = pages <= 1

func _change_pet_page(direction: int) -> void:
	var pages := maxi(1, ceili(float(_pet_entries.size()) / pet_cards_per_page))
	_pet_page = posmod(_pet_page + direction, pages)
	_build_pet_cards()

func _build_pet_cards() -> void:
	for child in %PetCards.get_children():
		%PetCards.remove_child(child)
		child.queue_free()
	var end := mini((_pet_page + 1) * pet_cards_per_page, _pet_entries.size())
	for index in range(_pet_page * pet_cards_per_page, end):
		var option := _pet_entries[index]
		var card := pet_card_scene.instantiate() as Button
		%PetCards.add_child(card)
		card.get_node("Icon").texture = option.icon if option != null else no_pet_icon
		card.get_node("Name").text = option.display_name if option != null else "Tanpa pet"
		card.tooltip_text = option.display_name if option != null else "Mulai tanpa pet"
		card.set_meta("pet_index", index)
		card.set_pressed_no_signal((option.pet_id if option != null else "") == _pet_id)
		card.pressed.connect(_select_pet.bind(index))
	var pages := maxi(1, ceili(float(_pet_entries.size()) / pet_cards_per_page))
	%PetPageNumber.text = "%d / %d" % [_pet_page + 1, pages]
	%PreviousPets.disabled = pages <= 1
	%NextPets.disabled = pages <= 1

func _profile_changed(_text: String) -> void:
	_validate_profile()

func _set_birthday(season_index: int, day: int) -> void:
	_birthday_season = season_index if season_index >= 0 and season_index < DayCycle.SEASONS.size() else -1
	_birthday_day = day if day >= 1 and day <= DayCycle.DAYS_PER_SEASON else 0
	%BirthdayButton.text = "%d · %s" % [_birthday_day, season_labels[_birthday_season] if _birthday_season < season_labels.size() else DayCycle.SEASONS[_birthday_season].capitalize()] if _birthday_season >= 0 and _birthday_day > 0 else "Pilih dari kalender…"
	if is_node_ready():
		_validate_profile()

func _calendar_visibility_changed() -> void:
	if _calendar.visible:
		for branch in $Design.get_children():
			if branch == _calendar:
				continue
			var controls := branch.find_children("*", "Control", true, false)
			controls.append(branch)
			for control in controls:
				if control is Control and control.focus_mode != Control.FOCUS_NONE:
					_background_focus[control] = control.focus_mode
					control.focus_mode = Control.FOCUS_NONE
	else:
		for control in _background_focus:
			if is_instance_valid(control):
				control.focus_mode = _background_focus[control]
		_background_focus.clear()
		%BirthdayButton.grab_focus()

func _select_pet(index: int, animate: bool = true) -> void:
	if index < 0 or index >= _pet_entries.size():
		return
	var option := _pet_entries[index]
	_pet_id = option.pet_id if option != null else ""
	_pet_name.editable = option != null
	%PetIcon.texture = option.icon if option != null else no_pet_icon
	%SelectedPet.text = option.display_name if option != null else "Tanpa pet"
	%PetDescription.text = option.description if option != null else "Kamu bisa memulai tanpa teman peliharaan."
	if animate:
		if _pet_tween != null and _pet_tween.is_valid():
			_pet_tween.kill()
		%PetIcon.scale = Vector2.ONE * 0.78
		_pet_tween = create_tween()
		_pet_tween.tween_property(%PetIcon, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if %PetCards.get_child_count() == 0:
		_build_pet_cards()
	else:
		for card in %PetCards.get_children():
			var entry := _pet_entries[int(card.get_meta("pet_index"))]
			card.set_pressed_no_signal((entry.pet_id if entry != null else "") == _pet_id)
	if is_node_ready():
		_validate_profile()

func _profile_valid() -> bool:
	return not ask_name or (not _name_edit.text.strip_edges().is_empty() and not _farm_edit.text.strip_edges().is_empty() and _birthday_season >= 0 and _birthday_day > 0 and (_pet_id.is_empty() or not _pet_name.text.strip_edges().is_empty()))

func _validate_profile() -> void:
	var valid := _profile_valid()
	%Confirm.disabled = not valid
	%Validation.text = "" if valid else "Isi nama pet yang kamu pilih." if not _pet_id.is_empty() and _pet_name.text.strip_edges().is_empty() else required_message

func _options_for(row: Dictionary) -> PackedStringArray:
	var options: PackedStringArray = []
	if row["kind"] == "part":
		if row["optional"]:
			options.append("")
		for part in CATALOG.get_parts(row["layer"]):
			options.append(part.id)
	else:
		var part := CATALOG.find_part(appearance.get(row["part_field"]))
		if part != null:
			options = part.colors
	return options

func _cycle(row_index: int, step: int) -> void:
	var row: Dictionary = ROWS[row_index]
	var options := _options_for(row)
	if options.is_empty():
		return
	var current: String = appearance.get(row["field"])
	var index := wrapi(options.find(current) + step, 0, options.size())
	appearance.set(row["field"], options[index])
	appearance = CATALOG.sanitize(appearance)
	_refresh()

func _randomize() -> void:
	for row in ROWS:
		if row["kind"] != "part":
			continue
		var options := _options_for(row)
		if not options.is_empty():
			appearance.set(row["field"], options[randi() % options.size()])
	appearance = CATALOG.sanitize(appearance)
	for row in ROWS:
		if row["kind"] == "color":
			var colors := _options_for(row)
			if not colors.is_empty():
				appearance.set(row["field"], colors[randi() % colors.size()])
	_refresh()

func _turn(step: int) -> void:
	_direction_index = wrapi(_direction_index + step, 0, DIRECTIONS.size())
	_play_preview()

func _refresh() -> void:
	for i in ROWS.size():
		var row: Dictionary = ROWS[i]
		var value: String = appearance.get(row["field"])
		var text := "Tidak ada"
		if row["field"] == "pants" and value.is_empty():
			text = "Bawaan Baju"
		if row["kind"] == "part":
			var part := CATALOG.find_part(value)
			if part != null:
				text = part.display_name
		elif not value.is_empty():
			text = COLOR_NAMES.get(value, value.capitalize())
		_value_labels[i].text = text
		# Baris warna disembunyikan jika part-nya tidak punya pilihan warna.
		var visible_row: bool = row["kind"] == "part" or not _options_for(row).is_empty()
		for node in _row_nodes[i]:
			node.visible = visible_row

	_update_option_page()
	_refresh_preview()

func _refresh_preview() -> void:
	var animations: PackedStringArray = [_preview_action]
	for direction in DIRECTIONS:
		animations.append("%s_%s" % [_preview_action, direction])
	var result := CharacterSpriteBuilder.build(CATALOG, appearance, {}, animations)
	_preview.sprite_frames = result["frames"]
	_play_preview()

func _play_preview() -> void:
	if _preview.sprite_frames == null:
		return
	var direction := DIRECTIONS[_direction_index]
	_preview.flip_h = false
	var anim := "%s_%s" % [_preview_action, direction]
	if not _preview.sprite_frames.has_animation(anim) and direction == "left":
		anim = "%s_right" % _preview_action
		_preview.flip_h = true
	if not _preview.sprite_frames.has_animation(anim):
		anim = _preview_action
		_preview.flip_h = false
	if _preview.sprite_frames.has_animation(anim):
		var texture := _preview.sprite_frames.get_frame_texture(anim, 0)
		_preview.scale = Vector2.ONE * minf(preview_max_scale, minf(preview_bounds.x / texture.get_width(), preview_bounds.y / texture.get_height()))
		_preview.play(anim)


func _input(event: InputEvent) -> void:
	if _closed:
		return
	var input := player.input if is_instance_valid(player) else PlayerInput.solo()
	if _calendar.visible and input.is_event(event, &"ui_cancel"):
		get_viewport().set_input_as_handled()
		_calendar.hide()
		%BirthdayButton.grab_focus()
	elif allow_cancel and input.is_event(event, &"ui_cancel"):
		get_viewport().set_input_as_handled()
		_cancel()

func _confirm() -> void:
	if _closed:
		return
	_validate_profile()
	if not _profile_valid():
		if _name_edit.text.strip_edges().is_empty():
			_show_page(0)
			_name_edit.grab_focus()
		elif _farm_edit.text.strip_edges().is_empty():
			_show_page(0)
			_farm_edit.grab_focus()
		elif _birthday_season < 0 or _birthday_day <= 0:
			_show_page(0)
			%BirthdayButton.grab_focus()
		else:
			_show_page(2)
			_pet_name.grab_focus()
		return
	if ask_name:
		data.player_name = _name_edit.text.strip_edges()
		GameState.farm_name = _farm_edit.text.strip_edges()
		data.birthday_season = DayCycle.SEASONS[_birthday_season]
		data.birthday_day = _birthday_day
		data.pet_id = _pet_id
		data.pet_name = _pet_name.text.strip_edges() if not _pet_id.is_empty() else ""
	data.set_appearance(appearance)
	_closed = true
	_release_menu()
	finished.emit(data.appearance)
	queue_free()

func _cancel() -> void:
	if _closed or not allow_cancel:
		return
	_closed = true
	_release_menu()
	cancelled.emit()
	queue_free()

func _release_menu() -> void:
	if _menu_open:
		Coop.set_menu_open(player, false)
	_menu_open = false

func _exit_tree() -> void:
	_release_menu()
