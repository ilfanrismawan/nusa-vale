extends Node2D
## Separate playable rooms, configured with a constructed building's stable session UID.
## Layout ada di scene (disusun awal oleh tools/build_ranch_interiors.gd, lalu diedit di editor):
## `Spots/<aksi>` (feed, stock, menu, eggs, door, exit) adalah titik interaksi, `Pens/PenN` rumah
## hewan ke-N, `DirtSpots/DirtN` tempat kotoran, `AnimalDoor` pintu hewan, `Exit` area keluar.
@export_enum("barn", "chicken_coop") var housing := "barn"
@export var ranch_uid := 0
## Area ruangan untuk batas kamera (kamera tetap di tengah bila ruangan lebih kecil dari layar).
@export var camera_rect := Rect2(224, 112, 448, 256)
## Kotak jelajah hewan di sekitar rumahnya.
@export var roam_size := Vector2(28, 16)
const FONT = preload("res://assets/fonts/m5x7.ttf")
const ZOOM := 2.0
var _herd: Node2D
var _dirt: Node2D
var _status: Label
var _spots: Array[Dictionary] = []

func configure_ranch(uid: int) -> void:
	ranch_uid = uid

func _ready() -> void:
	y_sort_enabled = true
	if ranch_uid == 0:
		ranch_uid = StructureManager.solo_ranch_uid
	set_meta("ranch_uid", ranch_uid)
	set_meta("farm_area", "ranch")
	var exit := get_node_or_null("Exit") as Area2D
	if exit != null:
		exit.body_entered.connect(func(body: Node2D):
			if body is Player and not body.is_input_locked():
				StructureManager.leave_ranch(body))
	_dirt = Node2D.new()
	_dirt.name = "Dirt"
	_dirt.z_index = -4
	add_child(_dirt)
	_herd = Node2D.new()
	_herd.name = "Animals"
	_herd.y_sort_enabled = true
	# The herd is a separate sibling from the player, so y-sort cannot order
	# them against the character. Keep animal sprites behind the player.
	_herd.z_index = -1
	_herd.set_meta("world", weakref(self))
	add_child(_herd)
	_status = _label(self, "", camera_rect.position + Vector2(8, 2), 16)
	_status.z_index = 10
	StructureManager.changed.connect(_refresh)
	SaveManager.game_loaded.connect(_refresh)
	_refresh()
	DayCycle.is_running = true
	for candidate in find_children("*", "CharacterBody2D", true, false):
		if candidate is Player:
			candidate.refresh_world()
			var camera := candidate.get_node_or_null("Camera2D") as Camera2D
			if camera != null and not Coop.has_root():
				camera.set_default_zoom(ZOOM)
				_limit_camera(camera)
				camera.reset_smoothing()

## Batas kamera mengikuti `camera_rect`; ruangan yang lebih kecil dari layar dipusatkan.
func _limit_camera(camera: Camera2D) -> void:
	var view := get_viewport_rect().size / ZOOM
	var center := camera_rect.get_center()
	var half := Vector2(maxf(camera_rect.size.x, view.x), maxf(camera_rect.size.y, view.y)) * 0.5
	camera.limit_left = int(center.x - half.x)
	camera.limit_right = int(center.x + half.x)
	camera.limit_top = int(center.y - half.y)
	camera.limit_bottom = int(center.y + half.y)
	camera.position_smoothing_enabled = false

