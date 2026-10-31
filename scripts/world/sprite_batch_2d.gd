@tool
class_name SpriteBatch2D
extends Node2D
## Menggambar ratusan sprite dekorasi statis (mis. pohon pembatas hutan) tanpa
## satu node per sprite. Tiap instance menjadi canvas item RenderingServer di
## bawah node ini, jadi Y-sort induk, culling, CanvasModulate dan cahaya tetap
## bekerja seperti Sprite2D biasa. Anak Sprite2D/StaticBody2D biasa tetap boleh
## ditambahkan dan tidak terpengaruh. Isi data dengan tools/bake_sprite_batch.gd.

## Tekstur unik; `texture_ids` menunjuk indeks di sini.
@export var textures: Array[Texture2D] = []:
	set(value):
		textures = value
		_queue_rebuild()
## Offset gambar per tekstur (sama dengan Sprite2D.offset).
@export var texture_offsets: PackedVector2Array = []:
	set(value):
		texture_offsets = value
		_queue_rebuild()
## Palet modulate; `color_ids` menunjuk indeks di sini.
@export var colors: PackedColorArray = [Color.WHITE]:
	set(value):
		colors = value
		_queue_rebuild()
@export var positions: PackedVector2Array = []:
	set(value):
		positions = value
		_queue_rebuild()
@export var texture_ids: PackedByteArray = []:
	set(value):
		texture_ids = value
		_queue_rebuild()
@export var color_ids: PackedByteArray = []:
	set(value):
		color_ids = value
		_queue_rebuild()
## 1 = flip_h.
@export var flips: PackedByteArray = []:
	set(value):
		flips = value
		_queue_rebuild()

var _items: Array[RID] = []
var _rebuild_queued := false


func instance_count() -> int:
	return positions.size()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_ENTER_CANVAS:
			_rebuild()
		NOTIFICATION_EXIT_CANVAS, NOTIFICATION_PREDELETE:
			_free_items()


func _queue_rebuild() -> void:
	if _rebuild_queued or not is_inside_tree():
		return
	_rebuild_queued = true
	_rebuild.call_deferred()


func _rebuild() -> void:
	_rebuild_queued = false
	_free_items()
	if not is_inside_tree():
		return
	var parent := get_canvas_item()
	for i in positions.size():
		var texture_id := int(texture_ids[i]) if i < texture_ids.size() else 0
		if texture_id >= textures.size() or textures[texture_id] == null:
			continue
		var texture := textures[texture_id]
		var size := texture.get_size()
		var offset := texture_offsets[texture_id] if texture_id < texture_offsets.size() else Vector2.ZERO
		# Sama dengan Sprite2D centered: lebar negatif = flip_h di tempat.
		var rect := Rect2(offset - size * 0.5, size)
		if i < flips.size() and flips[i] & 1:
			rect.size.x = -size.x
		var item := RenderingServer.canvas_item_create()
		RenderingServer.canvas_item_set_parent(item, parent)
		RenderingServer.canvas_item_set_transform(item, Transform2D(0.0, positions[i]))
		RenderingServer.canvas_item_set_default_texture_filter(item, RenderingServer.CANVAS_ITEM_TEXTURE_FILTER_NEAREST)
		var color_id := int(color_ids[i]) if i < color_ids.size() else 0
		if color_id < colors.size():
			RenderingServer.canvas_item_set_modulate(item, colors[color_id])
		texture.draw_rect_region(item, rect, Rect2(Vector2.ZERO, size))
		_items.append(item)


func _free_items() -> void:
	for item in _items:
		RenderingServer.free_rid(item)
	_items.clear()
