extends Node

const FISH_DIR := "res://resources/fish_data"

# --- Debug (diatur lewat FishingDebug, nilai bawaan harus tetap false/-1) ---
var debug_instant_bite := false
var debug_auto_win := false
var debug_force_tier := -1 # -1 = normal, 0..4 = paksa tier tertentu

var _last_catch_new := false

var _fish: Array[FishData] = []

func _ready() -> void:
	for file in DirAccess.get_files_at(FISH_DIR):
		var fname := file.trim_suffix(".remap")
		if not fname.ends_with(".tres"):
			continue
		var res := load("%s/%s" % [FISH_DIR, fname])
		if res is FishData:
			_fish.append(res)
	
	if _fish.is_empty():
		push_warning("FishingManager: tidak ada FishData di %s" % FISH_DIR)
			
func _point_hits(player: Player, position: Vector2, mask: int) -> Array:
	var q := PhysicsPointQueryParameters2D.new()
	q.position = position
	q.collide_with_areas = true
	q.collide_with_bodies = false
	q.collision_mask = mask
	return player.get_world_2d().direct_space_state.intersect_point(q, 8)

func find_spot_at(player: Player, world_position: Vector2) -> FishingSpot:
	if not _point_hits(player, world_position, FishingBlocker.BLOCKER_LAYER_BIT).is_empty():
		return null
	for hit in _point_hits(player, world_position, FishingSpot.SPOT_LAYER_BIT):
		if hit["collider"] is FishingSpot:
			return hit["collider"]
	return null

func find_spot(player: Player) -> FishingSpot:	
	return find_spot_at(player, player.get_target_world_position())

## rare_mult menaikkan bobot ikan Langka ke atas, legendary_mult ditumpuk untuk Legendaris.
func roll_catch(location_id: String, rare_mult: float = 1.0, legendary_mult: float = 1.0) -> FishData:
	var pool: Array[FishData] = []
	var weights: Array[float] = []
	var total := 0.0
	var season := DayCycle.get_current_season()
	
	for f in _fish:
		if OS.has_feature("editor") and debug_force_tier >= 0 and int(f.item.rarity) != debug_force_tier:
			continue
			
		if f.get_weight() <= 0.0:
			continue
			
		if f.is_available(location_id, DayCycle.hour, season):
			var w := f.get_weight()
			var rarity := int(f.item.rarity)
			if rarity >= ItemData.Rarity.RARE:
				w *= rare_mult
			if rarity >= ItemData.Rarity.LEGENDARY:
				w *= legendary_mult
			pool.append(f)
			weights.append(w)
			total += w
			
	if pool.is_empty() or total <= 0.0:
		return null
		
	var r := randf() * total
	
	for i in pool.size():
		r -= weights[i]
		if r <= 0.0:
			return pool[i]		
		
	return pool.back()
	
func register_catch(fish: FishData) -> bool:
	_last_catch_new = false
	var left := GameState.add_item(fish.item.item_id, 1)
	if left > 0:
		Notify.say("Tas penuh! %s terlepas." % fish.item.display_name)
		return false
	_last_catch_new = DiscoveryManager.discover("fish_" + fish.item.item_id)
	
	return true
