class_name Vehicles
extends RefCounted

## Aturan kendaraan (GDD 10): di mana boleh dipakai, dan gerak terbang sapu yang melintasi
## air/jurang pendek. Dipakai RideState, ToolController, dan toko.

## Node tabrakan (StaticBody2D dsb.) di grup ini dianggap air: bisa dilewati kendaraan terbang.
const WATER_GROUP := &"vehicle_water"
## Node tabrakan di grup ini dianggap jurang pendek.
const GAP_GROUP := &"vehicle_gap"
## Tile air: TileMapLayer bernama "...water...", tekstur atlas berisi kata ini,
## atau custom data bool "water" di TileSet.
const WATER_KEYWORD := "water"
const GAP_CUSTOM_DATA := "gap"
const NO_VEHICLE_PATHS := ["interior", "/cave/"]

## Kendaraan boleh dipakai di area tempat pemain berada.
static func allowed_here(player: Player) -> bool:
	var world := player.world_root()
	if world == null:
		return true
	for zone in player.get_tree().get_nodes_in_group(VehicleZone.GROUP):
		if zone == world or world.is_ancestor_of(zone):
			return zone.allowed
	var path := world.scene_file_path.to_lower()
	for keyword in NO_VEHICLE_PATHS:
		if path.contains(keyword):
			return false
	return true

## Barang ini kendaraan yang sudah bisa dibeli (area syaratnya terbuka).
## Merchant Lv10 Capitalist Investor (import_catalog) membeli kendaraan Kota Modern lebih awal.
static func is_unlocked(vehicle: VehicleData, buyer: PlayerData = null) -> bool:
	if vehicle == null:
		return false
	if vehicle.required_unlock.is_empty() or UnlockManager.is_unlocked(vehicle.required_unlock):
		return true
	return vehicle.required_unlock == "modern_city" and buyer != null and SkillSystem.stat(buyer, &"import_catalog") > 0.0

## Gerak terbang: tabrakan biasa, kecuali air/jurang yang boleh dilintasi kendaraan ini.
## Meluncur sepanjang dinding seperti move_and_slide (coba penuh, lalu sumbu X, lalu Y).
static func fly_move(player: Player, motion: Vector2, vehicle: VehicleData) -> void:
	if motion == Vector2.ZERO:
		return
	for step: Vector2 in [motion, Vector2(motion.x, 0.0), Vector2(0.0, motion.y)]:
		if step != Vector2.ZERO and not blocked_at(player, player.global_position + step, vehicle.crosses_water, vehicle.crosses_gaps):
			player.global_position += step
			return

## Badan pemain di `position` bertabrakan dengan sesuatu yang tidak boleh dilintasi.
## Tanpa izin air/jurang = sama dengan pejalan kaki (dipakai saat turun dari sapu).
static func blocked_at(player: Player, position: Vector2, water_ok: bool, gaps_ok: bool) -> bool:
	var shape_node := player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null or shape_node.shape == null:
		return false
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape_node.shape
	params.transform = shape_node.global_transform.translated(position - player.global_position)
	params.collision_mask = player.collision_mask
	params.exclude = [player.get_rid()]
	for hit in player.get_world_2d().direct_space_state.intersect_shape(params, 16):
		if not _passable(hit.collider, params, water_ok, gaps_ok):
			return true
	return false

static func _passable(collider: Object, params: PhysicsShapeQueryParameters2D, water_ok: bool, gaps_ok: bool) -> bool:
	if collider is TileMapLayer:
		return _tiles_passable(collider, params, water_ok, gaps_ok)
	if collider is Node:
		if water_ok and (collider as Node).is_in_group(WATER_GROUP):
			return true
		if gaps_ok and (collider as Node).is_in_group(GAP_GROUP):
			return true
	return false

## Semua tile padat di bawah badan adalah air/jurang yang boleh dilintasi.
static func _tiles_passable(layer: TileMapLayer, params: PhysicsShapeQueryParameters2D, water_ok: bool, gaps_ok: bool) -> bool:
	if layer.tile_set == null:
		return false
	var rect: Rect2 = params.transform * params.shape.get_rect()
	var from := layer.local_to_map(layer.to_local(rect.position))
	var to := layer.local_to_map(layer.to_local(rect.end))
	for x in range(mini(from.x, to.x), maxi(from.x, to.x) + 1):
		for y in range(mini(from.y, to.y), maxi(from.y, to.y) + 1):
			var cell := Vector2i(x, y)
			var data := layer.get_cell_tile_data(cell)
			if data == null or not _tile_solid(layer.tile_set, data, params.collision_mask):
				continue
			if water_ok and is_water_tile(layer, cell, data):
				continue
			if gaps_ok and _custom_flag(layer.tile_set, data, GAP_CUSTOM_DATA):
				continue
			return false
	return true

static func _tile_solid(tile_set: TileSet, data: TileData, mask: int) -> bool:
	for layer_id in tile_set.get_physics_layers_count():
		if (tile_set.get_physics_layer_collision_layer(layer_id) & mask) != 0 and data.get_collision_polygons_count(layer_id) > 0:
			return true
	return false

static func is_water_tile(layer: TileMapLayer, cell: Vector2i, data: TileData = null) -> bool:
	if layer.name.to_lower().contains(WATER_KEYWORD) or layer.is_in_group(WATER_GROUP):
		return true
	if data == null:
		data = layer.get_cell_tile_data(cell)
	if data != null and _custom_flag(layer.tile_set, data, WATER_KEYWORD):
		return true
	var source_id := layer.get_cell_source_id(cell)
	if not layer.tile_set.has_source(source_id):
		return false
	var source := layer.tile_set.get_source(source_id) as TileSetAtlasSource
	return source != null and source.texture != null and source.texture.resource_path.to_lower().contains(WATER_KEYWORD)

static func _custom_flag(tile_set: TileSet, data: TileData, layer_name: String) -> bool:
	var index := tile_set.get_custom_data_layer_by_name(layer_name)
	return index >= 0 and bool(data.get_custom_data_by_layer_id(index))
