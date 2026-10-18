extends Node2D

## Gua Tambang (GDD 9). Satu scene untuk semua lantai: lantai 0 = lobi (pintu keluar, lift,
## Toko Combat, lubang ke lantai 1), lantai 1+ = ruang acak harian berisi batu, bijih, dan
## musuh. Pindah lantai membangun ulang isi scene ini di tempat (pemain co-op ikut semua).
## Tangga turun muncul dari batu yang dihancurkan (acak) atau setelah semua musuh kalah.
## Lantai arena (CaveData.bosses, GDD 8.2-C) berisi BossArena selama boss-nya belum kalah.

signal floor_built(floor_number: int)
signal stairs_revealed(position: Vector2)

const DATA: CaveData = preload("res://resources/cave/cave_data.tres")
const CAVE_TILES := preload("res://assets/farm_rpg/tileset/ext/Caves.png")
const ORE_SHEET := preload("res://assets/farm_rpg/objects/mine/stone with minerals.png")
const STAIRS_SHEET := preload("res://assets/farm_rpg/objects/exterior/Mine and Dungeon/Mine/Stairs.png")
const DOOR_SHEET := preload("res://assets/farm_rpg/objects/exterior/Mine and Dungeon/Mine/Door Mine.png")
const ROCK_SCENE := preload("res://scenes/objects/rock.tscn")
const SHOP_COUNTER := preload("res://scenes/world/exterior/object/ShopCounter.tscn")
const LIFT_MENU := preload("res://scripts/ui/cave_lift_menu.gd")
const FONT := preload("res://assets/fonts/m5x7.ttf")
const WINTER_POND := preload("res://scripts/world/winter_pond.gd")

const TILE := 16
## Ukuran ruang tetap (tile) supaya batas kamera co-op tetap benar di semua lantai.
const SIZE := Vector2i(40, 24)
## Baris pertama yang bisa dipijak (baris 0-2 = dinding atas dengan tebing).
const FLOOR_TOP := 3
## Tempat pemain tiba (di bawah tangga naik / pintu masuk).
const ARRIVAL_CELL := Vector2i(20, 4)
const LIFT_CELL := Vector2i(15, 3)
const LOBBY_HOLE_CELL := Vector2i(20, 13)
## Musuh tidak muncul sedekat ini (tile) dari titik tiba.
const SAFE_RADIUS := 6
## Lantai arena: baris garis kabut. Di atasnya (titik tiba, tangga naik, lift) aman.
const BOSS_GATE_ROW := 8

# Koordinat atlas Caves.png.
const T_GROUND := Vector2i(4, 4)
const T_WALL_TOP := Vector2i(9, 1)
const T_WALL_EDGE := Vector2i(9, 3)
const T_CLIFF := Vector2i(9, 4)
const T_WALL_BOTTOM := Vector2i(9, 0)
const T_WALL_LEFT := Vector2i(11, 1)
const T_WALL_RIGHT := Vector2i(8, 1)
const T_CORNER := {
	Vector2i(0, 1): Vector2i(7, 3), Vector2i(0, 2): Vector2i(7, 1),
	Vector2i(SIZE.x - 1, 1): Vector2i(4, 3), Vector2i(SIZE.x - 1, 2): Vector2i(4, 1),
	Vector2i(0, SIZE.y - 1): Vector2i(7, 0), Vector2i(SIZE.x - 1, SIZE.y - 1): Vector2i(4, 0),
}
const T_DECALS: Array[Vector2i] = [Vector2i(12, 3)]

var floor_number := 0
var stairs: Area2D
var rocks_left := 0
var enemies_left := 0
## Arena boss lantai ini (null bila bukan lantai arena atau boss sudah kalah).
var arena: BossArena
var _ground: TileMapLayer
var _walls: TileMapLayer
var _content: Node2D
var _bounds: StaticBody2D
var _title: Label
var _blocked: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _changing := false
var _ore_frames: Dictionary = {}
## Naik tiap build_floor; sinyal dari batu/musuh lantai lama diabaikan.
var _floor_token := 0

