extends PanelContainer
## Tab Peta di buku tas (GDD 3 "Peta Lembah"): halaman kiri gambar lembah dengan area yang bisa
## dipilih, pin pemain co-op, dan filter; halaman kanan detail area terpilih (tempat + jam buka,
## warga yang sedang di sana, hasil alam musim ini). Hanya untuk dilihat, tanpa teleport.
## Data area ada di node WorldMapArea (Inspector); halaman ini hanya membaca dan menampilkan.

@export var row_scene: PackedScene = preload("res://scenes/ui/world_map_row.tscn")
@export var pin_scene: PackedScene = preload("res://scenes/ui/world_map_pin.tscn")
## Warna pin per pemain (P1..P4).
@export var pin_colors: Array[Color] = [Color(0.89, 0.13, 0.17), Color(0.14, 0.68, 0.9), Color(0.3, 0.64, 0.17), Color(1, 0.78, 0.1)]
@export var open_color := Color(0.27, 0.47, 0.2, 1)
@export var closed_color := Color(0.63, 0.24, 0.2, 1)
@export var muted_color := Color(0.45, 0.31, 0.2, 1)
@export var locked_color := Color(0.47, 0.47, 0.55, 1)
@export_range(1, 12) var max_season_icons := 8

var inventory_ui: CanvasLayer
var _areas: Array[WorldMapArea] = []
var _selected: WorldMapArea
var _filter := ""
var _filters := ButtonGroup.new()


func data() -> PlayerData:
	return inventory_ui.data if is_instance_valid(inventory_ui) else GameState.p1()


func _owner_input() -> PlayerInput:
	return inventory_ui._owner_input() if is_instance_valid(inventory_ui) else PlayerInput.solo()


func _ready() -> void:
	_filters.allow_unpress = true
	for child in %Areas.get_children():
		if child is WorldMapArea:
			var area: WorldMapArea = child
			_areas.append(area)
			area.pressed.connect(_select.bind(area))
			area.focus_entered.connect(_select.bind(area))
	for button in %Filters.get_children():
		if button is Button:
			button.toggle_mode = true
			button.button_group = _filters
			button.toggled.connect(_on_filter_toggled.bind(button))
	DayCycle.time_tick.connect(func(_h: int, _m: int):
		if is_visible_in_tree():
			_update_dynamic())
	UnlockManager.unlock_changed.connect(func(_id: String, _v: bool):
		if is_visible_in_tree():
			refresh())


## Dipanggil buku inventory setiap kali tab dibuka: pilih area tempat pemain berada.
func refresh() -> void:
	for area in _areas:
		area.refresh_state()
	var here := area_of_player(_own_player())
	_select(here if here != null else _area_by_id("farm"))
	_update_dynamic()
	_focus_selected.call_deferred()


func _focus_selected() -> void:
	if is_instance_valid(_selected) and is_visible_in_tree():
		_selected.grab_focus()


func _update_dynamic() -> void:
	%Clock.text = "%s %d · %02d.%02d" % [DayCycle.get_season_display_name().trim_prefix("Musim "), DayCycle.get_day_of_season(), DayCycle.hour, DayCycle.minute]
	_apply_filter()
	_update_pins()
	_show_detail(_selected)


# ── Input: WASD / stik memilih area terdekat ke arah itu ──────────────

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event.is_pressed() or event.is_echo():
		return
	var input := _owner_input()
	var dir := Vector2.ZERO
	if input.is_event(event, &"move_up"):
		dir = Vector2.UP
	elif input.is_event(event, &"move_down"):
		dir = Vector2.DOWN
	elif input.is_event(event, &"move_left"):
		dir = Vector2.LEFT
	elif input.is_event(event, &"move_right"):
		dir = Vector2.RIGHT
	if dir == Vector2.ZERO:
		return
	var next := neighbor(_selected, dir)
	if next != null:
		_select(next)
		next.grab_focus()
	get_viewport().set_input_as_handled()


## Area terdekat dari `from` ke arah `dir` (sudut dihitung dari pusat kotak area).
func neighbor(from: WorldMapArea, dir: Vector2) -> WorldMapArea:
	if from == null:
		return _areas[0] if not _areas.is_empty() else null
	var origin := from.position + from.size * 0.5
	var best: WorldMapArea = null
	var best_score := INF
	for area in _areas:
		if area == from:
			continue
		var delta := area.position + area.size * 0.5 - origin
		var along := delta.dot(dir)
		if along <= 0.0:
			continue
		var across := absf(delta.dot(Vector2(-dir.y, dir.x)))
		if across > along * 2.0:
			continue
		var score := along + across * 2.0
		if score < best_score:
			best_score = score
			best = area
	return best


# ── Pilihan & filter ──────────────────────────────────────────────────

