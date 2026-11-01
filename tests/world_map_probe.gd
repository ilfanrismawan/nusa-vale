extends Node
## Probe tab Peta: buka buku tas di Ladang lewat aksi M, pilih beberapa area, cek isi dan
## ambil tangkapan layar ke res://scratch/world_map_*.png. Log: res://tests/world_map_probe.log.

var _log := PackedStringArray()
var _fail := 0


func say(text: String) -> void:
	print(text)
	_log.append(text)
	var f := FileAccess.open("res://tests/world_map_probe.log", FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(_log))


func check(ok: bool, what: String) -> void:
	if not ok:
		_fail += 1
	say("%s %s" % ["PASS" if ok else "FAIL", what])


func shot(file_name: String) -> void:
	await get_tree().create_timer(0.4, true, false, true).timeout
	RenderingServer.force_draw()
	var image := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("res://scratch")
	image.save_png("res://scratch/%s.png" % file_name)
	say("PROBE shot %s" % file_name)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	say("PROBE START")
	GameState.new_game()
	say("PROBE new_game ok")
	var scene: Node = load("res://scenes/world/farm.tscn").instantiate()
	say("PROBE farm instanced")
	get_tree().root.add_child(scene)
	say("PROBE farm added")
	for i in 6:
		await get_tree().physics_frame
	var player: Player = null
	for node in get_tree().get_nodes_in_group(Combat.PLAYER_GROUP):
		if node is Player:
			player = node
	check(player != null, "player di farm")
	if player == null:
		return _finish()
	var inv = player.ui_inventory
	say("PROBE inv=%s map=%s" % [inv, inv.get_node_or_null("%MapPage")])
	# Tekan M
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_M
	ev.keycode = KEY_M
	ev.pressed = true
	var map = inv.get_node("%MapPage")
	# Mesin lambat: beri waktu scene selesai siap, lalu tekan M dan tunggu sampai tas terbuka.
	for i in 20:
		await get_tree().process_frame
	Input.parse_input_event(ev)
	for i in 40:
		await get_tree().process_frame
		if inv.visible and map.visible:
			break
	var up := ev.duplicate()
	up.pressed = false
	Input.parse_input_event(up)
	await get_tree().process_frame
	check(inv.visible and map.visible, "M membuka tas di tab Peta")
	if not map.visible:
		inv._open()
		inv._show_map()
		await get_tree().process_frame
	check(map._selected != null and map._selected.area_id == "farm", "area awal = Ladang (posisi pemain)")
	check(map.get_node("%Pins").get_child_count() == 1, "satu pin pemain")
	check(map.area_for_scene("res://scenes/world/interior/town/shop.tscn").area_id == "town", "interior toko = Kota")
	check(map.area_for_scene("res://scenes/world/Forest.tscn").area_id == "forest", "Forest.tscn = Hutan")
	check(map.area_for_scene("res://scenes/world/cave/cave.tscn").area_id == "cave", "gua = Gua")
	check(map.neighbor(map._area_by_id("farm"), Vector2.RIGHT).area_id == "town", "kanan dari Ladang = Kota")
	check(map.neighbor(map._area_by_id("farm"), Vector2.DOWN).area_id == "ranch", "bawah dari Ladang = Ranch")
	check(map.neighbor(map._area_by_id("farm"), Vector2.LEFT).area_id == "forest", "kiri dari Ladang = Hutan")
	check(map.neighbor(map._area_by_id("farm"), Vector2.UP).area_id == "hill", "atas dari Ladang = Bukit")
	await shot("world_map_0_farm")
	DayCycle.hour = 10
	map.select_area("town")
	map._update_dynamic()
	check(map.get_node("%AreaName").text == "Kota", "detail Kota")
	check(map.get_node("%Body").get_child_count() > 3, "Kota punya isi detail")
	await shot("world_map_1_town")
	map.select_area("forest")
	check(map.get_node("%AreaStatus").text == "Terkunci", "Hutan terkunci di game baru")
	await shot("world_map_2_forest_locked")
	map.select_area("modern_city")
	check(map.get_node("%AreaName").text == "???", "Kota Modern tersembunyi")
	UnlockManager.unlock("cave")
	map.refresh()
	map.select_area("cave")
	map._update_dynamic()
	check(map.get_node("%AreaStatus").text == "Terbuka", "Gua terbuka setelah unlock")
	await shot("world_map_3_cave")
	map.set_filter("shop")
	check(map._area_by_id("forest").dimmed and not map._area_by_id("town").dimmed, "filter Toko meredupkan area tanpa toko")
	await shot("world_map_4_filter_shop")
	map.set_filter("")
	_finish()


func _finish() -> void:
	say("PROBE DONE fail=%d" % _fail)
	await get_tree().create_timer(5.0).timeout
	get_tree().quit(1 if _fail > 0 else 0)
