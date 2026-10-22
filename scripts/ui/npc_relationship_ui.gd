class_name NPCRelationshipUI
extends Control

signal finished

@export var embedded := false
@export var design_size := Vector2(420, 224)
@export var resident_scene: PackedScene = preload("res://scenes/ui/relationship_resident.tscn")
@export var gift_scene: PackedScene = preload("res://scenes/ui/relationship_gift.tscn")
@export var heart_scene: PackedScene = preload("res://scenes/ui/relationship_heart.tscn")
@export var heart_icon: Texture2D = preload("res://resources/ui/icon_tab_heart.tres")
@export var map_names: Dictionary = {"town": "Kota", "hill": "Perbukitan", "farm": "Kebun", "wira_home": "Rumah Wira", "ubay_home": "Rumah Ubay"}
var inventory_ui: CanvasLayer
var player: Player
var selected_id := ""
var _closed := false
var _owns_pause := false
var _ids: Array[String] = []
var _buttons: Dictionary = {}
var _items: Dictionary = {}
var _gift_category := 0
var _refresh_pending := false
var _owner_text := ""
var _footer_text := ""
const CATEGORIES := ["loved", "liked", "neutral", "disliked", "hated"]
const CATEGORY_NAMES := ["Love", "Like", "Netral", "Dislike", "Hate"]
const STATUS_NAMES := {"dating": "Berpacaran", "married": "Menikah"}

func data() -> PlayerData:
	return inventory_ui.data if is_instance_valid(inventory_ui) else (player.data if is_instance_valid(player) else GameState.p1())

func _ready() -> void:
	if embedded:
		inventory_ui = get_parent().get_parent().get_parent()
		$Backdrop.hide()
		%Close.hide()
	process_mode = Node.PROCESS_MODE_ALWAYS
	%Search.text_changed.connect(func(_value: String): _rebuild_list())
	%Filter.item_selected.connect(func(_index: int): _rebuild_list())
	%Close.pressed.connect(close_menu)
	%GiftTabs.item_selected.connect(_select_category)
	%Section.item_selected.connect(_select_section)
	var owner_input: Player = inventory_ui.player if is_instance_valid(inventory_ui) else player
	_footer_text = "Pilih warga untuk melihat hubungan · Hadiah diberikan saat bertemu NPC · %s: Kembali" % InputPrompt.key_text(&"ui_cancel", owner_input, InputLayout.MENU)
	get_viewport().size_changed.connect(_resize)
	DayCycle.time_tick.connect(_on_time_tick)
	GameState.inventory_changed.connect(_queue_refresh)
	if is_instance_valid(inventory_ui):
		inventory_ui.visibility_changed.connect(_inventory_visibility_changed)
	else:
		Coop.set_menu_open(player, true)
		_owns_pause = true
	refresh()
	_resize()
	if not embedded:
		%Search.grab_focus()

func _definition(id: String) -> Dictionary:
	return NPCDatabase.social_definition(id)

func _display_name(id: String) -> String:
	var definition := _definition(id)
	return str(definition.get("name", id.capitalize()))

func _portrait(id: String) -> Texture2D:
	var visual: Dictionary = _definition(id).get("visual", {})
	var path := str(visual.get("portrait", ""))
	if not path.is_empty() and ResourceLoader.exists(path):
		return FarmServiceTheme.portrait(load(path) as Texture2D)
	var legacy := NPCDatabase.get_definition(StringName(id))
	return FarmServiceTheme.portrait(legacy.portrait) if legacy != null else null

func refresh() -> void:
	var owner_name := data().player_name if not data().player_name.is_empty() else "Petani P%d" % (data().index + 1)
	_owner_text = "Hubungan milik " + owner_name
	_rebuild_list()

func _matches(id: String) -> bool:
	var query: String = %Search.text.strip_edges().to_lower()
	if not query.is_empty() and not (_display_name(id) + " " + str(_definition(id).get("role", ""))).to_lower().contains(query):
		return false
	var status := str(data().romances.get(id, ""))
	match %Filter.selected:
		1: return NPCSocialService.points(data(), id) >= NPCSocialService.POINTS_PER_HEART
		2: return bool(_definition(id).get("romanceable", false))
		3: return status == "dating"
		4: return status == "married"
	return true

