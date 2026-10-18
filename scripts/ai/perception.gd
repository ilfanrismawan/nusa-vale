class_name Perception
extends RefCounted

## Sensor musuh (GDD 8.2-B2): suara yang bisa didengar, cahaya yang memengaruhi jarak pandang,
## dan garis pandang (tembok/batu menghalangi). Musuh memakai fungsi ini dari Enemy.

const RULES: AiRules = preload("res://resources/ai/ai_rules.tres")
## Node dalam grup ini menandai area gelap (gua). Musuh di dalamnya memakai dark_vision_scale.
const DARK_GROUP := &"dark_area"

## Tampilkan kerucut pandang dan status waspada di atas musuh (Ctrl+F12 di build debug).
static var debug_draw := false

## Suara di `position` terdengar oleh musuh dalam `radius` x hearing_scale musuh itu.
## `maker` = pembuat suara (pemain), dipakai musuh untuk menoleh. Mengembalikan jumlah pendengar.
static func noise(context: Node, position: Vector2, radius: float, maker: Node = null) -> int:
	if context == null or not context.is_inside_tree() or radius <= 0.0:
		return 0
	var heard := 0
	for node in context.get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy == context or enemy.is_dead() or enemy.data == null:
			continue
		if enemy.global_position.distance_to(position) <= radius * enemy.data.hearing_scale:
			if enemy.hear(position, maker):
				heard += 1
	return heard

## Pengali jarak pandang dari cahaya: gua gelap, malam meredupkan pandangan di luar ruangan.
static func light_scale(enemy: Enemy) -> float:
	if in_dark_area(enemy):
		return enemy.data.dark_vision_scale
	var night := clampf(DayCycle.night_intensity(), 0.0, 1.0)
	return lerpf(1.0, enemy.data.night_vision_scale, night)

static func in_dark_area(node: Node) -> bool:
	if node == null or not node.is_inside_tree():
		return false
	for area in node.get_tree().get_nodes_in_group(DARK_GROUP):
		if area == node or (area as Node).is_ancestor_of(node):
			return true
	return false

## true bila tidak ada tembok/batu di antara `from` dan `to`. Musuh lain tidak menghalangi.
static func line_of_sight(viewer: CollisionObject2D, from: Vector2, to: Vector2, target: CollisionObject2D = null) -> bool:
	if viewer == null or not viewer.is_inside_tree():
		return false
	var space := viewer.get_world_2d().direct_space_state
	var exclude: Array[RID] = [viewer.get_rid()]
	if target != null:
		exclude.append(target.get_rid())
	for _i in 4:
		var query := PhysicsRayQueryParameters2D.create(from, to, 1, exclude)
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			return true
		var collider: Object = hit.get("collider")
		if collider is Enemy or collider is Player:
			exclude.append((collider as CollisionObject2D).get_rid())
			continue
		return false
	return true

## Panggil kawan di sekitar `caller` untuk ikut menyerang `target`. Mengembalikan jumlah kawan.
static func call_for_help(caller: Enemy, target: Player) -> int:
	if caller == null or target == null or not caller.is_inside_tree():
		return 0
	var answered := 0
	for node in caller.get_tree().get_nodes_in_group(&"enemies"):
		var ally := node as Enemy
		if ally == null or ally == caller or ally.is_dead():
			continue
		if ally.global_position.distance_to(caller.global_position) <= RULES.help_radius and ally.answer_help(target, caller):
			answered += 1
	return answered
