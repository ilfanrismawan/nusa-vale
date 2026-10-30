extends Node

## Warga punya rumah: pagi/malam di interior rumahnya, siang bekerja di Town, berjalan lewat pintu
## tanpa menabrak; pintu toko/klinik/rumah terkunci di luar jam buka (ServiceHours).

const HOMES := {
	"bahar": ["house_blue", "res://scenes/world/interior/town/house_blue.tscn", 8],
	"bima": ["blacksmith", "res://scenes/world/interior/town/blacksmith.tscn", 8],
	"damar": ["house_brick", "res://scenes/world/interior/town/house_brick.tscn", 8],
	"darmi": ["house_west", "res://scenes/world/interior/town/house_west.tscn", 8],
	"joko": ["warung", "res://scenes/world/interior/town/warung.tscn", 8],
	"kirana": ["house_pink", "res://scenes/world/interior/town/house_pink.tscn", 8],
	"ratih": ["herbal_house", "res://scenes/world/interior/town/herbal_house.tscn", 8],
	"rian": ["house_tall", "res://scenes/world/interior/town/house_tall.tscn", 7],
}

var failures := 0

func check(ok: bool, label: String) -> void:
	if ok:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func walk(actor: VillageNPC) -> bool:
	var stalled := 0
	for step in 12000:
		if not actor._is_walking:
			return actor.global_position.distance_to(actor._target_pos) <= 3.0
		var before := actor.global_position
		actor._physics_process(1.0 / 60.0)
		var moved := before.distance_to(actor.global_position)
		if moved > 2.0:
			push_error("Unexpected NPC teleport")
			return false
		stalled = stalled + 1 if moved < 0.01 else 0
		if stalled > 320:
			print("BLOCKED: %s at %s towards %s (goal %s)" % [actor.npc_id, actor.global_position, actor._active_path[0], actor._target_pos])
			return false
	return false

func set_time(hour: int, minute: int = 0) -> void:
	DayCycle.hour = hour
	DayCycle.minute = minute

## Scene tanpa pemain dan tanpa aktor dinamis lain; hanya presenter + aktor jadwal.
func open(path: String) -> Node:
	var scene: Node = load(path).instantiate()
	var player := scene.get_node_or_null("Player")
	if player != null:
		player.free()
	for body in scene.find_children("*", "CharacterBody2D", true, false):
		if not body is VillageNPC:
			body.free()
	add_child(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	var presenter := scene.get_node("NPCMapPresenter")
	presenter.set_process(false)
	for actor: VillageNPC in presenter.actors.values():
		actor.set_physics_process(false)
	await get_tree().physics_frame
	return scene

func _ready() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").contains("nusa-save-audit-"):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	GameState.new_game()
	DayCycle.is_running = false
	DayCycle.current_day = 2
	GameState.weather.current = "sunny"

	for npc: String in HOMES:
		var home: String = HOMES[npc][0]
		var room_path: String = HOMES[npc][1]
		var work_hour: int = HOMES[npc][2]
		var resident: Dictionary = NPCDatabase.residents[npc]
		check(resident.home_map == home and bool(resident.get("anchored", false)) == (npc == "darmi"), npc + " lives in " + home)
		check(NPCDatabase.schedule_entry(npc, 6, 30, false).map == home, npc + " is home in the morning")
		check(NPCDatabase.schedule_entry(npc, 23, 0, false).map == home and NPCDatabase.schedule_entry(npc, 23, 0, false).activity == "sleeping", npc + " sleeps at home")
		check(NPCDatabase.schedule_entry(npc, 10, 0, false).map == "town", npc + " works in Town by day")

		# Pagi di rumah, lalu keluar lewat pintu.
		set_time(6, 30)
		var room := await open(room_path)
		var presenter := room.get_node("NPCMapPresenter")
		check(presenter.actors.has(npc), npc + " appears inside " + home)
		if presenter.actors.has(npc):
			var inside: VillageNPC = presenter.actors[npc]
			check(walk(inside), npc + " walks from the door to the home point")
			set_time(work_hour, 0)
			presenter.refresh()
			check(presenter.departures.has(npc) and walk(inside), npc + " walks back to the door to go to work")
			presenter._process(0)
			check(not presenter.actors.has(npc), npc + " leaves " + home)
		room.queue_free()
		await get_tree().process_frame

		# Siang di Town: datang dari pintu rumah ke tempat kerja, malam pulang.
		set_time(10, 0)
		var town := await open("res://scenes/world/town.tscn")
		presenter = town.get_node("NPCMapPresenter")
		var actor: VillageNPC = presenter.actors.get(npc)
		check(actor != null, npc + " is in Town at 10.00")
		if actor != null:
			var door: Vector2 = town.get_node("NPCPaths").gateway(home, npc)
			# Mbah Darmi (anchored) langsung duduk di terasnya; yang lain berjalan dari pintu rumah.
			if npc == "darmi":
				check(actor.global_position.distance_to(town.get_node("NPCPoints/darmi_porch").global_position) < 2.0, "darmi is seated at her porch")
			else:
				check(actor._active_path.size() > 0 or actor.global_position.distance_to(door) < 4.0, npc + " arrives from the home door")
			check(walk(actor), npc + " reaches the work point without collisions")
			set_time(23, 0)
			presenter.refresh()
			check(presenter.departures.has(npc) and walk(actor), npc + " walks home at night")
			presenter._process(0)
			check(not presenter.actors.has(npc), npc + " leaves Town at night")
		town.queue_free()
		await get_tree().process_frame

	# Jam buka pintu.
	DayCycle.current_day = 2 # Selasa
	check(ServiceHours.service_for_scene("res://scenes/world/interior/town/house_blue.tscn") == "house", "resident homes use house hours")
	check(ServiceHours.service_for_scene("res://scenes/world/interior/school_v2.tscn") == "school", "school door maps to school hours")
	check(ServiceHours.service_for_scene("res://scenes/world/interior/eep_home.tscn") == "", "Eep's ranch shop follows Eep, not a door lock")
	check(ServiceHours.is_open("shop", 10) and not ServiceHours.is_open("shop", 8) and not ServiceHours.is_open("shop", 17), "general store opens 09.00-17.00")
	check(not ServiceHours.is_open("shop", 10, 3), "general store closed on Wednesday")
	check(not ServiceHours.is_open("house", 23) and ServiceHours.is_open("house", 10), "homes locked at night")
	check(ServiceHours.is_open("clinic", 9) and not ServiceHours.is_open("clinic", 16), "clinic opens 08.00-16.00")
	print("NPC HOMES COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
