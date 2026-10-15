extends CanvasLayer

var player: Player
var item_id := "chicken_coop"
var from_inventory := false
var cell := Vector2i.ZERO
var _camera: Camera2D
var _original_camera: Camera2D
var _ghost: FootprintGuide
var _status: Label
var _confirm_button: Button
var _banner: PanelContainer
var _camera_bounds: Rect2
var _closed := false
var _mouse_moved := true
var _mouse_position := Vector2.ZERO
var _dragging := false
var _left_down := false
var _drag_distance := 0.0
var _edge_scroll_margin := 34.0
var _hud_visible := true
var _hotbar_visible := true

class FootprintGuide extends Node2D:
	var cells := Vector2i.ONE
	var valid := false
	var picture: Sprite2D
	func _draw() -> void:
		var color := Color(0.35, 0.9, 0.5, 0.35) if valid else Color(1, 0.25, 0.25, 0.4)
		var origin := -Vector2(cells) * 8
		for x in cells.x:
			for y in cells.y:
				var rect := Rect2(origin + Vector2(x, y) * 16, Vector2(16, 16))
				draw_rect(rect, color)
				draw_rect(rect, Color(color, 0.85), false, 1)

func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	player.set_input_locked(&"placement", true)
	player.hide()
	_hud_visible = player.hud_ui.visible
	_hotbar_visible = player.hotbar_ui.visible
	player.hud_ui.hide()
	player.hotbar_ui.hide()
	_original_camera = Coop.root.camera_of(player.player_index) if Coop.has_root() else player.get_node("Camera2D")
	_original_camera.enabled = false
	_camera = Camera2D.new()
	_camera.process_mode = Node.PROCESS_MODE_ALWAYS
	_camera.zoom = Vector2(0.85, 0.85)
	get_parent().add_child(_camera)
	_camera.global_position = player.global_position
	_configure_camera_limits()
	_camera.make_current()
	_clamp_camera()
	get_viewport().size_changed.connect(_clamp_camera)
	_mouse_position = get_viewport().get_mouse_position()
	var item := GameState._resolve_item(item_id)
	_ghost = FootprintGuide.new()
	_ghost.cells = item.placement_size
	_ghost.z_index = 200
	_ghost.picture = Sprite2D.new()
	_ghost.picture.texture = item.icon
	_ghost.picture.position.y = -16
	_ghost.add_child(_ghost.picture)
	player.world_root().add_child(_ghost)
	cell = player.get_player_cell() + Vector2i(2, 2)
	_build_ui(item)
	PauseManager.set_reason(&"building_placement", true)
	_update_target()

func _configure_camera_limits() -> void:
	var ground := player.base_layer_ground
	var used := ground.get_used_rect()
	var half_tile := Vector2(ground.tile_set.tile_size) / 2
	var start := ground.to_global(ground.map_to_local(used.position) - half_tile)
	var end := ground.to_global(ground.map_to_local(used.end) - half_tile)
	_camera_bounds = Rect2(start, end - start).abs()
	var original := Rect2(Vector2(_original_camera.limit_left, _original_camera.limit_top), Vector2(_original_camera.limit_right - _original_camera.limit_left, _original_camera.limit_bottom - _original_camera.limit_top))
	var bounded := _camera_bounds.intersection(original)
	if bounded.has_area():
		_camera_bounds = bounded
	_camera.limit_left = ceili(_camera_bounds.position.x)
	_camera.limit_top = ceili(_camera_bounds.position.y)
	_camera.limit_right = floori(_camera_bounds.end.x)
	_camera.limit_bottom = floori(_camera_bounds.end.y)

func _clamp_camera() -> void:
	if not is_instance_valid(_camera) or not _camera_bounds.has_area():
		return
	var view_size := get_viewport().get_visible_rect().size
	var min_zoom := maxf(0.3, maxf(view_size.x / _camera_bounds.size.x, view_size.y / _camera_bounds.size.y))
	_camera.zoom = Vector2.ONE * clampf(_camera.zoom.x, min_zoom, maxf(2.0, min_zoom))
	var half_view := view_size / (_camera.zoom * 2)
	_camera.global_position = _camera.global_position.clamp(_camera_bounds.position + half_view, _camera_bounds.end - half_view)
	_camera.force_update_scroll()