func _ready() -> void:
	# Gua gelap: jarak pandang musuh memakai dark_vision_scale (GDD 8.2-B2).
	add_to_group(Perception.DARK_GROUP)
	_build_static()
	DayCycle.is_running = true
	build_floor(clampi(GameState.cave.current_floor, 0, DATA.max_floor))
	for player in _players():
		player.refresh_world()
		var camera := player.get_node_or_null("Camera2D") as Camera2D
		if camera != null and not Coop.has_root():
			if camera.has_method("set_default_zoom"):
				camera.set_default_zoom(2.0)
			camera.reset_smoothing()

func _players() -> Array[Player]:
	var result: Array[Player] = []
	for candidate in find_children("*", "CharacterBody2D", true, false):
		if candidate is Player:
			result.append(candidate)
	return result

# ── Kerangka tetap ──────────────────────────────────────────────────

func _build_static() -> void:
	var tiles := TileSet.new()
	tiles.tile_size = Vector2i(TILE, TILE)
	tiles.add_custom_data_layer()
	tiles.set_custom_data_layer_name(0, "farmable")
	tiles.set_custom_data_layer_type(0, TYPE_BOOL)
	var source := TileSetAtlasSource.new()
	source.texture = CAVE_TILES
	source.texture_region_size = Vector2i(TILE, TILE)
	tiles.add_source(source, 0)
	_ground = TileMapLayer.new()
	_ground.name = "BaseLayerGround"
	_ground.z_index = -10
	_ground.tile_set = tiles
	add_child(_ground)
	_walls = TileMapLayer.new()
	_walls.name = "CaveWalls"
	_walls.z_index = -9
	_walls.tile_set = tiles
	add_child(_walls)
	_bounds = StaticBody2D.new()
	_bounds.name = "Walls"
	add_child(_bounds)
	_content = Node2D.new()
	_content.name = "FloorContent"
	_content.y_sort_enabled = true
	add_child(_content)
	_title = Label.new()
	_title.position = Vector2(24, 2)
	_title.z_index = -8
	_title.add_theme_font_override("font", FONT)
	_title.add_theme_font_size_override("font_size", 16)
	add_child(_title)

func _tile(layer: TileMapLayer, cell: Vector2i, atlas: Vector2i) -> void:
	var source := layer.tile_set.get_source(0) as TileSetAtlasSource
	if not source.has_tile(atlas):
		source.create_tile(atlas)
	layer.set_cell(cell, 0, atlas)

func _wall_rect(rect: Rect2) -> void:
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	shape.position = rect.get_center()
	_bounds.add_child(shape)

# ── Membangun lantai ────────────────────────────────────────────────

## Bangun ulang isi lantai. Tidak memindahkan pemain (lihat go_to_floor).
func build_floor(number: int) -> void:
	floor_number = number
	_floor_token += 1
	if GameState.cave.reach(number):
		Notify.say("Lift lantai %d aktif! Naik lift dari lobi gua untuk langsung kembali ke sini." % number)
	_rng.seed = GameState.cave.floor_seed(number)
	_blocked.clear()
	stairs = null
	arena = null
	rocks_left = 0
	enemies_left = 0
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	for child in _bounds.get_children():
		child.queue_free()
	_ground.clear()
	_walls.clear()
	_build_room()
	_title.text = "Gua - Lobi" if number == 0 else "Gua - Lantai %d" % number
	var boss := DATA.boss_for(number)
	if number == 0:
		_build_lobby()
	elif boss != null and not GameState.cave.is_boss_defeated(number):
		_build_boss_floor(boss)
	else:
		_build_mine_floor()
	floor_built.emit(number)

