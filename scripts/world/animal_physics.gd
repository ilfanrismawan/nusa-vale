extends RefCounted
## Dipakai lewat preload (const AnimalPhysics := preload(...)).
## Pemeriksaan fisika bersama untuk hewan (pet, serangga darat, hewan ternak): jalur dan titik
## kosong terhadap penghalang dunia di layer 1 (bangunan, pagar, pohon, batu, tile, objek pemain).

const OBSTACLE_MASK := 1


## true bila garis from -> to (global) menabrak penghalang layer 1.
static func is_blocked(node: Node2D, from: Vector2, to: Vector2, exclude: Array[RID] = []) -> bool:
	var space := node.get_world_2d().direct_space_state
	if space == null:
		return false
	var ray := PhysicsRayQueryParameters2D.create(from, to, OBSTACLE_MASK, exclude)
	ray.collide_with_areas = false
	return not space.intersect_ray(ray).is_empty()


## true bila lingkaran `radius` di titik global `at` tidak menyentuh penghalang layer 1.
static func is_free(node: Node2D, at: Vector2, radius: float = 4.0, exclude: Array[RID] = []) -> bool:
	var space := node.get_world_2d().direct_space_state
	if space == null:
		return true
	var circle := CircleShape2D.new()
	circle.radius = radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.transform = Transform2D(0.0, at)
	query.collision_mask = OBSTACLE_MASK
	query.collide_with_areas = false
	query.exclude = exclude
	return space.intersect_shape(query, 1).is_empty()


## Titik kosong terdekat dari `at` (cincin 8 arah tiap 6 px sampai max_distance), atau `at` sendiri.
static func nearest_free(node: Node2D, at: Vector2, radius: float = 4.0, max_distance: float = 48.0, exclude: Array[RID] = []) -> Vector2:
	if is_free(node, at, radius, exclude):
		return at
	var distance := 6.0
	while distance <= max_distance:
		for i in 8:
			var candidate := at + Vector2.from_angle(TAU * i / 8.0) * distance
			if is_free(node, candidate, radius, exclude):
				return candidate
		distance += 6.0
	return at
