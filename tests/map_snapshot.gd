extends Node2D
## Snapshot peta (alat bantu Claude): salin layer tile + sprite + kolisi sebuah scene ke SubViewport,
## gambar grid koordinat tiap 80 px, simpan ke tests/_snapshots/map_<nama>.png. Script scene sumber tidak dijalankan.
@export_file("*.tscn") var target := "res://scenes/world/DeepForest.tscn"
@export var crop := Rect2i()
const OUT_DIR := "res://tests/_snapshots"

func _ready() -> void:
	var path := target
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scene="):
			path = arg.substr(8)
	await get_tree().create_timer(0.5, true).timeout
	var source := (load(path) as PackedScene).instantiate()
	var rect := Rect2()
	var view := SubViewport.new()
	view.world_2d = World2D.new()
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(view)
	var holder := Node2D.new()
	holder.y_sort_enabled = true
	for node in source.get_children():
		if node is TileMapLayer:
			var layer: TileMapLayer = node.duplicate(0)
			layer.set_script(null)
			layer.visible = node.name != "ResourceSpawnMask"
			view.add_child(layer)
			if layer.tile_set != null and layer.get_used_rect().size != Vector2i.ZERO:
				var used := layer.get_used_rect()
				var r := Rect2(Vector2(used.position * layer.tile_set.tile_size), Vector2(used.size * layer.tile_set.tile_size))
				rect = r if rect.size == Vector2.ZERO else rect.merge(r)
	view.add_child(holder)
	_copy_visuals(source, holder)
	var overlay := _Overlay.new()
	overlay.source = source
	overlay.rect = rect
	view.add_child(overlay)
	if crop.size != Vector2i.ZERO:
		rect = Rect2(crop)
	view.size = Vector2i(rect.size)
	var cam := Camera2D.new()
	cam.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	cam.position = rect.position
	view.add_child(cam)
	cam.make_current()
	await get_tree().create_timer(0.8, true).timeout
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var file := OUT_DIR.path_join("map_%s.png" % path.get_file().get_basename())
	var err := view.get_texture().get_image().save_png(ProjectSettings.globalize_path(file))
	print("map_snapshot: %s rect=%s -> %s" % [file, rect, error_string(err)])
	await get_tree().create_timer(4.0, true).timeout
	get_tree().quit()

func _copy_visuals(node: Node, holder: Node2D) -> void:
	for child in node.get_children():
		if child is TileMapLayer:
			continue
		if child is Sprite2D or child is AnimatedSprite2D:
			var copy: Node2D = child.duplicate(0)
			copy.set_script(null)
			for c in copy.get_children():
				c.free()
			copy.global_position = child.global_position if child.is_inside_tree() else _pos(child)
			holder.add_child(copy)
		_copy_visuals(child, holder)

func _pos(node: Node) -> Vector2:
	var p := Vector2.ZERO
	var n := node
	while n != null and n is Node2D:
		p = (n as Node2D).transform * p
		n = n.get_parent()
	return p

class _Overlay extends Node2D:
	var source: Node
	var rect: Rect2
	func _ready() -> void:
		z_index = 100
	func _draw() -> void:
		var font := ThemeDB.fallback_font
		var x := floorf(rect.position.x / 80.0) * 80.0
		while x < rect.end.x:
			draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), Color(1, 1, 1, 0.25))
			x += 80.0
		var y := floorf(rect.position.y / 80.0) * 80.0
		while y < rect.end.y:
			draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), Color(1, 1, 1, 0.25))
			y += 80.0
		x = floorf(rect.position.x / 160.0) * 160.0
		while x < rect.end.x:
			y = floorf(rect.position.y / 160.0) * 160.0
			while y < rect.end.y:
				draw_string(font, Vector2(x + 2, y + 12), "%d,%d" % [x, y], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.YELLOW)
				y += 160.0
			x += 160.0
		_draw_shapes(source)
	func _draw_shapes(node: Node) -> void:
		for child in node.get_children():
			if child is CollisionShape2D and child.shape != null:
				var xf := _xf(child)
				var col := Color(1, 0, 0, 0.35) if child.get_parent() is StaticBody2D else Color(0, 0.6, 1, 0.45)
				draw_set_transform_matrix(xf)
				child.shape.draw(get_canvas_item(), col)
				draw_set_transform_matrix(Transform2D.IDENTITY)
			elif child is CollisionPolygon2D:
				draw_set_transform_matrix(_xf(child))
				if child.polygon.size() >= 3:
					draw_colored_polygon(child.polygon, Color(1, 0, 0, 0.35))
				draw_set_transform_matrix(Transform2D.IDENTITY)
			_draw_shapes(child)
	func _xf(node: Node) -> Transform2D:
		var t := Transform2D.IDENTITY
		var n := node
		while n != null and n is Node2D:
			t = (n as Node2D).transform * t
			n = n.get_parent()
		return t
