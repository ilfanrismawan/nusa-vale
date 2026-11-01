class_name HouseInteriorLayout
extends Node2D

## Root isi interior_house.tscn untuk satu tingkat rumah (GDD 4.12): tilemap, collision, kasur,
## pintu, perabot, dan marker. Semua diedit langsung di scene layout. Pintu masuk dan ruang utama
## sama di semua tingkat karena posisinya dipakai dari luar (pintu farm 310,190 · pingsan 317,151).

## Dimuat saat dipakai, bukan preload: scene ini memakai script ini sendiri (preload = siklus).
const BASE_LAYOUT := "res://scenes/world/interior/house/house_interior_lv0.tscn"

## Posisi Marker2D `marker` di layout tingkat rumah sekarang, mis. KitchenReturn untuk pintu
## keluar dapur. Layout dipasang di origin interior_house, jadi posisi lokal = posisi dunia.
static func point(marker: String, fallback: Vector2) -> Vector2:
	var scene := HouseManager.scene_for(GameState.house.level, load(BASE_LAYOUT), true)
	if scene == null:
		return fallback
	var layout := scene.instantiate()
	var node := layout.get_node_or_null(marker) as Node2D
	var result := node.position if node != null else fallback
	layout.free()
	return result
