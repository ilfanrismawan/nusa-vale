class_name CaveDungeonPopulator
extends RefCounted

## Mengisi zona editor dengan budget tier; tidak menyimpan koordinat atau nama tier.
static func populate(cave, band: CaveBand, layout: CaveDungeonLayout, rng: RandomNumberGenerator) -> void:
	var mineral_states: Array[Dictionary] = []
	var enemy_states: Array[Dictionary] = []
	for zone in layout.zones():
		if zone.kind == CaveSpawnZone.Kind.SAFE or zone.spawn_weight <= 0.0:
			continue
		var cells: Array[Vector2i] = []
		for cell in zone.cells(cave, cave.TILE):
			if not layout.reachable.has(cell) or cave._blocked.has(cell):
				continue
			if zone.kind == CaveSpawnZone.Kind.ENEMY and cell.distance_to(cave.ARRIVAL_CELL) < band.enemy_safe_radius:
				continue
			cells.append(cell)
		var pool := _item_pool(zone, band, cave.DATA)
		if cells.is_empty() or (zone.kind != CaveSpawnZone.Kind.ENEMY and pool.is_empty()):
			continue
		var state := {"zone": zone, "cells": cells, "pool": pool, "count": 0, "anchor": Vector2i.ZERO, "item": ""}
		if zone.kind == CaveSpawnZone.Kind.ENEMY:
			enemy_states.append(state)
		else:
			mineral_states.append(state)
	_fill(cave, band, mineral_states, rng.randi_range(band.rock_min, maxi(band.rock_min, band.rock_max)), rng)
	_fill(cave, band, enemy_states, rng.randi_range(band.enemy_min, maxi(band.enemy_min, band.enemy_max)), rng)

static func _item_pool(zone: CaveSpawnZone, band: CaveBand, catalog: CaveData) -> PackedStringArray:
	var pool := PackedStringArray()
	for id in band.ore_ids:
		if band._weight(band.ore_ids.find(id)) <= 0.0:
			continue
		if not zone.item_ids.is_empty() and not zone.item_ids.has(id):
			continue
		var ore := catalog.ore(id)
		if ore == null:
			continue
		var category: int = CaveOre.SpawnKind.GEM if ore.is_gem else ore.spawn_kind
		if category == zone.kind:
			pool.append(id)
	return pool

static func _fill(cave, band: CaveBand, states: Array[Dictionary], budget: int, rng: RandomNumberGenerator) -> void:
	# Minimum per zona dibatasi budget global, kapasitas dan Maximum Count.
	for state in states:
		var zone: CaveSpawnZone = state.zone
		for i in mini(zone.minimum_count, zone.maximum_count):
			if budget <= 0:
				return
			if _spawn(cave, band, state, rng):
				budget -= 1
	while budget > 0:
		var available: Array[Dictionary] = []
		var total := 0.0
		for state in states:
			var zone: CaveSpawnZone = state.zone
			var cells: Array = state.cells
			for i in range(cells.size() - 1, -1, -1):
				if cave._blocked.has(cells[i]):
					cells.remove_at(i)
			if state.count < zone.maximum_count and not cells.is_empty():
				available.append(state)
				total += zone.spawn_weight
		if available.is_empty():
			return
		var roll := rng.randf() * total
		var chosen: Dictionary = available.back()
		for state in available:
			roll -= state.zone.spawn_weight
			if roll < 0.0:
				chosen = state
				break
		if _spawn(cave, band, chosen, rng):
			budget -= 1
		else:
			chosen.cells.clear()

static func _spawn(cave, band: CaveBand, state: Dictionary, rng: RandomNumberGenerator) -> bool:
	var zone: CaveSpawnZone = state.zone
	var cells: Array = state.cells
	for i in range(cells.size() - 1, -1, -1):
		if cave._blocked.has(cells[i]):
			cells.remove_at(i)
	if cells.is_empty() or state.count >= zone.maximum_count:
		return false
	var choices: Array[int] = []
	if zone.clustered and state.count > 0:
		for i in cells.size():
			if cells[i].distance_to(state.anchor) <= zone.cluster_radius:
				choices.append(i)
	var index: int = choices[rng.randi() % choices.size()] if not choices.is_empty() else rng.randi() % cells.size()
	var cell: Vector2i = cells.pop_at(index)
	var spawned: Node2D
	if zone.kind == CaveSpawnZone.Kind.ENEMY:
		var data: EnemyData = band.pick_enemy(rng)
		if not zone.enemy_pool.is_empty():
			var pool: Array[EnemyData] = []
			for entry in zone.enemy_pool:
				if entry != null:
					pool.append(entry)
			data = pool[rng.randi() % pool.size()] if not pool.is_empty() else null
		if data == null:
			return false
		var enemy := Enemy.spawn(data, cave._content, cave.to_global(cave.cell_center(cell)))
		if enemy == null:
			return false
		cave.enemies_left += 1
		enemy.died.connect(cave._on_enemy_died.bind(cave._floor_token))
		cave._blocked[cell] = true
		spawned = enemy
	else:
		if not zone.clustered or state.count == 0 or choices.is_empty():
			state.item = _pick_item(state.pool, band, rng)
			state.anchor = cell
		spawned = cave._spawn_rock(state.item, cell)
		if spawned == null:
			return false
	spawned.set_meta("spawn_zone", zone.name)
	spawned.set_meta("spawn_kind", zone.kind)
	state.count += 1
	return true

static func _pick_item(pool: PackedStringArray, band: CaveBand, rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for id in pool:
		total += band._weight(band.ore_ids.find(id))
	if total <= 0.0:
		return pool[0]
	var roll := rng.randf() * total
	for id in pool:
		roll -= band._weight(band.ore_ids.find(id))
		if roll < 0.0:
			return id
	return pool[pool.size() - 1]
