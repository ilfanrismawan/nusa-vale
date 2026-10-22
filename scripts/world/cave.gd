extends Node2D

## Gua Tambang (GDD 9). Satu scene untuk semua lantai: lantai 0 = lobi (pintu keluar, lift,
## Toko Combat, lubang ke lantai 1), lantai 1+ = ruang acak harian berisi batu, bijih, dan
## musuh. Pindah lantai membangun ulang isi scene ini di tempat (pemain co-op ikut semua).
## Tangga turun muncul dari batu yang dihancurkan (acak) atau setelah semua musuh kalah.
## Lantai arena (CaveData.bosses, GDD 8.2-C) berisi BossArena selama boss-nya belum kalah.
##
## Bagian tetap ada sebagai node di cave.tscn dan bisa diedit di editor:
## - BaseLayerGround / CaveWalls: bentuk ruang (tileset resources/world/cave_tileset.tres).
##   Setiap lantai mulai dari ubin yang dilukis di editor, lalu pilar dan retakan acak ditambahkan.
## - Walls: tabrakan batas ruang; PillarWalls: tabrakan pilar acak (dibuat ulang tiap lantai).
## - FloorTitle: judul lantai; Lobby: isi lantai 0 (pintu keluar, lift, lubang, Toko Combat).
## Isi lantai tambang (batu, bijih, musuh, pilar) tetap acak harian dan masuk ke FloorContent.

signal floor_built(floor_number: int)
signal stairs_revealed(position: Vector2)

const DATA: CaveData = preload("res://resources/cave/cave_data.tres")
const ORE_SHEET := preload("res://assets/farm_rpg/objects/mine/stone with minerals.png")
const ROCK_SCENE := preload("res://scenes/objects/rock.tscn")
const LIFT_MENU := preload("res://scripts/ui/cave_lift_menu.gd")
const WINTER_POND := preload("res://scripts/world/winter_pond.gd")
const FLOOR_BADGE := preload("res://scripts/ui/cave_floor_badge.gd")
const LOBBY_ICON := preload("res://resources/icons/icon_pickaxe_wood.tres")
const LOBBY_ACCENT := Color(0.9, 0.7, 0.3)

## Ubin aset gua memakai grid 16 px; geometri ruangan tetap dilukis di TileMap.
const TILE := 16
@export_group("Layout ruangan")
## Bila ukuran diubah, sesuaikan TileMap, Walls, dan batas kamera di scene juga.
@export var room_size: Vector2i = Vector2i(40, 24)
@export_range(1, 20) var first_walkable_row: int = 3
@export_group("Scene isi lantai")
@export var ladder_scene: PackedScene = preload("res://scenes/world/cave/ladder_up.tscn")
@export var lift_scene: PackedScene = preload("res://scenes/world/cave/lift.tscn")
@export var stairs_scene: PackedScene = preload("res://scenes/world/cave/stairs_down.tscn")
@export var arena_scene: PackedScene = preload("res://scenes/world/cave/boss_arena.tscn")
## Kompatibilitas pemanggil lama; koordinat sekarang mengikuti Marker2D di scene.
var ARRIVAL_CELL: Vector2i:
	get:
		return cell_of(dungeon_layout.marker_position(dungeon_layout.arrival_path)) if dungeon_layout != null else _marker_cell("Arrival", Vector2i(20, 4))
var LIFT_CELL: Vector2i:
	get:
		var point := dungeon_layout.marker_position(dungeon_layout.lift_path) if dungeon_layout != null else ($Layout/Lift as Marker2D).global_position
		return cell_of(point + Vector2(-8, 24))

func _marker_cell(marker_name: String, fallback: Vector2i) -> Vector2i:
	var marker := get_node_or_null("Layout/" + marker_name) as Marker2D
	return cell_of(marker.global_position) if marker != null else fallback

# Koordinat atlas Caves.png.
const T_DECALS: Array[Vector2i] = [Vector2i(12, 3)]