func _select(area: WorldMapArea) -> void:
	if area == null:
		return
	if _selected == area and area.selected:
		return
	if is_instance_valid(_selected):
		_selected.selected = false
	_selected = area
	area.selected = true
	_show_detail(area)


func select_area(area_id: String) -> void:
	_select(_area_by_id(area_id))


func _on_filter_toggled(on: bool, button: Button) -> void:
	_filter = str(button.get_meta("filter", "")) if on else ("" if _filters.get_pressed_button() == null else _filter)
	_apply_filter()


func set_filter(tag: String) -> void:
	for button in %Filters.get_children():
		if button is Button:
			button.set_pressed_no_signal(str(button.get_meta("filter", "")) == tag and not tag.is_empty())
	_filter = tag
	_apply_filter()


func _apply_filter() -> void:
	for area in _areas:
		area.dimmed = not _filter.is_empty() and not _area_has(area, _filter)


func _area_has(area: WorldMapArea, tag: String) -> bool:
	if tag == "resident":
		return area.is_open() and not residents_in(area).is_empty()
	return area.is_open() and area.has_tag(tag)


func _area_by_id(id: String) -> WorldMapArea:
	for area in _areas:
		if area.area_id == id:
			return area
	return null


# ── Pemain ────────────────────────────────────────────────────────────

func _players() -> Array[Player]:
	var out: Array[Player] = []
	for node in get_tree().get_nodes_in_group(Combat.PLAYER_GROUP):
		if node is Player and is_instance_valid(node.data):
			out.append(node)
	out.sort_custom(func(a: Player, b: Player): return a.data.index < b.data.index)
	return out


func _own_player() -> Player:
	var own: Player = inventory_ui.player if is_instance_valid(inventory_ui) and "player" in inventory_ui else null
	if is_instance_valid(own):
		return own
	var players := _players()
	return players[0] if not players.is_empty() else null


## Path scene dunia tempat node berada (naik ke induk sampai ketemu scene di scenes/world/).
static func world_scene_of(node: Node) -> String:
	var n := node
	while n != null:
		if n.scene_file_path.begins_with("res://scenes/world/"):
			return n.scene_file_path
		n = n.get_parent()
	var current := node.get_tree().current_scene if node != null and node.is_inside_tree() else null
	return current.scene_file_path if current != null else ""


func area_of_player(player: Player) -> WorldMapArea:
	if player == null:
		return null
	return area_for_scene(world_scene_of(player))


func area_for_scene(path: String) -> WorldMapArea:
	for area in _areas:
		if area.matches_scene(path):
			return area
	return null


func _update_pins() -> void:
	for pin in %Pins.get_children():
		pin.queue_free()
	var stacked := {}
	for player in _players():
		var area := area_of_player(player)
		if area == null:
			continue
		var pin := pin_scene.instantiate() as Control
		var i := player.data.index
		pin.fill = pin_colors[i % pin_colors.size()]
		pin.number = i + 1
		var n: int = stacked.get(area, 0)
		stacked[area] = n + 1
		%Pins.add_child(pin)
		pin.position = area.pin_position() + Vector2(n * 10, 0) - Vector2(pin.size.x * 0.5, pin.size.y)
		pin.tooltip_text = _player_label(player)


func _player_label(player: Player) -> String:
	var own := _own_player()
	if player == own:
		return "Kamu"
	return "P%d" % (player.data.index + 1)


func _player_place(player: Player) -> String:
	var area := area_of_player(player)
	if area == null:
		return "?"
	var text := area.display_name
	if area.area_id == "cave":
		var cave = GameState.get("cave")
		if cave != null and int(cave.current_floor) > 0:
			text += " Lt. %d" % int(cave.current_floor)
	return text


# ── Detail (halaman kanan) ────────────────────────────────────────────

func _show_detail(area: WorldMapArea) -> void:
	if area == null:
		return
	var open := area.is_open()
	%AreaIcon.texture = area.icon_texture
	%AreaName.text = area.shown_name()
	%AreaStatus.text = "Terbuka" if open else "Terkunci"
	%AreaStatus.add_theme_color_override("font_color", open_color if open else locked_color)
	%AreaSubtitle.text = area.subtitle if open or not area.hide_name_when_locked else ""
	for child in %Body.get_children():
		child.queue_free()
	if not open:
		_add_note(area.locked_hint, muted_color)
	else:
		if area.area_id == "cave":
			_add_cave_rows()
		_add_places(area)
		_add_residents(area)
		_add_season(area)
	_update_players_line()


func _add_heading(text: String) -> void:
	var label := %HeadingTemplate.duplicate() as Label
	label.text = text
	label.visible = true
	%Body.add_child(label)


func _add_note(text: String, color: Color) -> void:
	var label := %NoteTemplate.duplicate() as Label
	label.text = text
	label.visible = true
	label.add_theme_color_override("font_color", color)
	%Body.add_child(label)