func _rebuild_list() -> void:
	var focused_id := ""
	for id: String in _buttons:
		if is_instance_valid(_buttons[id]) and _buttons[id].has_focus():
			focused_id = id
	for child in %Residents.get_children():
		%Residents.remove_child(child)
		child.queue_free()
	_buttons.clear()
	_ids.clear()
	for source: Dictionary in [NPCDatabase.residents, NPCDatabase.gift_profiles]:
		for id: String in source:
			if id not in _ids and _matches(id):
				_ids.append(id)
	_ids.sort_custom(func(a: String, b: String): return _display_name(a).naturalnocasecmp_to(_display_name(b)) < 0)
	%Count.text = "%d warga · pilih nama" % _ids.size()
	for id: String in _ids:
		var button := resident_scene.instantiate() as Button
		button.name = id
		button.icon = _portrait(id)
		if button.icon == null:
			button.icon = preload("res://resources/ui/icon_tab_person.tres")
		var points := NPCSocialService.points(data(), id)
		var hearts := floori(float(points) / NPCSocialService.POINTS_PER_HEART)
		button.text = "%s\n%d / %d hati%s" % [_display_name(id), hearts, NPCSocialService.max_hearts(id), " · " + str(STATUS_NAMES[data().romances[id]]) if data().romances.has(id) else ""]
		button.pressed.connect(_select_npc.bind(id))
		%Residents.add_child(button)
		_buttons[id] = button
	%ResidentsPager.refresh()
	%Empty.visible = _ids.is_empty()
	%Details.visible = not _ids.is_empty()
	if not _ids.is_empty():
		_select_npc(selected_id if selected_id in _ids else _ids[0])
	else:
		selected_id = ""
	if _buttons.has(focused_id):
		_buttons[focused_id].grab_focus()

func _select_npc(id: String) -> void:
	var changed := selected_id != id
	selected_id = id
	for key: String in _buttons:
		_buttons[key].set_pressed_no_signal(key == id)
	var definition := _definition(id)
	%Name.text = _display_name(id)
	%Role.text = str(definition.get("role", "Warga Nusa Vale"))
	%Portrait.texture = _portrait(id)
	%Initial.text = _display_name(id).left(1).to_upper()
	%Initial.visible = %Portrait.texture == null
	%Birthday.text = _birthday_text(definition)
	var points := NPCSocialService.points(data(), id)
	var cap := NPCSocialService.max_points(id)
	%Points.text = "%d / %d poin persahabatan" % [points, cap]
	%Progress.max_value = cap
	%Progress.value = points
	for child in %Hearts.get_children():
		%Hearts.remove_child(child)
		child.queue_free()
	var maximum := NPCSocialService.max_hearts(id)
	for index in mini(20, maximum):
		var icon := heart_scene.instantiate() as TextureRect
		icon.texture = heart_icon
		icon.modulate = Color.WHITE if points >= (index + 1) * NPCSocialService.POINTS_PER_HEART else Color(1, 1, 1, 0.18)
		%Hearts.add_child(icon)
	var hearts := floori(float(points) / NPCSocialService.POINTS_PER_HEART)
	var status := str(data().romances.get(id, ""))
	var friendship := "Sahabat" if hearts >= 8 else ("Teman" if hearts >= 4 else ("Kenalan" if hearts >= 1 else "Belum akrab"))
	%Status.text = str(STATUS_NAMES.get(status, friendship))
	%Romance.text = "Bisa romance" if bool(definition.get("romanceable", false)) else "Persahabatan"
	var entry: Dictionary = data().friendships.get(id, {})
	var week := floori(float(DayCycle.current_day - 1) / 7.0)
	var gifts := int(entry.get("gifts", 0)) if int(entry.get("week", -1)) == week else 0
	var daily_text := "Bicara hari ini: %s    ·    Hadiah hari ini: %s    ·    Minggu ini: %d/%d" % ["Sudah" if int(entry.get("talk_day", 0)) == DayCycle.current_day else "Belum", "Sudah" if int(entry.get("gift_day", 0)) == DayCycle.current_day else "Belum", gifts, NPCSocialService.WEEKLY_GIFTS]
	var schedule_text := ""
	if NPCDatabase.residents.has(id):
		var schedule := NPCDatabase.schedule_entry(id, DayCycle.hour, DayCycle.minute, GameState.weather.is_raining())
		var map_id := str(schedule.get("map", ""))
		schedule_text = "Jadwal sekarang: " + str(schedule.get("location", map_names.get(map_id, map_id.capitalize())))
	var events: Array = definition.get("heart_events", [])
	var done := 0
	for event: Dictionary in events:
		if bool(data().completed_events.get(str(event.get("id", "")), false)):
			done += 1
	var story_text := "Cerita: %d/%d event selesai" % [done, events.size()] if not events.is_empty() else ""
	if not NPCEventService.pending_letter(data(), id).is_empty():
		story_text += " · Ada surat, bicara dengan NPC ini"
	%Journal.text = "\n\n".join([_owner_text, daily_text, schedule_text, story_text, _footer_text])
	_select_category(_gift_category)
	if changed:
		call_deferred("_reveal_selection")