var floor_number := 0
var stairs: Area2D
var rocks_left := 0
var enemies_left := 0
## Arena boss lantai ini (null bila bukan lantai arena atau boss sudah kalah).
var arena: BossArena
@onready var _ground: TileMapLayer = $BaseLayerGround
@onready var _walls: TileMapLayer = $CaveWalls
@onready var _content: Node2D = $FloorContent
@onready var _pillar_walls: StaticBody2D = $PillarWalls
@onready var _title: Label = $FloorTitle
@onready var _lobby: Node2D = $Lobby
## Ubin ruang seperti dilukis di editor; dipulihkan setiap pindah lantai.
var _ground_template: PackedByteArray
var _walls_template: PackedByteArray
## Penanda lantai di layar, satu per pemain (co-op punya layar sendiri-sendiri).
var _badges: Dictionary = {}
var _blocked: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _changing := false
## Waktu (ms) pemain terakhir ditaruh di titik tiba; objek sentuh menunggu sebentar setelahnya.
var arrived_msec := 0
var _ore_frames_cache: Dictionary = {}
## Naik tiap build_floor; sinyal dari batu/musuh lantai lama diabaikan.
var _floor_token := 0
var dungeon_layout: CaveDungeonLayout
var _dungeon_reserved: Dictionary = {}

func _ready() -> void:
	arrived_msec = Time.get_ticks_msec()
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
	_ground_template = _ground.tile_map_data
	_walls_template = _walls.tile_map_data
	var hole := _lobby.get_node_or_null("StairsDown") as Area2D
	if hole != null:
		hole.body_entered.connect(_on_hole_entered)
	var counter := _lobby.get_node_or_null("CombatShop")
	if counter != null and counter.get("shop_data") == null:
		counter.set("shop_data", DATA.shop)

## Lobi dilepas dari scene di lantai lain supaya pintunya tidak bisa dipakai; dibebaskan di sini.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and is_instance_valid(_lobby) and not _lobby.is_inside_tree():
		_lobby.free()

func _exit_tree() -> void:
	for badge in _badges.values():
		if is_instance_valid(badge):
			badge.queue_free()
	_badges.clear()

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
	_pillar_walls.add_child(shape)

# ── Membangun lantai ────────────────────────────────────────────────

## Bangun ulang isi lantai. Tidak memindahkan pemain (lihat go_to_floor).
func build_floor(number: int) -> void:
	floor_number = number
	_floor_token += 1
	if GameState.cave.reach(number):
		Notify.say("Lift lantai %d aktif! Naik lift dari lobi gua untuk langsung kembali ke sini." % number)
	_rng.seed = GameState.cave.floor_seed(number)
	_blocked.clear()
	dungeon_layout = null
	_dungeon_reserved.clear()
	_ground.visible = true
	_walls.visible = true
	stairs = null
	arena = null
	rocks_left = 0
	enemies_left = 0
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	# Barang yang dijatuhkan di lantai lama tidak ikut ke lantai baru.
	for child in get_children():
		if child is ItemPickup:
			remove_child(child)
			child.queue_free()
	for child in _pillar_walls.get_children():
		_pillar_walls.remove_child(child)
		child.queue_free()
	_ground.tile_map_data = _ground_template
	_walls.tile_map_data = _walls_template
	_build_room()
	_title.text = "Gua - Lobi" if number == 0 else "Gua - Lantai %d" % number
	var band := DATA.band_for(number) if number > 0 else null
	var tint: Color = band.tint if band != null else Color.WHITE
	_ground.modulate = tint
	_walls.modulate = tint
	var boss := DATA.boss_for(number)
	_show_lobby(number == 0)
	if number > 0:
		if boss != null and not GameState.cave.is_boss_defeated(number):
			_build_boss_floor(boss)
		else:
			_build_mine_floor()
	_update_badges()
	floor_built.emit(number)

## Teks penanda lantai: "Lobi Gua" atau "Lantai N" + nama tingkat (atau nama boss).
func floor_badge_info() -> Dictionary:
	if floor_number == 0:
		return {"floor": "Lobi Gua", "band": "Lantai 0", "icon": LOBBY_ICON, "accent": LOBBY_ACCENT}
	var band := DATA.band_for(floor_number)
	var band_name := band.display_name if band != null else ""
	var boss := DATA.boss_for(floor_number)
	if arena != null and boss != null:
		band_name = boss.title
	return {
		"floor": "Lantai %d" % floor_number,
		"band": band_name,
		"icon": band.icon if band != null else null,
		"accent": band.accent if band != null else LOBBY_ACCENT,
	}

