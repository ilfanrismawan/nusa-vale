@tool
extends Node2D

## Rumah pemain di farm. Tampilannya (sprite, collision, pintu) ada di scene eksterior per tingkat:
## `base_exterior` untuk tingkat 0, tingkat 1+ dari HouseLevelData.exterior_scene (GDD 4.12).
## Saat pesanan Wira selesai, scene eksterior diganti tanpa memuat ulang farm.

@export var base_exterior: PackedScene
## Root farm, tempat target HouseAnchor dan objek cleanup dicari.
@export var world_path: NodePath = ^".."
## Hanya untuk editor: lihat tampilan tingkat lain tanpa menjalankan game.
@export_range(0, 10) var preview_level := 0:
	set(value):
		preview_level = value
		if Engine.is_editor_hint() and is_inside_tree():
			_show(value)

var exterior: HouseExterior
var _shown: PackedScene

func _ready() -> void:
	if Engine.is_editor_hint():
		_show(preview_level)
		return
	_show(GameState.house.level)
	GameState.house.level_changed.connect(_show)

func _show(level: int) -> void:
	var scene := HouseManager.scene_for(level, base_exterior, false)
	if scene == _shown and is_instance_valid(exterior):
		return
	if is_instance_valid(exterior):
		remove_child(exterior)
		exterior.queue_free()
	_shown = scene
	exterior = null
	if scene == null:
		return
	exterior = scene.instantiate() as HouseExterior
	if exterior == null:
		push_error("Scene eksterior rumah harus memakai house_exterior.gd: " + scene.resource_path)
		return
	exterior.name = "Exterior"
	add_child(exterior)
	if not Engine.is_editor_hint():
		# Deferred: farm.gd membuat SocialMailbox di _ready-nya, setelah _ready node anak.
		_apply_to_world.call_deferred()

func _apply_to_world() -> void:
	var world := get_node_or_null(world_path)
	if world == null or not is_instance_valid(exterior):
		return
	for anchor in exterior.anchors():
		var target := world.get_node_or_null(anchor.target_path) as Node2D
		if target != null:
			target.global_position = anchor.global_position
	if exterior.clear_area.has_area():
		_clear_objects(world, exterior.get_global_transform() * exterior.clear_area)

## Pohon/batu cleanup di bawah rumah baru hilang permanen, seperti dibersihkan tukang.
func _clear_objects(world: Node, area: Rect2) -> void:
	for node in world.find_children("*", "Node2D", true, false):
		var object := node as Choppable
		if object == null or not object.persistent or not area.has_point(object.global_position):
			continue
		var removed := object._removed_ids()
		var key := object._persistence_key()
		if not removed.has(key):
			removed.append(key)
		object.queue_free()