func _reveal_selection() -> void:
	if not _closed and _buttons.has(selected_id) and is_instance_valid(_buttons[selected_id]):
		%ResidentsPager.reveal(_buttons[selected_id].get_index())

func _birthday_text(definition: Dictionary) -> String:
	var birthday: Dictionary = definition.get("birthday", {})
	var season := str(definition.get("birthday_season", birthday.get("season", "")))
	var day := int(definition.get("birthday_day", birthday.get("day", 0)))
	var seasons := {"spring": "Semi", "summer": "Panas", "fall": "Gugur", "autumn": "Gugur", "winter": "Dingin"}
	return "Ulang tahun: %d Musim %s" % [day, seasons.get(season, season)] if day > 0 else "Ulang tahun: belum tercatat"

func _select_category(index: int) -> void:
	_gift_category = index
	for child in %Gifts.get_children():
		%Gifts.remove_child(child)
		child.queue_free()
	%GiftInfo.text = "Pilih item untuk melihat detail. Hadiah diberikan saat bertemu NPC."
	if selected_id.is_empty():
		return
	var category: String = CATEGORIES[index]
	var delta: int = NPCSocialService.GIFT_POINTS[category]
	%GiftHeading.text = "%s  ·  %s%d poin" % [CATEGORY_NAMES[index], "+" if delta >= 0 else "", delta]
	%GiftHint.text = "Item di luar daftar selera juga dianggap netral." if category == "neutral" else "Selera hadiah " + _display_name(selected_id)
	%GiftHint.visible = category == "neutral"
	for item_id: String in NPCSocialService._preference(selected_id, category):
		if not _items.has(item_id):
			_items[item_id] = GameState._resolve_item(item_id)
		var item: ItemData = _items[item_id]
		if item == null:
			continue
		var card := gift_scene.instantiate() as Button
		card.text = item.display_name
		card.icon = item.icon
		card.tooltip_text = item.display_name + "\n" + item.description
		card.pressed.connect(func():
			%GiftInfo.text = item.display_name + " · " + item.description
			%Section.select(3)
			_select_section(3))
		%Gifts.add_child(card)

	%GiftsPager.refresh()

func _resize() -> void:
	var view := size if embedded else get_viewport().get_visible_rect().size
	var fit := minf(view.x / design_size.x, view.y / design_size.y)
	$Design.scale = Vector2.ONE * fit
	$Design.position = ((view - design_size * fit) * 0.5).floor()

func _on_time_tick(_hour: int, _minute: int) -> void:
	_queue_refresh()

func _queue_refresh() -> void:
	if _refresh_pending or _closed:
		return
	_refresh_pending = true
	call_deferred("_refresh_deferred")

func _refresh_deferred() -> void:
	_refresh_pending = false
	if not _closed:
		refresh()

func _input(event: InputEvent) -> void:
	if _closed or embedded or not is_visible_in_tree():
		return
	var input: PlayerInput = inventory_ui._owner_input() if is_instance_valid(inventory_ui) else (player.input if is_instance_valid(player) else PlayerInput.solo())
	# Typing I in the search field must not close the journal.
	if input.is_event(event, &"ui_cancel") or (input.is_event(event, &"inventory") and not %Search.has_focus()):
		get_viewport().set_input_as_handled()
		close_menu()

func close_menu() -> void:
	if embedded:
		hide()
		return
	if _closed:
		return
	_closed = true
	hide()
	if _owns_pause:
		Coop.set_menu_open(player, false)
		_owns_pause = false
	if is_instance_valid(inventory_ui) and inventory_ui.visible:
		inventory_ui._show_bag_page()
		inventory_ui._menu_buttons["NPC"].grab_focus()
	finished.emit()
	queue_free()

func _inventory_visibility_changed() -> void:
	if is_instance_valid(inventory_ui) and not inventory_ui.visible:
		close_menu()

func _exit_tree() -> void:
	if _owns_pause:
		Coop.set_menu_open(player, false)

func _select_section(index: int) -> void:
	for i in 4:
		[%Profile, %Activity, %GiftList, %GiftDetail][i].visible = i == index