func _update_badges() -> void:
	var info := floor_badge_info()
	for player in _players():
		var badge: CanvasLayer = _badges.get(player)
		if not is_instance_valid(badge):
			var parent := Coop.ui_parent(player)
			if parent == null:
				continue
			badge = FLOOR_BADGE.new()
			badge.name = "CaveFloorBadge"
			parent.add_child.call_deferred(badge)
			_badges[player] = badge
		badge.show_floor(info.floor, info.band, info.icon, info.accent)

## Ubin dan tabrakan ruang ada di scene; di sini hanya sel yang harus tetap kosong.
func _build_room() -> void:
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
	return cell.x >= 1 and cell.x < room_size.x - 1 and cell.y >= first_walkable_row and cell.y < room_size.y - 1

func cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell * TILE) + Vector2(TILE, TILE) * 0.5

func cell_of(world_pos: Vector2) -> Vector2i:
	return Vector2i((to_local(world_pos) / TILE).floor())

func arrival_position() -> Vector2:
	return dungeon_layout.marker_position(dungeon_layout.arrival_path) if dungeon_layout != null else ($Layout/Arrival as Marker2D).global_position

## Lobi hanya ada di lantai 0; isinya diatur di node Lobby pada cave.tscn.
func _show_lobby(visible_now: bool) -> void:
	if visible_now and _lobby.get_parent() == null:
		add_child(_lobby)
	elif not visible_now and _lobby.get_parent() == self:
		remove_child(_lobby)

func _build_mine_floor() -> void:
	var selected_band := DATA.band_for(floor_number)
	if selected_band != null and floor_number != DATA.lake_floor and _build_dungeon_floor(selected_band):
		return
	_add_ladder_up()
	if DATA.is_lift_floor(floor_number):
		_add_lift()
	if floor_number == DATA.lake_floor:
		_add_lake()
	var band := DATA.band_for(floor_number)
	if band == null:
		return
	_add_floor_layout(band)
	_add_pillars()
	_add_decals()
	var free := _free_cells()
	var rock_total := mini(_rng.randi_range(band.rock_min, maxi(band.rock_min, band.rock_max)), free.size())
	for i in rock_total:
		_spawn_rock(band.pick_ore(_rng), _take_cell(free))
	var spawn_cells := free.filter(func(cell: Vector2i) -> bool:
		return cell.distance_to(ARRIVAL_CELL) >= band.enemy_safe_radius)
	var enemy_total := mini(_rng.randi_range(band.enemy_min, maxi(band.enemy_min, band.enemy_max)), spawn_cells.size())
	for i in enemy_total:
		if band.enemies.is_empty():
			break
		var data := band.pick_enemy(_rng)
		if data == null:
			break
		var cell: Vector2i = spawn_cells.pop_at(_rng.randi() % spawn_cells.size())
		var enemy := Enemy.spawn(data, _content, to_global(cell_center(cell)))
		if enemy != null:
			enemies_left += 1
			enemy.died.connect(_on_enemy_died.bind(_floor_token))
	_reveal_if_empty()
	if floor_number >= DATA.max_floor and DiscoveryManager.discover("cave_floor_%d" % floor_number):
		Notify.say("Lantai %d adalah dasar Gua Tambang." % floor_number)


func _reveal_if_empty() -> void:
	if rocks_left == 0 and enemies_left == 0 and floor_number < DATA.max_floor:
		_reveal_stairs(_nearest_free(ARRIVAL_CELL + Vector2i(0, 3)))