func _build_room() -> void:
	for x in SIZE.x:
		for y in SIZE.y:
			_tile(_ground, Vector2i(x, y), T_GROUND)
	for x in SIZE.x:
		_tile(_walls, Vector2i(x, 0), T_WALL_TOP)
		_tile(_walls, Vector2i(x, 1), T_WALL_EDGE)
		_tile(_walls, Vector2i(x, 2), T_CLIFF)
		_tile(_walls, Vector2i(x, SIZE.y - 1), T_WALL_BOTTOM)
	for y in range(1, SIZE.y):
		_tile(_walls, Vector2i(0, y), T_WALL_LEFT)
		_tile(_walls, Vector2i(SIZE.x - 1, y), T_WALL_RIGHT)
	for cell: Vector2i in T_CORNER:
		_tile(_walls, cell, T_CORNER[cell])
	var w := float(SIZE.x * TILE)
	var h := float(SIZE.y * TILE)
	_wall_rect(Rect2(0, 0, w, FLOOR_TOP * TILE))
	_wall_rect(Rect2(-8, 0, TILE + 8, h))
	_wall_rect(Rect2(w - TILE, 0, TILE + 8, h))
	_wall_rect(Rect2(0, h - TILE, w, TILE + 8))
	for cell in _reserved_cells():
		_blocked[cell] = true

## Sel di sekitar titik tiba selalu kosong supaya pemain tidak terkurung.
func _reserved_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for dx in range(-2, 3):
		for dy in range(-1, 3):
			cells.append(ARRIVAL_CELL + Vector2i(dx, dy))
	if DATA.is_lift_floor(floor_number) or floor_number == 0:
		cells.append(LIFT_CELL)
		cells.append(LIFT_CELL + Vector2i(1, 0))
	return cells

func _is_inside(cell: Vector2i) -> bool:
	return cell.x >= 1 and cell.x < SIZE.x - 1 and cell.y >= FLOOR_TOP and cell.y < SIZE.y - 1

func cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell * TILE) + Vector2(TILE, TILE) * 0.5

func cell_of(world_pos: Vector2) -> Vector2i:
	return Vector2i((to_local(world_pos) / TILE).floor())

func arrival_position() -> Vector2:
	return to_global(cell_center(ARRIVAL_CELL))

func _build_lobby() -> void:
	_add_exit_door()
	_add_lift()
	_add_hole(LOBBY_HOLE_CELL)
	var counter := SHOP_COUNTER.instantiate()
	counter.name = "CombatShop"
	counter.shop_data = DATA.shop
	counter.position = cell_center(Vector2i(31, 10))
	_content.add_child(counter)
	var sign_label := Label.new()
	sign_label.text = "Toko Combat"
	sign_label.position = cell_center(Vector2i(28, 5))
	sign_label.add_theme_font_override("font", FONT)
	_content.add_child(sign_label)

func _build_mine_floor() -> void:
	_add_ladder_up()
	if DATA.is_lift_floor(floor_number):
		_add_lift()
	if floor_number == DATA.lake_floor:
		_add_lake()
	_add_pillars()
	_add_decals()
	var band := DATA.band_for(floor_number)
	if band == null:
		return
	var free := _free_cells()
	var rock_total := mini(_rng.randi_range(band.rock_min, maxi(band.rock_min, band.rock_max)), free.size())
	for i in rock_total:
		_spawn_rock(band.pick_ore(_rng), _take_cell(free))
	var spawn_cells := free.filter(func(cell: Vector2i) -> bool:
		return cell.distance_to(ARRIVAL_CELL) >= SAFE_RADIUS)
	var enemy_total := mini(_rng.randi_range(band.enemy_min, maxi(band.enemy_min, band.enemy_max)), spawn_cells.size())
	for i in enemy_total:
		if band.enemies.is_empty():
			break
		var data: EnemyData = band.enemies[_rng.randi() % band.enemies.size()]
		var cell: Vector2i = spawn_cells.pop_at(_rng.randi() % spawn_cells.size())
		var enemy := Enemy.spawn(data, _content, to_global(cell_center(cell)))
		if enemy != null:
			enemies_left += 1
			enemy.died.connect(_on_enemy_died.bind(_floor_token))
	if floor_number >= DATA.max_floor and DiscoveryManager.discover("cave_floor_%d" % floor_number):
		Notify.say("Lantai %d adalah lantai terdalam untuk saat ini. Lantai 21 dan seterusnya menyusul." % floor_number)

