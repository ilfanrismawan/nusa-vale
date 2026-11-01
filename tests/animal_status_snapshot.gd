extends Node2D
## Snapshot penanda status hewan: jalankan scene ini (F6). Menyimpan dua gambar ke tests/_snapshots/:
## animal_status_jauh.png (pemain jauh: hanya yang belum) dan animal_status_dekat.png (pemain dekat: semua).
## Data hewan sementara; StructureManager dan data peliharaan dipulihkan sebelum keluar.
const StatusMarker := preload("res://scripts/ui/animal_status_marker.gd")
const OUT_DIR := "res://tests/_snapshots"
const ZOOM := 3.0

var _view: SubViewport
var _saved_records: Array
var _saved_pet := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# SaveManager memuat save secara deferred saat start; tunggu dulu supaya data sementara tidak tertimpa.
	await get_tree().create_timer(0.6, true).timeout
	print("animal_status_snapshot: setup")
	DayCycle.is_running = false
	DayCycle.hour = 12
	var day := DayCycle.current_day
	_saved_records = StructureManager.records.duplicate(true)
	var p1 := GameState.p1()
	_saved_pet = {"pet_id": p1.pet_id, "pet_name": p1.pet_name, "pet_day": p1.pet_day, "pet_fed_day": p1.pet_fed_day}
	# SubViewport sendiri: tidak tertutup lapisan UI autoload (transisi/HUD).
	var view := SubViewport.new()
	view.size = Vector2i(320, 120)
	view.world_2d = World2D.new()
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(view)
	_view = view
	var bg := ColorRect.new()
	bg.color = Color("5d9b45")
	bg.position = Vector2(-200, -200)
	bg.size = Vector2(800, 500)
	view.add_child(bg)
	var ysort := Node2D.new()
	ysort.name = "YSort"
	ysort.y_sort_enabled = true
	view.add_child(ysort)
	# Barn: sapi (semua belum + susu siap), domba (makan+elus sudah, sikat belum), kambing anak, kuda.
	var barn := _record(9001, "barn", day, [
		{"name": "Moli", "species": "cow", "fed_day": 0, "pet_day": 0, "brush_day": 0, "ready": "cow_milk"},
		{"name": "Wolly", "species": "sheep", "fed_day": day, "pet_day": day, "brush_day": 0, "ready": ""},
		{"name": "Anak", "species": "goat", "fed_day": day, "pet_day": 0, "brush_day": day, "ready": "", "baby_days": 3},
		{"name": "Kilat", "species": "horse", "variant": "bay", "fed_day": 0, "pet_day": day, "brush_day": 0, "ready": ""},
	])
	var coop := _record(9002, "chicken_coop", day, [
		{"name": "Ciki", "species": "chicken", "fed_day": 0, "pet_day": 0, "ready": ""},
		{"name": "Kwek", "species": "duck", "fed_day": day, "pet_day": day, "ready": ""},
	])
	StructureManager.records.append(barn)
	StructureManager.records.append(coop)
	var x := 0.0
	for pair in [[9001, 1], [9001, 2], [9001, 3], [9002, 1], [9002, 2]]:
		var actor: CharacterBody2D = load("res://scripts/world/ranch_animal.gd").new()
		actor.uid = pair[0]
		actor.animal_id = pair[1]
		actor.home = Vector2(x, 0)
		ysort.add_child(actor)
		x += 44.0
	var horse: Area2D = load("res://scripts/world/horse_actor.gd").new()
	horse.uid = 9001
	horse.animal_id = 4
	horse.position = Vector2(x + 6, 0)
	ysort.add_child(horse)
	x += 50.0
	p1.pet_id = "cat"
	p1.pet_name = "Mochi"
	p1.pet_fed_day = 0
	p1.pet_day = day
	var pet := PetActor.new()
	pet.home = Vector2(x, 0)
	pet.position = pet.home
	ysort.add_child(pet)
	var camera := Camera2D.new()
	camera.position = Vector2(x * 0.5, -14)
	camera.zoom = Vector2.ONE
	view.add_child(camera)
	camera.make_current()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	await _capture("animal_status_jauh.png")
	StatusMarker.debug_force_near = true
	for node in ysort.get_children():
		var marker := node.get("_status") as Node2D
		if marker != null:
			marker.update_now()
	await _capture("animal_status_dekat.png")
	StatusMarker.debug_force_near = false
	StructureManager.records = _saved_records
	for key in _saved_pet:
		p1.set(key, _saved_pet[key])
	print("animal_status_snapshot: OK")
	get_tree().quit()

func _record(uid: int, item: String, day: int, animals: Array) -> Dictionary:
	var state := {"chickens": [], "eggs": 0, "next_id": 1, "last_day": day, "door": true}
	for info in animals:
		var animal: Dictionary = RanchHusbandry.ANIMAL_DEFAULTS.duplicate()
		animal.merge({"id": int(state.next_id), "variant": "white", "affection": 40}, true)
		animal.merge(info, true)
		state.chickens.append(animal)
		state.next_id = int(state.next_id) + 1
	return {"uid": uid, "item": item, "cell": [0, 0], "storage": [], "open": false, "job": {}, "ready": {}, "livestock": state}

func _capture(file: String) -> void:
	# Tunggu gelembung muncul (tween pantul 0,18 detik).
	await get_tree().create_timer(0.6, true).timeout
	var image := _view.get_texture().get_image()
	image.resize(image.get_width() * int(ZOOM), image.get_height() * int(ZOOM), Image.INTERPOLATE_NEAREST)
	var err := image.save_png(ProjectSettings.globalize_path(OUT_DIR.path_join(file)))
	print("animal_status_snapshot: %s -> %s" % [file, error_string(err)])