## Coba semua template dalam urutan seed; fallback legacy jika semua tidak valid.
func _build_dungeon_floor(band: CaveBand) -> bool:
	if band.dungeon_scenes.is_empty():
		return false
	var offset := _rng.randi() % band.dungeon_scenes.size()
	for i in band.dungeon_scenes.size():
		var prefab := band.dungeon_scenes[(offset + i) % band.dungeon_scenes.size()]
		if prefab == null:
			continue
		var instance := prefab.instantiate()
		var candidate := instance as CaveDungeonLayout
		if candidate == null:
			instance.free()
			continue
		candidate.name = "DungeonLayout"
		_content.add_child(candidate)
		if candidate.map_bounds != Rect2i(Vector2i.ZERO, room_size):
			push_warning("Map Bounds layout harus sama dengan Room Size gua")
			_content.remove_child(candidate)
			candidate.queue_free()
			continue
		if not candidate.prepare(self, TILE):
			push_warning("Layout %s dilewati: %s" % [prefab.resource_path, candidate.error_message])
			_content.remove_child(candidate)
			candidate.queue_free()
			continue
		dungeon_layout = candidate
		_ground.hide()
		_walls.hide()
		(candidate.get_node("GroundTiles") as CanvasItem).modulate = band.tint
		var wall_tiles := candidate.get_node_or_null("WallTiles") as CanvasItem
		if wall_tiles != null:
			wall_tiles.modulate = band.tint
		_blocked.clear()
		# Tembok mengikuti sel non-ground; run horizontal mengurangi jumlah shape.
		for y in range(candidate.map_bounds.position.y, candidate.map_bounds.end.y):
			var run := -1
			for x in range(candidate.map_bounds.position.x, candidate.map_bounds.end.x + 1):
				var wall := x < candidate.map_bounds.end.x and not candidate.walkable.has(Vector2i(x, y))
				if wall:
					_blocked[Vector2i(x, y)] = true
					if run < 0:
						run = x
				elif run >= 0:
					_wall_rect(Rect2(run * TILE, y * TILE, (x - run) * TILE, TILE))
					run = -1
		for cell in candidate.routes:
			_blocked[cell] = true
		for cell in _reserved_cells():
			_blocked[cell] = true
		_dungeon_reserved = _blocked.duplicate()
		_add_ladder_up()
		if DATA.is_lift_floor(floor_number):
			_add_lift()
		CaveDungeonPopulator.populate(self, band, candidate, _rng)
		_reveal_if_empty()
		return true
	return false

## AI berjalan mengikuti ground dan menghindari batu, bukan menembus belokan tembok.
func dungeon_navigation_direction(from: Vector2, to: Vector2) -> Vector2:
	if dungeon_layout == null:
		return (to - from).normalized()
	var start := cell_of(from)
	var end := cell_of(to)
	var nav := dungeon_layout.navigation
	if not dungeon_layout.walkable.has(start) or not dungeon_layout.walkable.has(end) or nav.is_point_solid(end):
		return Vector2.ZERO
	if start == end:
		return (to - from).normalized()
	var path := nav.get_id_path(start, end)
	if path.size() < 2:
		return Vector2.ZERO
	return (to_global(cell_center(path[1])) - from).normalized()

## Semua pilihan template datang dari CaveBand; tidak ada cabang kode per tier/lantai.
func _add_floor_layout(band: CaveBand) -> void:
	if band.floor_scenes.is_empty():
		return
	var prefab := band.floor_scenes[_rng.randi() % band.floor_scenes.size()]
	if prefab == null:
		return
	var instance := prefab.instantiate()
	var layout := instance as CaveFloorLayout
	if layout == null:
		instance.free()
		push_error("Floor Scene harus berakar CaveFloorLayout")
		return
	layout.name = "TierLayout"
	_content.add_child(layout)
	for cell in layout.occupied_cells(self, TILE):
		_blocked[cell] = true

## Lantai arena boss: lapang tanpa batu dan pilar; garis kabut memisahkan area tiba dari arena.
func _build_boss_floor(boss: BossData) -> void:
	_add_ladder_up()
	if DATA.is_lift_floor(floor_number):
		_add_lift()
	_add_decals()
	_title.text = "Gua - Lantai %d: %s" % [floor_number, boss.title]
	arena = arena_scene.instantiate() as BossArena
	arena.name = "BossArena"
	_content.add_child(arena)
	var start := to_local(($Layout/ArenaStart as Marker2D).global_position)
	var end := to_local(($Layout/ArenaEnd as Marker2D).global_position)
	arena.setup(boss, self, Rect2(start, end - start))
	arena.boss_defeated.connect(_on_boss_defeated.bind(_floor_token))

func _on_boss_defeated(boss: BossData, token: int) -> void:
	if token != _floor_token:
		return
	if floor_number < DATA.max_floor:
		_reveal_stairs(_marker_cell("BossExit", Vector2i(room_size.x / 2, room_size.y - 4)))
	if DiscoveryManager.discover("boss_cleared_%d" % boss.floor_number):
		Notify.say("Lift lantai %d kini checkpoint aman. Lantai ini kembali jadi lantai tambang mulai kunjungan berikutnya." % boss.floor_number)

