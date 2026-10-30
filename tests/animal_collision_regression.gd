extends Node

## Tes collision hewan: pet, serangga darat, satwa liar darat, dan hewan ternak tidak menembus
## penghalang layer 1 (StaticBody2D seperti bangunan/pagar), titik rumah yang tertutup objek
## digeser ke titik kosong, pet tetap bisa dielus lewat area interaksinya, serangga terbang dan
## burung yang kabur tetap boleh melintas. Tidak menulis slot save.

const WALL_LEFT := 100.0
const WALL_RIGHT := 108.0
const RUN_FRAMES := 240

var failures := 0
var _world: Node2D

func check(value: bool, label: String) -> void:
	if value:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func _wall() -> void:
	var wall := StaticBody2D.new()
	wall.name = "Wall"
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(WALL_RIGHT - WALL_LEFT, 400)
	shape.shape = rect
	wall.add_child(shape)
	wall.position = Vector2((WALL_LEFT + WALL_RIGHT) * 0.5, 0)
	_world.add_child(wall)

func _inside_wall(x: float, radius: float) -> bool:
	return x + radius > WALL_LEFT and x - radius < WALL_RIGHT

## Jalankan fisika dan catat posisi x terjauh tiap node.
func _run(nodes: Array[Node2D], frames: int = RUN_FRAMES) -> Dictionary:
	var max_x := {}
	for node in nodes:
		max_x[node] = node.global_position.x
	for i in frames:
		await get_tree().physics_frame
		for node in nodes:
			if is_instance_valid(node):
				max_x[node] = maxf(max_x[node], node.global_position.x)
	return max_x

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_environment("NUSA_SAVE_AUDIT") != "1" or not OS.get_user_data_dir().replace("\\", "/").contains("nusa-save-audit-"):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	GameState.new_game()
	DayCycle.current_day = 1
	DayCycle.hour = 9
	DayCycle.is_running = true
	_world = Node2D.new()
	_world.name = "AnimalCollisionWorld"
	add_child(_world)
	_wall()
	await get_tree().physics_frame
	await get_tree().physics_frame

	# Pet: badan fisik terhalang, area interaksi tetap di layer pemain.
	GameState.p1().load_pet({"pet_id": "dog_brown", "pet_name": "Belang"})
	var pet := PetActor.new()
	pet.home = Vector2(80, 0)
	pet.position = pet.home
	_world.add_child(pet)
	pet.settle_home()
	check(pet is CharacterBody2D and pet.collision_mask & 1 != 0 and pet.collision_layer == 0, "pet is a physics body masked to world obstacles and does not block players")
	var query := PhysicsPointQueryParameters2D.new()
	query.position = pet.global_position + Vector2(0, -5)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = 1 << 9
	await get_tree().physics_frame
	var hits := _world.get_world_2d().direct_space_state.intersect_point(query, 4)
	check(hits.any(func(hit: Dictionary) -> bool: return hit.collider.get_parent() == pet), "pet keeps its interaction area for petting")
	pet._target = Vector2(160, 0)
	pet._wait = 0.0

	# Serangga darat dan terbang.
	var ant: Node2D = load("res://scripts/world/bug_critter.gd").new()
	ant.setup(load("res://resources/bugs/ant.tres"))
	_world.add_child(ant)
	ant.place(Vector2(90, 30))
	ant._target = Vector2(160, 30)
	ant._wait = 0.0
	var moth: Node2D = load("res://scripts/world/bug_critter.gd").new()
	moth.setup(load("res://resources/bugs/monarch.tres"))
	_world.add_child(moth)
	moth.place(Vector2(90, 60))
	moth._target = Vector2(130, 60)
	moth._wait = 0.0

	# Satwa liar darat.
	var fox := WildAnimal.new()
	fox.setup(load("res://resources/wildlife/fox_red.tres"))
	_world.add_child(fox)
	fox.place(Vector2(80, -40))
	fox._set_mode(WildAnimal.Mode.WANDER)
	fox._target = Vector2(160, -40)

	# Hewan ternak (kandang dalam ruangan supaya tidak butuh peta ladang).
	StructureManager.records.assign([{"uid": 1, "item": "barn", "cell": [50, 50], "storage": [], "open": false, "job": {}, "ready": {}}])
	GameState.money = 100000
	check(StructureManager.buy_animal(1, "cow", "Sari").ok, "cow purchased for collision test")
	var state := StructureManager.coop_state(StructureManager.record_for(1))
	state.door = false
	var cow: CharacterBody2D = load("res://scripts/world/ranch_animal.gd").new()
	cow.uid = 1
	cow.animal_id = int(state.chickens[0].id)
	cow.indoors = true
	cow.home = Vector2(80, -80)
	# Area jalan sengaja melewati dinding: tujuan di seberang harus tetap terhalang.
	cow.roam_rect = Rect2(70, -90, 90, 20)
	_world.add_child(cow)
	check(cow.motion_mode == CharacterBody2D.MOTION_MODE_FLOATING, "ranch animal uses top-down floating motion")

	# Rumah yang tertutup penghalang digeser ke titik kosong.
	var blocked_pet := PetActor.new()
	blocked_pet.home = Vector2(104, 120)
	blocked_pet.position = blocked_pet.home
	_world.add_child(blocked_pet)
	blocked_pet.settle_home()
	check(not _inside_wall(blocked_pet.home.x, PetActor.FEET_RADIUS), "pet home inside an obstacle moves to a free spot")
	blocked_pet.queue_free()
	var blocked_cow: CharacterBody2D = load("res://scripts/world/ranch_animal.gd").new()
	blocked_cow.uid = 1
	blocked_cow.animal_id = cow.animal_id
	blocked_cow.indoors = true
	blocked_cow.home = Vector2(104, 150)
	blocked_cow.roam_rect = Rect2(blocked_cow.home, Vector2.ONE)
	_world.add_child(blocked_cow)
	check(not _inside_wall(blocked_cow.home.x, 4.0), "ranch animal home inside an obstacle moves to a free spot")
	blocked_cow.queue_free()

	var tracked: Array[Node2D] = [pet, ant, moth, fox, cow]
	var max_x: Dictionary = await _run(tracked)
	check(max_x[pet] + PetActor.FEET_RADIUS <= WALL_LEFT + 0.5, "pet stops at the wall (max x %.1f)" % max_x[pet])
	check(max_x[ant] <= WALL_LEFT, "crawling bug stops at the wall (max x %.1f)" % max_x[ant])
	check(max_x[moth] > WALL_RIGHT, "flying bug still flies over obstacles (max x %.1f)" % max_x[moth])
	check(max_x[fox] + 3.0 <= WALL_LEFT + 0.5, "ground wildlife stops at the wall (max x %.1f)" % max_x[fox])
	check(max_x[cow] + 4.0 <= WALL_LEFT + 0.5, "ranch animal never crosses the wall (max x %.1f)" % max_x[cow])

	# Serangga darat kabur ke arah dinding: belok, tidak menembus.
	var cricket: Node2D = load("res://scripts/world/bug_critter.gd").new()
	cricket.setup(load("res://resources/bugs/cricket.tres"))
	_world.add_child(cricket)
	cricket.place(Vector2(94, -140))
	cricket._target = cricket._flee_target(Vector2.RIGHT)
	cricket._flee = 0.7
	check(not _is_blocked(cricket, cricket._target), "fleeing crawling bug picks a path that is not through the wall")
	var flee_x: Dictionary = await _run([cricket] as Array[Node2D], 60)
	check(flee_x[cricket] <= WALL_LEFT, "fleeing crawling bug does not cross the wall (max x %.1f)" % flee_x[cricket])

	print("ANIMAL COLLISION REGRESSION COMPLETE: failures=%d" % failures)
	DayCycle.is_running = false
	get_tree().quit(1 if failures else 0)

func _is_blocked(node: Node2D, target: Vector2) -> bool:
	return preload("res://scripts/world/animal_physics.gd").is_blocked(node, node.global_position, target)