## Lantai arena boss: lapang tanpa batu dan pilar; garis kabut memisahkan area tiba dari arena.
func _build_boss_floor(boss: BossData) -> void:
	_add_ladder_up()
	if DATA.is_lift_floor(floor_number):
		_add_lift()
	_add_decals()
	_title.text = "Gua - Lantai %d: %s" % [floor_number, boss.title]
	arena = BossArena.new()
	arena.name = "BossArena"
	_content.add_child(arena)
	var top := BOSS_GATE_ROW * TILE
	arena.setup(boss, self, Rect2(TILE, top, (SIZE.x - 2) * TILE, (SIZE.y - 1) * TILE - top))
	arena.boss_defeated.connect(_on_boss_defeated.bind(_floor_token))

func _on_boss_defeated(boss: BossData, token: int) -> void:
	if token != _floor_token:
		return
	if DiscoveryManager.discover("boss_cleared_%d" % boss.floor_number):
		Notify.say("Lift lantai %d kini checkpoint aman. Lantai ini kembali jadi lantai tambang mulai kunjungan berikutnya." % boss.floor_number)

func _free_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for x in range(1, SIZE.x - 1):
		for y in range(FLOOR_TOP, SIZE.y - 1):
			var cell := Vector2i(x, y)
			if not _blocked.has(cell):
				cells.append(cell)
	return cells

func _take_cell(cells: Array[Vector2i]) -> Vector2i:
	return cells.pop_at(_rng.randi() % cells.size())

## Pilar batu 1-3 tile (atas + tebing) sebagai rintangan. Dijaga agar tidak saling menempel.
func _add_pillars() -> void:
	var count := _rng.randi_range(3, 7)
	for i in count:
		var length := _rng.randi_range(1, 3)
		var origin := Vector2i(_rng.randi_range(3, SIZE.x - 4 - length), _rng.randi_range(FLOOR_TOP + 4, SIZE.y - 4))
		var ok := true
		for dx in range(-1, length + 1):
			for dy in range(-1, 3):
				var cell := origin + Vector2i(dx, dy)
				if _blocked.has(cell) or cell.distance_to(ARRIVAL_CELL) < 4:
					ok = false
		if not ok:
			continue
		for k in length:
			var column := 0 if length == 1 else (1 if k == 0 else (3 if k == length - 1 else 2))
			_tile(_walls, origin + Vector2i(k, 0), Vector2i(column, 3))
			_tile(_walls, origin + Vector2i(k, 1), Vector2i(column, 4))
			_blocked[origin + Vector2i(k, 0)] = true
			_blocked[origin + Vector2i(k, 1)] = true
		_wall_rect(Rect2(Vector2(origin * TILE) + Vector2(1, 4), Vector2(length * TILE - 2, TILE * 2 - 6)))

## Danau bawah tanah: spot pancing yang tetap terbuka di Musim Dingin (GDD 5).
func _add_lake() -> void:
	var lake: Node2D = WINTER_POND.new()
	lake.name = "CaveLake"
	lake.size_tiles = DATA.lake_size
	lake.location_id = "cave_lake"
	lake.steam = false
	lake.tint = Color(0.7, 0.75, 0.95)
	lake.position = Vector2(DATA.lake_cell * TILE)
	_content.add_child(lake)
	for x in range(-1, DATA.lake_size.x + 1):
		for y in range(-1, DATA.lake_size.y + 1):
			_blocked[DATA.lake_cell + Vector2i(x, y)] = true
	if DiscoveryManager.discover("cave_lake"):
		Notify.say("Danau bawah tanah! Airnya tidak membeku, bisa dipancing sepanjang tahun.")

func _add_decals() -> void:
	for i in _rng.randi_range(4, 10):
		var cell := Vector2i(_rng.randi_range(2, SIZE.x - 3), _rng.randi_range(FLOOR_TOP + 1, SIZE.y - 3))
		if not _blocked.has(cell):
			_tile(_walls, cell, T_DECALS[_rng.randi() % T_DECALS.size()])

# ── Batu dan bijih ─────────────────────────────────────────────────

