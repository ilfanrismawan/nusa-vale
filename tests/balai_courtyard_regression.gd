extends Node

## Balai Nadi (balai.tscn): masuk dari Town, jembatan ke Bale Agung, keluar kembali ke Town.
const BALE_STAND := Vector2(616, 432)

var failures := 0

func check(ok: bool, message: String) -> void:
	if ok: print("PASS: ",message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func _ready() -> void:
	if OS.get_environment("NUSA_SAVE_AUDIT") != "1" or not OS.get_user_data_dir().contains("nusa-save-audit-"):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	GameState.new_game()
	var access := (load("res://scenes/world/exterior/town/balai_access.tscn") as PackedScene).instantiate()
	check(ResourceUID.ensure_path(access.target_scene) == "res://scenes/world/balai_nadi/balai.tscn", "Town access leads to balai.tscn")
	access.free()
	var scene: Node2D = (load("res://scenes/world/balai_nadi/balai.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(scene)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var player := scene.get_node("Player/CharacterBody2D") as Player
	player.set_physics_process(false)
	check(scene.get_node("water") is TileMapLayer and scene.get_node("Bridge") is TileMapLayer, "Water and bridge are editable TileMapLayers")
	var spawn := player.global_transform
	spawn.origin = scene.get_node("spawn").global_position
	check(not player.test_move(spawn, Vector2.UP * (spawn.origin.y - BALE_STAND.y)), "Spawn to Bale Agung across the bridge is continuously walkable")
	var bridge := player.global_transform
	bridge.origin = Vector2(616, 640)
	check(player.test_move(bridge, Vector2.LEFT * 60) and player.test_move(bridge, Vector2.RIGHT * 60), "Player cannot walk from bridge into lake")
	var corner := player.global_transform
	corner.origin = Vector2(24, 870)
	check(player.test_move(corner, Vector2.LEFT * 40), "Map edge blocks walking into the void")
	player.global_position = BALE_STAND
	player.facing_direction = Vector2.UP
	await get_tree().physics_frame
	check(player._find_interactable() == scene.get_node("BaleAgung/BalaiInteractionArea"), "Interaction finds the Bale Agung contribution area")
	check(scene.get_node("ReturnTown").target_scene == "res://scenes/world/town.tscn", "South exit returns to village")
	var camera := player.get_node("Camera2D") as Camera2D
	check(camera.limit_left == 0 and camera.limit_top == 0 and camera.limit_right == 1280 and camera.limit_bottom == 912, "Camera stays inside the map")
	scene.queue_free()
	await get_tree().process_frame
	print("BALAI COURTYARD COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
