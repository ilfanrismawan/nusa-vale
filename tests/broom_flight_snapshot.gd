extends Node2D
## Snapshot sapu terbang (GDD 10): jalankan scene ini (F6). Memuat farm.tscn, menaruh pemain di
## belakang pohon, lalu menyimpan ke tests/_snapshots/:
##   broom_1_jalan.png   (jalan kaki di belakang pohon: tertutup tajuk)
##   broom_2_terbang.png (melayang di belakang pohon: di atas tajuk, bayangan di tanah)
##   broom_3_kilau.png   (terbang bergerak: jejak kilau di ekor sapu)
## Tidak menyimpan game; sapu sementara dibuang lagi dari tas sebelum keluar.
const OUT_DIR := "res://tests/_snapshots"
const ZOOM := 2

var _player: Player

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().create_timer(0.8, true).timeout
	DayCycle.is_running = false
	DayCycle.hour = 12
	var farm: Node = load("res://scenes/world/farm.tscn").instantiate()
	add_child(farm)
	await get_tree().create_timer(1.0, true).timeout
	var players := get_tree().get_nodes_in_group(Combat.PLAYER_GROUP)
	if players.is_empty():
		print("broom_snapshot: GAGAL tidak ada pemain")
		get_tree().quit(1)
		return
	_player = players[0] as Player
	var tree := _find_tree(farm, _player.global_position)
	if tree == null:
		print("broom_snapshot: GAGAL tidak ada pohon")
		get_tree().quit(1)
		return
	print("broom_snapshot: pohon ", tree.name, " di ", tree.global_position)
	# Kaki pemain sedikit di utara pangkal pohon = di belakang tajuk.
	_player.global_position = tree.global_position + Vector2(0, -6)
	_player.velocity = Vector2.ZERO
	_player.update_facing_direction(Vector2.RIGHT, true)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	await _capture("broom_1_jalan.png", 0.5)
	var added: bool = not _player.data.has_item("flying_broom")
	if added:
		_player.data.add_item_silent("flying_broom", 1)
	var broom: ItemData = GameState._resolve_item("flying_broom")
	print("broom_snapshot: naik = ", _player.mount_vehicle(broom, true))
	_player.global_position = tree.global_position + Vector2(0, -6)
	await _capture("broom_2_terbang.png", 1.0)
	# Geser pemain ke kanan sebentar (seperti terbang) dan nyalakan kilau tiap frame.
	var sparkles := _player.find_child("BroomSparkles", true, false) as CPUParticles2D
	_player.global_position += Vector2(-40, 0)
	for i in 30:
		_player.global_position += Vector2(1.4, 0)
		if sparkles != null:
			sparkles.emitting = true
		await get_tree().process_frame
	await _capture("broom_3_kilau.png", 0.0)
	_player.dismount_vehicle(true)
	if added:
		_player.data.remove_item("flying_broom", 1)
	_player.data.riding_vehicle_id = ""
	print("broom_snapshot: OK")
	get_tree().quit()

func _find_tree(root: Node, near: Vector2) -> Node2D:
	var best: Node2D
	var best_d := INF
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		var script := n.get_script() as Script
		if script == null or not script.resource_path.ends_with("choppable.gd"):
			continue
		if n.get("_canopy") == null or not (n as Node2D).is_visible_in_tree():
			continue
		var d := (n as Node2D).global_position.distance_to(near)
		if d < best_d:
			best_d = d
			best = n
	return best

func _capture(file: String, wait: float) -> void:
	if wait > 0.0:
		await get_tree().create_timer(wait, true).timeout
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	# Potong 240x160 di sekitar pemain (layar 854x480, kamera mengikuti pemain).
	var size := image.get_size()
	var screen_pos: Vector2 = _player.get_global_transform_with_canvas().origin
	var k := float(size.x) / get_viewport().get_visible_rect().size.x
	screen_pos *= k
	var rect := Rect2i(int(screen_pos.x - 120 * k), int(screen_pos.y - 110 * k), int(240 * k), int(160 * k))
	rect = rect.intersection(Rect2i(Vector2i.ZERO, size))
	if rect.size.x > 0 and rect.size.y > 0:
		image = image.get_region(rect)
	if k > 1.01:
		image.resize(240, 160, Image.INTERPOLATE_NEAREST)
	image.resize(image.get_width() * ZOOM, image.get_height() * ZOOM, Image.INTERPOLATE_NEAREST)
	var err := image.save_png(ProjectSettings.globalize_path(OUT_DIR.path_join(file)))
	print("broom_snapshot: %s -> %s" % [file, error_string(err)])