func _spawn_rock(item_id: String, cell: Vector2i) -> Choppable:
	var ore := DATA.ore(item_id)
	if ore == null:
		return null
	var rock := (ore.scene if ore.scene != null else ROCK_SCENE).instantiate() as Choppable
	rock.name = "CaveRock_%d_%d" % [cell.x, cell.y]
	rock.persistent = false
	rock.drop_item_id = ore.item_id
	rock.health = ore.health
	rock.drop_count = _rng.randi_range(ore.drop_min, maxi(ore.drop_min, ore.drop_max))
	rock.resource_size = Choppable.ResourceSize.SMALL
	rock.minimum_tool_tier = ore.minimum_tool_tier
	if ore.scene == null:
		rock.scale = Vector2.ONE
		var sprite := rock.get_node("AnimatedSprite2D") as AnimatedSprite2D
		sprite.sprite_frames = _ore_frames_for(ore.sprite_column)
		sprite.animation = &"idle"
		var shape := rock.get_node("CollisionShape2D") as CollisionShape2D
		shape.scale = Vector2(0.6, 0.6)
	rock.position = cell_center(cell)
	rock.set_meta("cave_cell", cell)
	_blocked[cell] = true
	rock.tree_exiting.connect(_on_rock_removed.bind(rock, _floor_token))
	_content.add_child(rock)
	rocks_left += 1
	return rock

## Animasi batu bijih dari `stone with minerals.png`: baris 0 kolom bijih, kolom 10 = kilat putih.
func _ore_frames_for(column: int) -> SpriteFrames:
	if _ore_frames.has(column):
		return _ore_frames[column]
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	var normal := _ore_region(Rect2(column * TILE, 0, TILE, TILE))
	var flash := _ore_region(Rect2(160, 0, TILE, TILE))
	for anim: StringName in [&"idle", &"chopping", &"stump"]:
		frames.add_animation(anim)
		frames.set_animation_loop(anim, false)
		frames.set_animation_speed(anim, 8.0)
	frames.add_frame(&"idle", normal)
	frames.add_frame(&"chopping", normal)
	frames.add_frame(&"chopping", flash)
	frames.add_frame(&"stump", flash)
	_ore_frames[column] = frames
	return frames

func _ore_region(region: Rect2) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = ORE_SHEET
	texture.region = region
	return texture

func _on_rock_removed(rock: Choppable, token: int) -> void:
	if not rock.is_destroyed or token != _floor_token:
		return
	rocks_left -= 1
	var cell: Vector2i = rock.get_meta("cave_cell")
	_blocked.erase(cell)
	if stairs != null or floor_number >= DATA.max_floor:
		return
	if randf() < DATA.stairs_chance or (rocks_left <= 0 and enemies_left <= 0):
		_reveal_stairs.call_deferred(cell)

func _on_enemy_died(enemy: Enemy, token: int) -> void:
	if token != _floor_token:
		return
	enemies_left -= 1
	if enemies_left > 0 or stairs != null or floor_number >= DATA.max_floor:
		return
	var cell := cell_of(enemy.global_position)
	if not _is_inside(cell) or _blocked.has(cell):
		cell = _nearest_free(cell)
	_reveal_stairs.call_deferred(cell)
	if DiscoveryManager.discover("cave_all_monsters"):
		Notify.say("Semua monster di lantai ini kalah. Tangga turun muncul!")

func _nearest_free(from: Vector2i) -> Vector2i:
	var best := ARRIVAL_CELL + Vector2i(0, 3)
	var best_distance := INF
	for cell in _free_cells():
		var distance := cell.distance_squared_to(from)
		if distance < best_distance:
			best_distance = distance
			best = cell
	return best

# ── Tangga, lift, pintu ────────────────────────────────────────────

func _reveal_stairs(cell: Vector2i) -> void:
	if stairs != null or not is_inside_tree():
		return
	stairs = _add_hole(cell)
	stairs_revealed.emit(stairs.global_position)
	if DiscoveryManager.discover("cave_stairs"):
		Notify.say("Tangga turun ditemukan! Injak lubangnya untuk turun ke lantai berikutnya.")