func _add_row(title: String, value: String, value_color: Color, tooltip := "", icon: Texture2D = null) -> void:
	var row := row_scene.instantiate() as Control
	%Body.add_child(row)
	(row.get_node("%Title") as Label).text = title
	var value_label := row.get_node("%Value") as Label
	value_label.text = value
	value_label.add_theme_color_override("font_color", value_color)
	var icon_rect := row.get_node("%Icon") as TextureRect
	icon_rect.texture = icon
	icon_rect.visible = icon != null
	row.tooltip_text = tooltip


func _add_places(area: WorldMapArea) -> void:
	if area.services.is_empty() and area.places.is_empty():
		return
	_add_heading("TEMPAT")
	for id in area.services:
		var rules: Dictionary = ServiceHours.SERVICES.get(id, {})
		if rules.is_empty():
			continue
		var is_open := ServiceHours.is_open(id)
		_add_row(str(rules.name), "Buka" if is_open else "Tutup", open_color if is_open else closed_color, ServiceHours.hours_text(id))
	for place in area.places:
		_add_row(place, "", muted_color)


func _add_cave_rows() -> void:
	var cave = GameState.get("cave")
	if cave == null:
		return
	_add_heading("KEMAJUAN")
	_add_row("Lantai terdalam", "%d / %d" % [int(cave.deepest_floor), CaveManager.DATA.max_floor], Color(0.25, 0.14, 0.08, 1))
	_add_row("Lift sampai", "Lt. %d" % int(cave.deepest_lift) if int(cave.deepest_lift) > 0 else "-", Color(0.25, 0.14, 0.08, 1))
	_add_row("Boss dikalahkan", str(cave.bosses_defeated.size()), Color(0.25, 0.14, 0.08, 1))


## Nama warga yang menurut jadwal sedang berada di area ini.
func residents_in(area: WorldMapArea) -> PackedStringArray:
	var names: PackedStringArray = []
	if area.npc_maps.is_empty():
		return names
	var rainy: bool = GameState.weather.is_raining()
	for id: String in NPCDatabase.residents:
		var entry: Dictionary = NPCDatabase.schedule_entry(id, DayCycle.hour, DayCycle.minute, rainy)
		if area.npc_maps.has(str(entry.get("map", ""))):
			names.append(str(NPCDatabase.residents[id].get("name", id.capitalize())))
	return names


## Batas nama warga di halaman kanan supaya tidak meluap.
const RESIDENTS_SHOWN := 5


func _add_residents(area: WorldMapArea) -> void:
	if area.npc_maps.is_empty():
		return
	_add_heading("WARGA DI SINI")
	var names := residents_in(area)
	if names.size() > RESIDENTS_SHOWN:
		var extra := names.size() - RESIDENTS_SHOWN
		names = names.slice(0, RESIDENTS_SHOWN)
		names.append("+%d lainnya" % extra)
	_add_note(", ".join(names) if not names.is_empty() else "Tidak ada warga saat ini.", Color(0.25, 0.14, 0.08, 1) if not names.is_empty() else muted_color)


## Ikon hasil alam musim ini: forage (bukan galian) lalu ikan. Ikan yang belum pernah
## ditangkap tampil sebagai siluet.
func _add_season(area: WorldMapArea) -> void:
	var entries: Array[Dictionary] = []
	var seen := {}
	for loc in area.forage_locations:
		for forage in ForageManager.candidates(loc):
			if forage.item != null and not seen.has(forage.item.item_id):
				seen[forage.item.item_id] = true
				entries.append({"item": forage.item, "known": true})
	var season := DayCycle.get_current_season()
	for fish in FishingManager._fish:
		if fish.item == null or seen.has(fish.item.item_id) or not fish.is_in_season(season):
			continue
		for loc in area.fish_locations:
			if fish.locations.has(loc):
				seen[fish.item.item_id] = true
				entries.append({"item": fish.item, "known": DiscoveryManager.has_discovered("fish_" + fish.item.item_id)})
				break
	if entries.is_empty():
		return
	_add_heading("MUSIM INI")
	var box := %ItemsTemplate.duplicate() as HFlowContainer
	box.visible = true
	%Body.add_child(box)
	for i in mini(entries.size(), max_season_icons):
		var item: ItemData = entries[i].item
		var icon := TextureRect.new()
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.custom_minimum_size = Vector2(14, 14)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = item.icon
		var known: bool = entries[i].known
		icon.modulate = Color.WHITE if known else Color(0, 0, 0, 0.55)
		icon.tooltip_text = item.display_name if known else "???"
		box.add_child(icon)


func _update_players_line() -> void:
	var parts: PackedStringArray = []
	for player in _players():
		parts.append("%s: %s" % [_player_label(player), _player_place(player)])
	%Players.text = " · ".join(parts)
