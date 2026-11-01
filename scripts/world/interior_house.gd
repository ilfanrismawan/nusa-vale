@tool
extends Node2D

## Interior rumah pemain. Isinya (tilemap, kasur, pintu dapur/gudang, perabot) ada di scene layout
## per tingkat: `base_layout` untuk tingkat 0, tingkat 1+ dari HouseLevelData.interior_scene (GDD 4.12).
## Path scene ini tetap satu karena dipakai tidur, pingsan, respawn, menu, dan pet.

@export var base_layout: PackedScene
## Hanya untuk editor: lihat layout tingkat lain tanpa menjalankan game.
@export_range(0, 10) var preview_level := 0:
	set(value):
		preview_level = value
		if Engine.is_editor_hint() and is_inside_tree():
			_show(value)

var layout: HouseInteriorLayout

func _ready() -> void:
	if Engine.is_editor_hint():
		_show(preview_level)
		return
	_show(GameState.house.level)
	GameState.house.level_changed.connect(_on_level_changed)
	var household := Node2D.new()
	household.name = "Household"
	household.set_script(preload("res://scripts/world/npc_home.gd"))
	add_child(household)

## Upgrade selesai saat tidur (pergantian hari): tunggu tirai tidur selesai supaya kasur lama tidak
## dihapus di tengah animasinya, lalu pemain di rumah ini bangun di BedSpawn layout baru.
func _on_level_changed(level: int) -> void:
	while DayCycle.is_sleep_transition or DayCycle._is_passing_out:
		await get_tree().process_frame
	if not is_inside_tree() or not _show(level):
		return
	var spot := layout.get_node_or_null("BedSpawn") as Node2D
	if spot == null:
		return
	for body in get_tree().get_nodes_in_group("night_players"):
		var player := body as Player
		if player != null and player.world_root() == self:
			player.global_position = spot.global_position

## Pasang layout tingkat `level`; false bila layout itu sudah terpasang.
func _show(level: int) -> bool:
	var scene := HouseManager.scene_for(level, base_layout, true)
	if is_instance_valid(layout) and layout.scene_file_path == (scene.resource_path if scene != null else ""):
		return false
	if is_instance_valid(layout):
		remove_child(layout)
		layout.free()
	layout = scene.instantiate() as HouseInteriorLayout if scene != null else null
	if layout == null:
		push_error("Layout interior rumah harus memakai house_interior_layout.gd")
		return false
	layout.name = "Layout"
	add_child(layout)
	move_child(layout, 0)
	return true

## Kasur aktif di layout tingkat sekarang.
func bed() -> Bed:
	return layout.find_child("Kasur", true, false) as Bed if is_instance_valid(layout) else null