func _label(parent: Node, text: String, pos: Vector2, size: int = 16) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color("fff1c9"))
	label.add_theme_color_override("font_outline_color", Color("50332b"))
	label.add_theme_constant_override("outline_size", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func pen_center(slot: int) -> Vector2:
	var pens := get_node_or_null("Pens")
	if pens == null or pens.get_child_count() == 0:
		return camera_rect.get_center()
	return (pens.get_child(slot % pens.get_child_count()) as Node2D).global_position

## Posisi titik interaksi `Spots/<action>` (untuk tes dan UI).
func spot_position(action: String) -> Vector2:
	var spot := get_node_or_null("Spots/" + action) as Node2D
	return spot.global_position if spot != null else camera_rect.get_center()

func _collect_spots() -> void:
	_spots.clear()
	var holder := get_node_or_null("Spots")
	if holder == null:
		return
	for spot in holder.get_children():
		if spot is Node2D:
			_spots.append({"position": spot.global_position, "action": str(spot.name)})

func _update_door(open: bool) -> void:
	var door := get_node_or_null("AnimalDoor") as Sprite2D
	if door != null and door.has_meta("open_region"):
		door.region_rect = door.get_meta("open_region") if open else door.get_meta("closed_region")

func _refresh() -> void:
	_collect_spots()
	var record := StructureManager.record_for(ranch_uid)
	if record.get("item") != housing:
		_status.text = "Kandang tidak tersedia. Pintu keluar tetap dapat digunakan."
		_spots = _spots.filter(func(spot: Dictionary): return spot.action == "exit")
		return
	var state := StructureManager.coop_state(record)
	if housing != "chicken_coop":
		_spots = _spots.filter(func(spot: Dictionary): return spot.action != "eggs")
	_update_door(state.door)
	var fed := 0
	var live := {}
	for index in state.chickens.size():
		var animal: Dictionary = state.chickens[index]
		fed += 1 if int(animal.fed_day) == DayCycle.current_day else 0
		var name := "Animal_%d" % int(animal.id)
		live[name] = true
		var actor := _herd.get_node_or_null(name)
		if actor == null:
			actor = load("res://scripts/world/ranch_animal.gd").new()
			actor.name = name
			actor.uid = ranch_uid
			actor.animal_id = int(animal.id)
			actor.indoors = true
			actor.home = pen_center(index)
			actor.roam_rect = Rect2(actor.home - roam_size * 0.5, roam_size)
			_herd.add_child(actor)
		actor.refresh()
	for actor in _herd.get_children():
		if not live.has(str(actor.name)):
			_herd.remove_child(actor)
			actor.queue_free()
	_status.text = "%s · Kenyang %d/%d · Jerami %d · Kotor %d/3%s" % ["TERNAK" if housing == "barn" else "UNGGAS", fed, state.chickens.size(), int(state.hay), int(state.dirt), " · Pintu hewan terbuka" if state.door else ""]
	for child in _dirt.get_children():
		_dirt.remove_child(child)
		child.queue_free()
	var dirt_spots := get_node_or_null("DirtSpots")
	for index in int(state.dirt):
		if dirt_spots == null or index >= dirt_spots.get_child_count():
			break
		var pos := (dirt_spots.get_child(index) as Node2D).global_position
		var sprite := Sprite2D.new()
		sprite.texture = preload("res://assets/ranch/dirt.png")
		sprite.position = pos
		_dirt.add_child(sprite)
		_spots.append({"position": pos, "action": "clean"})

func interact_ranch_near(player: Player) -> bool:
	var carried := player.get_meta("carried_animal") as Node if player.has_meta("carried_animal") else null
	if is_instance_valid(carried) and carried.has_method("place_from_player"):
		carried.place_from_player(player)
		return true
	var feet := player.global_position + Player.FEET_OFFSET
	for actor in _herd.get_children():
		if actor.visible and feet.distance_to(actor.global_position) < 22:
			actor.interact_with(player)
			return true
	var nearest := 30.0
	var selected := ""
	for spot in _spots:
		var distance := feet.distance_to(spot.position)
		if distance < nearest:
			nearest = distance
			selected = spot.action
	if selected.is_empty():
		return false
	var result: Dictionary = {}
	match selected:
		"exit": StructureManager.leave_ranch(player)
		"menu", "stock": StructureManager.open_ranch_menu(player, ranch_uid)
		"feed":
			var record := StructureManager.record_for(ranch_uid)
			if record.is_empty():
				return true
			result = StructureManager.feed_stored(ranch_uid) if int(StructureManager.coop_state(record).hay) > 0 else StructureManager.feed_chickens(player.data, ranch_uid)
		"eggs": result = StructureManager.collect_eggs(player.data, ranch_uid)
		"clean": result = StructureManager.clean_ranch(player.data, ranch_uid)
		"door": result = StructureManager.toggle_ranch_door(ranch_uid)
	if not result.is_empty():
		Notify.say(result.message)
	return true
