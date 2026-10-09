extends Node

const FISH_DIR := "res://resources/fish_data"

var _fish: Array[FishData] = []
# --- Debug (diatur lewat FishingDebug, nilai bawaan harus tetap false/-1) ---
var debug_instant_bite := false
var debug_auto_win := false
var debug_force_tier := -1 # -1 = normal, 0..4 = paksa tier tertentu

func _ready() -> void:
	for file in DirAccess.get_files_at(FISH_DIR):
		var fname := file.trim_suffix(".remap")
		if not fname.ends_with(".tres"):
			continue
		var res := load("%s/%s" % [FISH_DIR, fname])
		if res is FishData:
			_fish.append(res)
			
			
func _point_hits(player: Player, position: Vector2, mask: int) -> Array:
	var q := PhysicsPointQueryParameters2D.new()
	q.position = position
	q.collide_with_areas = true
	q.collide_with_bodies = false
	q.collision_mask = mask
	return player.get_world_2d().direct_space_state.intersect_point(q, 8)
	
func find_spot(player: Player) -> FishingSpot:	
	var position := player.get_target_world_position()
	
	if not _point_hits(player, position, FishingBlocker.BLOCKER_LAYER_BIT).is_empty():
		return null
		
	for hit in _point_hits(player, position, FishingSpot.SPOT_LAYER_BIT):
		if hit["collider"] is FishingSpot:
			return hit["collider"]
			
	return null

func roll_catch(location_id: String) -> FishData:
	var pool: Array[FishData] = []
	var total := 0.0
	
	for f in _fish:
		if f.weight <= 0.0:
			continue
			
		if f.is_available(location_id, DayCycle.hour):
			pool.append(f)
			total += f.weight
			
	if pool.is_empty() or total <= 0.0:
		return null
		
	var r := randf() * total
	
	for f in pool:
		if r <= f.weight:
			return f
		r -= f.weight
		
	return pool.back()
	
func register_catch(fish: FishData) -> bool:
	var left := GameState.add_item(fish.item.item_id, 1)
	if left > 0:
		Notify.say("Tas penuh! %s terlepas.")
		return false
	if DiscoveryManager.discover("fish_" + fish.item.item_id):
		Notify.say("Ikan baru tercatat: %s" % fish.item.display_name)
	return true