func _free_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for x in range(1, room_size.x - 1):
		for y in range(first_walkable_row, room_size.y - 1):
			var cell := Vector2i(x, y)
			if not _blocked.has(cell) and (dungeon_layout == null or dungeon_layout.reachable.has(cell)):
				cells.append(cell)
	return cells

func _take_cell(cells: Array[Vector2i]) -> Vector2i:
	return cells.pop_at(_rng.randi() % cells.size())

## Pilar batu 1-3 tile (atas + tebing) sebagai rintangan. Dijaga agar tidak saling menempel.
func _add_pillars() -> void:
	var band := DATA.band_for(floor_number)
	var count := _rng.randi_range(band.pillar_min, maxi(band.pillar_min, band.pillar_max))
	for i in count:
		var length := _rng.randi_range(1, maxi(1, mini(band.pillar_max_length, room_size.x - 8)))
		var origin := Vector2i(_rng.randi_range(3, room_size.x - 4 - length), _rng.randi_range(first_walkable_row + 4, room_size.y - 4))
		var ok := true
		for dx in range(-1, length + 1):
			for dy in range(-1, 3):
				var cell := origin + Vector2i(dx, dy)
				if _blocked.has(cell) or cell.distance_to(ARRIVAL_CELL) < band.pillar_safe_radius:
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
	var band := DATA.band_for(floor_number)
	for i in _rng.randi_range(band.decal_min, maxi(band.decal_min, band.decal_max)):
		var cell := Vector2i(_rng.randi_range(2, room_size.x - 3), _rng.randi_range(first_walkable_row + 1, room_size.y - 3))
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
		rock.scale = Vector2.ONE * ore.sprite_scale
		var sprite := rock.get_node("AnimatedSprite2D") as AnimatedSprite2D
		sprite.sprite_frames = _ore_frames(ore)
		sprite.animation = &"idle"
		var shape := rock.get_node("CollisionShape2D") as CollisionShape2D
		shape.scale = Vector2(0.8, 0.8) if ore.sprite != null else Vector2(0.6, 0.6)
	rock.set_meta("cave_ore", ore.item_id)
	rock.position = cell_center(cell)
	rock.set_meta("cave_cell", cell)
	_blocked[cell] = true
	rock.tree_exiting.connect(_on_rock_removed.bind(rock, _floor_token))
	_content.add_child(rock)
	rocks_left += 1
	if dungeon_layout != null and dungeon_layout.walkable.has(cell):
		dungeon_layout.navigation.set_point_solid(cell, true)
	return rock

## Animasi batu dari CaveOre.sprite / hit_sprite, atau cadangan lama dari
## `stone with minerals.png` (baris 0 kolom bijih, kolom 10 = kilat putih).
func _ore_frames(ore: CaveOre) -> SpriteFrames:
	var key: Variant = ore.sprite_column
	if ore.sprite != null:
		key = ore
	if _ore_frames_cache.has(key):
		return _ore_frames_cache[key]
	var normal: Texture2D = ore.sprite
	var flash: Texture2D = ore.hit_sprite if ore.hit_sprite != null else ore.sprite
	if normal == null:
		normal = _ore_region(Rect2(ore.sprite_column * TILE, 0, TILE, TILE))
		flash = _ore_region(Rect2(160, 0, TILE, TILE))
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for anim: StringName in [&"idle", &"chopping", &"stump"]:
		frames.add_animation(anim)
		frames.set_animation_loop(anim, false)
		frames.set_animation_speed(anim, 8.0)
	frames.add_frame(&"idle", normal)
	frames.add_frame(&"chopping", normal)
	frames.add_frame(&"chopping", flash)
	frames.add_frame(&"stump", flash)
	_ore_frames_cache[key] = frames
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
	if dungeon_layout != null and dungeon_layout.walkable.has(cell):
		dungeon_layout.navigation.set_point_solid(cell, false)
	for item_id in rock_bonus_drops(rock.get_meta("cave_ore", ""), randf(), [randf(), randf()]):
		_spawn_bonus.call_deferred(item_id, rock.global_position)
		# Prospector: batubara 2x. Geologist: geoda berpasangan (GDD 13).
		if (item_id == "coal" and SkillSystem.roll(rock.last_hitter, &"coal_double")) \
				or (item_id.contains("geode") and SkillSystem.roll(rock.last_hitter, &"gem_double")):
			_spawn_bonus.call_deferred(item_id, rock.global_position)
	if stairs != null or floor_number >= DATA.max_floor:
		return
	# Spelunker Master (Miner Lv10 A): tangga 50% lebih sering.
	if randf() < DATA.stairs_chance * (1.0 + SkillSystem.household(&"stairs_chance")) or (rocks_left <= 0 and enemies_left <= 0):
		_reveal_for_floor.call_deferred(cell, _floor_token)

