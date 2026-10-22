class_name EnemyProjectile
extends Node2D

## Proyektil musuh: sapuan ray mencegah tembus tembok pada frame lambat.
var direction := Vector2.RIGHT
var speed := 150.0
var damage := 10
var tint := Color.WHITE
var distance_left := 240.0
var _exclude: Array[RID] = []

static func launch(enemy: Enemy, heading: Vector2) -> EnemyProjectile:
	var shot := EnemyProjectile.new()
	shot.direction = heading.normalized()
	shot.speed = enemy.data.projectile_speed
	shot.distance_left = enemy.data.projectile_range
	shot.damage = enemy.data.attack
	shot.tint = enemy.data.projectile_color
	for node in enemy.get_tree().get_nodes_in_group(&"enemies"):
		if node is CollisionObject2D:
			shot._exclude.append(node.get_rid())
	enemy.get_parent().add_child(shot)
	shot.global_position = enemy.global_position
	return shot

func poise_damage_to_player() -> float:
	return damage * 1.5

func _physics_process(delta: float) -> void:
	var step := direction * minf(speed * delta, distance_left)
	var query := PhysicsRayQueryParameters2D.create(global_position, global_position + step, 0xFFFFFFFF, _exclude)
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		if hit.collider is Player:
			hit.collider.take_hit(damage, self, direction * 14.0)
		queue_free()
		return
	global_position += step
	distance_left -= step.length()
	if distance_left <= 0.0:
		queue_free()
	queue_redraw()

func _draw() -> void:
	draw_line(-direction * 9.0 + Vector2(0, -6), Vector2(0, -6), tint, 2.0)
	draw_circle(Vector2(0, -6), 2.5, tint.lightened(0.4))