## Lubang tangga turun ke lantai berikutnya.
func _add_hole(cell: Vector2i) -> Area2D:
	var hole := Area2D.new()
	hole.name = "StairsDown"
	hole.position = cell_center(cell)
	hole.z_index = -8
	hole.z_as_relative = false
	var sprite := Sprite2D.new()
	sprite.texture = STAIRS_SHEET
	sprite.region_enabled = true
	sprite.region_rect = Rect2(0, 16, 16, 16)
	hole.add_child(sprite)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 5.0
	shape.shape = circle
	hole.add_child(shape)
	hole.body_entered.connect(_on_hole_entered)
	_blocked[cell] = true
	_content.add_child(hole)
	return hole

func _on_hole_entered(body: Node2D) -> void:
	if body is Player and not body.is_input_locked():
		go_to_floor.call_deferred(floor_number + 1)

func _add_ladder_up() -> void:
	var ladder := _interactable("LadderUp", cell_center(ARRIVAL_CELL) + Vector2(0, -24), Rect2(16, 0, 16, 32), STAIRS_SHEET, Vector2(14, 12))
	ladder.set_meta("cave_action", "up")

func _add_exit_door() -> void:
	var door := _interactable("ExitDoor", cell_center(ARRIVAL_CELL) + Vector2(0, -40), Rect2(32, 0, 32, 32), DOOR_SHEET, Vector2(24, 14))
	door.set_meta("cave_action", "exit")

func _add_lift() -> void:
	var lift := _interactable("Lift", cell_center(LIFT_CELL) + Vector2(8, -24), Rect2(0, 0, 32, 32), DOOR_SHEET, Vector2(24, 14))
	lift.set_meta("cave_action", "lift")

## Objek dinding yang dipakai dengan tombol interaksi (Player._find_interactable).
func _interactable(node_name: String, pos: Vector2, region: Rect2, texture: Texture2D, hit_size: Vector2) -> Area2D:
	var area := CaveInteractable.new()
	area.name = node_name
	area.cave = self
	area.position = pos
	area.z_index = -8
	area.z_as_relative = false
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.region_enabled = true
	sprite.region_rect = region
	area.add_child(sprite)
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = hit_size
	shape.shape = box
	# Kotak sentuh menjulur sedikit ke lantai di bawah sprite supaya bisa dipakai dari depannya.
	shape.position = Vector2(0, region.size.y * 0.5 + 2)
	area.add_child(shape)
	_content.add_child(area)
	return area

func use_object(action: String, player: Player) -> void:
	if player == null or player.is_input_locked() or _changing:
		return
	match action:
		"up":
			go_to_floor(0)
		"exit":
			GameState.cave.current_floor = 0
			RoomDoor.travel(player, DATA.exit_scene, DATA.exit_spawn)
		"lift":
			var menu := LIFT_MENU.new() as CanvasLayer
			menu.set("cave", self)
			menu.set("player", player)
			Coop.ui_parent(player).add_child(menu)

## Pindah lantai di tempat: layar gelap, bangun ulang, pemain di gua ini dipindah ke titik tiba.
func go_to_floor(number: int) -> void:
	if _changing or not is_inside_tree():
		return
	number = clampi(number, 0, DATA.max_floor)
	_changing = true
	await Transition.fade_action(func() -> void:
		build_floor(number)
		_place_players())
	_changing = false

func _place_players() -> void:
	var players := _players()
	var count := float(players.size())
	for i in players.size():
		var body := players[i]
		var pos := arrival_position() + Vector2((float(i) - (count - 1.0) * 0.5) * 18.0, 0.0)
		var root := body.get_parent() as Node2D
		if root != null and root != self:
			root.global_position = pos
			body.position = Vector2.ZERO
		else:
			body.global_position = pos
		body.velocity = Vector2.ZERO
		var camera: Camera2D = Coop.root.camera_of(body.player_index) if Coop.has_root() else body.get_node_or_null("Camera2D") as Camera2D
		if camera != null:
			camera.global_position = body.global_position
			camera.reset_smoothing()


class CaveInteractable extends Area2D:
	var cave: Node

	func _ready() -> void:
		set_meta("player_interaction", true)

	func interact(player: Player = null) -> void:
		if player == null:
			player = RoomDoor.player()
		if cave != null:
			cave.use_object(str(get_meta("cave_action", "")), player)