## Geoda dan barang tambahan dari satu batu yang hancur. `geode_roll` dan `bonus_rolls`
## berisi angka acak 0-1 supaya bisa diuji.
func rock_bonus_drops(ore_id: String, geode_roll: float, bonus_rolls: Array) -> PackedStringArray:
	var drops := PackedStringArray()
	var band := DATA.band_for(floor_number)
	if band != null:
		var geode := band.roll_geode(geode_roll)
		if not geode.is_empty():
			drops.append(geode)
	var ore := DATA.ore(ore_id)
	if ore != null:
		for i in ore.bonus_item_ids.size():
			var chance := ore.bonus_chances[i] if i < ore.bonus_chances.size() else 0.0
			var roll: float = bonus_rolls[i] if i < bonus_rolls.size() else randf()
			if roll < chance:
				drops.append(ore.bonus_item_ids[i])
	return drops

func _spawn_bonus(item_id: String, at: Vector2) -> void:
	if is_inside_tree():
		ItemPickup.spawn(_content, at + Vector2(randf_range(-6.0, 6.0), randf_range(-4.0, 4.0)), item_id, 1)

func _on_enemy_died(enemy: Enemy, token: int) -> void:
	if token != _floor_token:
		return
	enemies_left -= 1
	if enemies_left > 0 or stairs != null or floor_number >= DATA.max_floor:
		return
	var cell := cell_of(enemy.global_position)
	if not _is_inside(cell) or _blocked.has(cell):
		cell = _nearest_free(cell)
	_reveal_for_floor.call_deferred(cell, _floor_token)
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

func _reveal_for_floor(cell: Vector2i, token: int) -> void:
	if token == _floor_token:
		_reveal_stairs(cell)

func _reveal_stairs(cell: Vector2i) -> void:
	if stairs != null or not is_inside_tree():
		return
	if dungeon_layout != null:
		cell = dungeon_layout.stair_cells[_rng.randi() % dungeon_layout.stair_cells.size()]
	stairs = _add_hole(cell)
	stairs_revealed.emit(stairs.global_position)
	if DiscoveryManager.discover("cave_stairs"):
		Notify.say("Tangga turun ditemukan! Injak lubangnya untuk turun ke lantai berikutnya.")

## Lubang tangga turun ke lantai berikutnya.
func _add_hole(cell: Vector2i) -> Area2D:
	var hole := stairs_scene.instantiate() as Area2D
	hole.name = "StairsDown"
	hole.position = cell_center(cell)
	hole.body_entered.connect(_on_hole_entered)
	_blocked[cell] = true
	_content.add_child(hole)
	return hole

func _on_hole_entered(body: Node2D) -> void:
	if body is Player and not body.is_input_locked():
		go_to_floor.call_deferred(floor_number + 1)

func _add_ladder_up() -> void:
	var point := dungeon_layout.marker_position(dungeon_layout.ladder_path) if dungeon_layout != null else ($Layout/LadderUp as Marker2D).global_position
	_spawn_interactable(ladder_scene, to_local(point))

func _add_lift() -> void:
	var point := dungeon_layout.marker_position(dungeon_layout.lift_path) if dungeon_layout != null else ($Layout/Lift as Marker2D).global_position
	_spawn_interactable(lift_scene, to_local(point))

func _spawn_interactable(prefab: PackedScene, pos: Vector2) -> Area2D:
	var area := prefab.instantiate() as Area2D
	area.set("cave", self)
	area.position = pos
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
	arrived_msec = Time.get_ticks_msec()
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