func _build_ui(item: ItemData) -> void:
	var theme := Theme.new()
	theme.default_font = preload("res://resources/ui/readable_font.tres")
	theme.default_font_size = 18
	var banner := PanelContainer.new()
	_banner = banner
	banner.theme = theme
	banner.position = Vector2(12, 12)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("292b3df0")
	style.border_color = Color("efd7a3")
	style.set_border_width_all(2)
	style.set_content_margin_all(8)
	banner.add_theme_stylebox_override("panel", style)
	add_child(banner)
	var rows := VBoxContainer.new()
	banner.add_child(rows)
	var title := Label.new()
	title.text = "Letakkan %s · %dx%d petak" % [item.display_name, item.placement_size.x, item.placement_size.y]
	rows.add_child(title)
	var guide := Label.new()
	guide.text = "Tepi layar/WASD: geser · Tahan kiri/tengah + geser: kamera · Wheel: zoom · Klik kiri/Enter: pasang · Kanan/Esc: batal"
	guide.add_theme_font_size_override("font_size", 14)
	rows.add_child(guide)
	var costs := Label.new()
	costs.text = "Bangunan dari tas — dikonsumsi setelah lokasi dikonfirmasi." if from_inventory else "Biaya %d G + %d kayu + %d batu — dibayar saat konfirmasi." % [int(StructureManager.CONSTRUCTION[item_id].money), int(StructureManager.CONSTRUCTION[item_id].materials.wood), int(StructureManager.CONSTRUCTION[item_id].materials.stone)]
	costs.add_theme_font_size_override("font_size", 14)
	rows.add_child(costs)
	_status = Label.new()
	rows.add_child(_status)
	var buttons := HBoxContainer.new()
	rows.add_child(buttons)
	_confirm_button = Button.new()
	_confirm_button.text = "Bangun di sini"
	_confirm_button.focus_mode = Control.FOCUS_NONE
	_confirm_button.pressed.connect(confirm)
	buttons.add_child(_confirm_button)
	var cancel := Button.new()
	cancel.text = "Batal — tanpa biaya"
	cancel.focus_mode = Control.FOCUS_NONE
	cancel.pressed.connect(close)
	buttons.add_child(cancel)

func _over_ui(viewport_position: Vector2 = Vector2.INF) -> bool:
	var point := _mouse_position if viewport_position == Vector2.INF else viewport_position
	return is_instance_valid(_banner) and _banner.get_global_rect().has_point(point)

func _process(delta: float) -> void:
	if _closed:
		return
	if not is_instance_valid(player) or not player.is_inside_tree():
		close()
		return
	var movement := player.input.get_vector()
	_camera.global_position += movement * delta * 320.0 / _camera.zoom.x
	_clamp_camera()
	if player.input.uses_mouse():
		if not _over_ui():
			var view := get_viewport().get_visible_rect().size
			var edge := Vector2.ZERO
			if _mouse_position.x <= _edge_scroll_margin: edge.x -= 1.0
			elif _mouse_position.x >= view.x - _edge_scroll_margin: edge.x += 1.0
			if _mouse_position.y <= _edge_scroll_margin: edge.y -= 1.0
			elif _mouse_position.y >= view.y - _edge_scroll_margin: edge.y += 1.0
			if edge != Vector2.ZERO:
				_camera.global_position += edge.normalized() * delta * 280.0 / _camera.zoom.x
				_clamp_camera()
		if _mouse_moved and not _over_ui():
			_target_mouse(_mouse_position)
	elif movement.length_squared() > 0:
		cell = player.base_layer_ground.local_to_map(player.base_layer_ground.to_local(_camera.global_position)) - Vector2i(_ghost.cells.x / 2, _ghost.cells.y / 2)
	_update_target()

func _target_mouse(viewport_position: Vector2) -> void:
	_clamp_camera()
	var world_point := get_viewport().get_canvas_transform().affine_inverse() * viewport_position
	# Anchor the visible building, including its roof offset, to the mouse.
	var first_tile_center := world_point - _ghost.picture.position - Vector2(_ghost.cells - Vector2i.ONE) * 8
	cell = player.base_layer_ground.local_to_map(player.base_layer_ground.to_local(first_tile_center))
	_update_target()

func set_target_cell(value: Vector2i) -> void:
	cell = value
	_mouse_moved = false
	_update_target()

func _update_target() -> void:
	var item := GameState._resolve_item(item_id)
	var ground := player.base_layer_ground
	_ghost.global_position = ground.to_global(ground.map_to_local(cell)) + Vector2(item.placement_size - Vector2i.ONE) * 8
	var result := StructureManager.check_construction(player, item_id, cell)
	_ghost.valid = bool(result.ok)
	_ghost.picture.modulate = Color(0.7, 1, 0.8, 0.65) if result.ok else Color(1, 0.45, 0.45, 0.6)
	_ghost.queue_redraw()
	_status.text = result.message
	_status.add_theme_color_override("font_color", Color("86dc9b") if result.ok else Color("ff9d86"))
	_confirm_button.disabled = not result.ok

func _input(event: InputEvent) -> void:
	if _closed or not player.input.owns_event(event):
		return
	if event is InputEventMouseMotion and player.input.uses_mouse():
		_mouse_position = event.position
		_mouse_moved = true
		if _left_down:
			_drag_distance += event.relative.length()
			if _drag_distance > 6.0:
				_dragging = true
		if _dragging:
			_camera.global_position -= event.relative / _camera.zoom.x
		if not _over_ui(event.position):
			_target_mouse(event.position)
	if event is InputEventMouseButton and player.input.uses_mouse():
		_mouse_position = event.position
		if event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			get_viewport().set_input_as_handled()
			close()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if _over_ui(event.position):
					return
				_left_down = true
				_drag_distance = 0.0
			elif not event.pressed and _left_down:
				_left_down = false
				var was_dragging := _dragging
				_dragging = false
				if not was_dragging and not _over_ui(event.position):
					confirm()
			else:
				return
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = event.pressed
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var factor := 1.12 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.12
			_camera.zoom = Vector2.ONE * clampf(_camera.zoom.x * factor, 0.3, 2.0)
			_clamp_camera()
			get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if _closed or not player.input.owns_event(event):
		return
	if player.input.is_event(event, &"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
	elif player.input.is_event(event, &"ui_accept") or player.input.is_event(event, &"use_tool"):
		get_viewport().set_input_as_handled()
		confirm()

func confirm() -> void:
	if _closed:
		return
	var result := StructureManager.commit_construction(player, item_id, cell, from_inventory)
	if not result.ok:
		_status.text = result.message
		return
	Notify.say(result.message)
	var item := GameState._resolve_item(item_id)
	if Rect2i(cell, item.placement_size).has_point(player.get_player_cell()):
		var entrance := cell + Vector2i(item.placement_size.x / 2, item.placement_size.y)
		player.global_position = player.base_layer_ground.to_global(player.base_layer_ground.map_to_local(entrance)) - Player.FEET_OFFSET
	close()

func close() -> void:
	if _closed:
		return
	_closed = true
	_cleanup()
	if is_instance_valid(player):
		BuildingPlacement.finish(player)
	else:
		BuildingPlacement.session.clear()
		BuildingPlacement._opening = false
	queue_free()

func _cleanup() -> void:
	PauseManager.set_reason(&"building_placement", false)
	if is_instance_valid(_ghost):
		_ghost.queue_free()
	if is_instance_valid(_camera):
		_camera.queue_free()
	if is_instance_valid(_original_camera):
		_original_camera.enabled = true
		_original_camera.make_current()
	if is_instance_valid(player):
		player.show()
		player.set_input_locked(&"placement", false)
		player.hud_ui.visible = _hud_visible
		player.hotbar_ui.visible = _hotbar_visible

func _exit_tree() -> void:
	if not _closed:
		_cleanup()
		BuildingPlacement.session.clear()
		BuildingPlacement._opening = false
