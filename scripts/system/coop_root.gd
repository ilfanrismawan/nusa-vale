extends Control

## Scene utama co-op lokal: 2-4 layar (SubViewport) dan area yang sedang dimuat.
##
## - Setiap area (Farm, Forest, rumah, ...) dimuat sekali ke SubViewport tersembunyi yang
##   memiliki World2D-nya. Pemain di area yang sama berbagi World2D itu.
## - Setiap pemain punya layar sendiri: SubViewport dengan world_2d = World2D area pemain,
##   berisi Camera2D, HUD, hotbar, dan tas pemain itu (dipindah dari Player.tscn saat spawn).
## - Pemain bebas berada di area berbeda. Area tanpa pemain dilepas dari memori.
## - Input dari root diteruskan ke tiap area (push_input) supaya Player dan objek dunia
##   tetap menerima _unhandled_input; tiap pemain menyaring aksinya sendiri (PlayerInput).

const PLAYER_SCENE := preload("res://scenes/player/Player.tscn")
const START_AREA := "res://scenes/world/farm.tscn"
const PLAYER_ROOT_SCRIPT := preload("res://scripts/player/player_root.gd")
const FONT: Font = preload("res://assets/fonts/m5x7.ttf")

## Garis pemisah antar layar (piksel layar).
const GAP := 2
## Ukuran logis 2D layar = ukuran sebenarnya x UI_SCALE, sehingga HUD/tas (dirancang untuk
## 854x480) tetap muat dan font piksel tampil 1:1.
const UI_SCALE := 2.0
## Zoom kamera efektif (piksel layar per piksel dunia) per jumlah pemain.
const EFFECTIVE_ZOOM := {2: 2.0, 3: 1.5, 4: 1.5}
## Jarak antar pemain saat muncul bersama.
const SPAWN_SPREAD := 18.0
const FADE_TIME := 0.3


class Area:
	var path: String
	var host: SubViewport
	var world: Node
	## Path (relatif world) ke parent Player bawaan scene, mis. "." atau "Furniture".
	var player_parent: NodePath = NodePath(".")
	var default_spawn := Vector2.ZERO
	var has_camera_limits := false
	var limit_left := 0
	var limit_top := 0
	var limit_right := 0
	var limit_bottom := 0


## Container layar yang hanya meneruskan mouse ke layar P1.
class ViewContainer extends SubViewportContainer:
	var allow_mouse := true

	func _propagate_input_event(event: InputEvent) -> bool:
		if event is InputEventMouse and not allow_mouse:
			return false
		return true


var _areas: Dictionary = {} # path huruf kecil -> Area
var _containers: Array[ViewContainer] = []
var _views: Array[SubViewport] = []
var _cameras: Array[Camera2D] = []
var _bodies: Array[Player] = []
var _roots: Array[Node2D] = []
var _area_of: Array[String] = []
var _fades: Array[ColorRect] = []
var _juice_layers: Array[CanvasLayer] = []
var _busy: Array[bool] = []
var _sleeping: Dictionary = {} # player_index -> true
var _spare_panel: Control
var _spare_label: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Coop.root = self
	var count := Coop.player_count()

	for i in count:
		_build_view(i)
	_build_spare_panel(count)
	_layout()
	get_viewport().size_changed.connect(_layout)

	var start := _area(START_AREA)
	for i in count:
		_spawn_player(i, start)

	DayCycle.time_tick.connect(_on_time_tick)
	_on_time_tick(DayCycle.hour, DayCycle.minute)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	Notify.say("Co-op %d pemain dimulai! Masing-masing punya tas dan stamina sendiri." % count)

func _exit_tree() -> void:
	if Coop.root == self:
		Coop.root = null


func _process(_delta: float) -> void:
	for i in _bodies.size():
		if is_instance_valid(_bodies[i]) and is_instance_valid(_cameras[i]):
			_cameras[i].global_position = _bodies[i].global_position


## Teruskan input yang tidak dipakai GUI ke semua area, supaya Player/objek dunia menerimanya.
func _unhandled_input(event: InputEvent) -> void:
	for a in _areas.values():
		var area: Area = a
		if is_instance_valid(area.host) and area.host.is_inside_tree():
			area.host.push_input(event, true)


# ── Akses dari Coop ─────────────────────────────────────────────────

func view_of(index: int) -> SubViewport:
	return _views[index] if index >= 0 and index < _views.size() else null

func camera_of(index: int) -> Camera2D:
	return _cameras[index] if index >= 0 and index < _cameras.size() else null

func body_of(index: int) -> Player:
	return _bodies[index] if index >= 0 and index < _bodies.size() else null

## World area yang sedang dimuat, atau null.
func world_of(path: String) -> Node:
	var key := _key(path)
	if _areas.has(key):
		return (_areas[key] as Area).world
	return null

func juice_layer_of(index: int) -> CanvasLayer:
	return _juice_layers[index] if index >= 0 and index < _juice_layers.size() else null


# ── Layar ───────────────────────────────────────────────────────────

func _build_view(index: int) -> void:
	var container := ViewContainer.new()
	container.name = "View%d" % (index + 1)
	container.stretch = true
	container.allow_mouse = Coop.get_input(index).uses_mouse()
	container.mouse_filter = Control.MOUSE_FILTER_PASS
	container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Layar tetap meneruskan input saat pause (menu pengaturan P1 harus bisa ditutup);
	# UI pemain di dalamnya diset PAUSABLE saat spawn.
	container.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(container)

	var view := SubViewport.new()
	view.name = "Screen"
	view.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	view.snap_2d_transforms_to_pixel = true
	view.size_2d_override_stretch = true
	view.handle_input_locally = false
	container.add_child(view)

	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 95
	view.add_child(fade_layer)
	var fade := ColorRect.new()
	fade.color = Color.BLACK
	fade.modulate.a = 0.0
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_layer.add_child(fade)

	var juice_layer := CanvasLayer.new()
	juice_layer.layer = 25
	view.add_child(juice_layer)

	_containers.append(container)
	_views.append(view)
	_fades.append(fade)
	_juice_layers.append(juice_layer)
	_cameras.append(null)
	_bodies.append(null)
	_roots.append(null)
	_area_of.append("")
	_busy.append(false)

## Kuadran ke-4 saat 3 pemain: jam dan hari.
func _build_spare_panel(count: int) -> void:
	if count != 3:
		return
	_spare_panel = ColorRect.new()
	(_spare_panel as ColorRect).color = Color(0.09, 0.07, 0.1)
	_spare_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_spare_panel)
	_spare_label = Label.new()
	_spare_label.add_theme_font_override("font", FONT)
	_spare_label.add_theme_font_size_override("font_size", 16)
	_spare_label.add_theme_color_override("font_color", Color8(249, 230, 207))
	_spare_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_spare_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_spare_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_spare_panel.add_child(_spare_label)

func _layout() -> void:
	var size_px := get_viewport_rect().size
	var count := _containers.size()
	var rects: Array[Rect2] = []
	var half_w := floorf((size_px.x - GAP) * 0.5)
	var half_h := floorf((size_px.y - GAP) * 0.5)
	var right_x := half_w + GAP
	var bottom_y := half_h + GAP
	match count:
		1:
			rects = [Rect2(Vector2.ZERO, size_px)]
		2:
			# Kiri-kanan: 427x480 lebih nyaman untuk peta tile daripada 854x240.
			rects = [Rect2(0, 0, half_w, size_px.y), Rect2(right_x, 0, size_px.x - right_x, size_px.y)]
		_:
			rects = [
				Rect2(0, 0, half_w, half_h),
				Rect2(right_x, 0, size_px.x - right_x, half_h),
				Rect2(0, bottom_y, half_w, size_px.y - bottom_y),
				Rect2(right_x, bottom_y, size_px.x - right_x, size_px.y - bottom_y),
			]
	for i in count:
		var c := _containers[i]
		c.position = rects[i].position
		c.size = rects[i].size
		var ui_scale := UI_SCALE if count > 1 else 1.0
		_views[i].size_2d_override = Vector2i((rects[i].size * ui_scale).round())
	if _spare_panel != null and rects.size() >= 4:
		_spare_panel.position = rects[3].position
		_spare_panel.size = rects[3].size
	for i in count:
		_apply_camera(i)


# ── Area ────────────────────────────────────────────────────────────

func _key(path: String) -> String:
	return path.to_lower()

func _area(path: String) -> Area:
	var key := _key(path)
	if _areas.has(key):
		return _areas[key]

	var packed := load(path) as PackedScene
	if packed == null:
		push_error("CoopRoot: area tidak bisa dimuat: %s" % path)
		return null
	var world := packed.instantiate()
	var area := Area.new()
	area.path = path
	area.world = world
	_take_embedded_player(world, area)

	var host := SubViewport.new()
	host.name = "Area_%s" % path.get_file().get_basename()
	host.size = Vector2i(2, 2)
	host.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(host)
	area.host = host
	_areas[key] = area
	host.add_child(world)
	return area

## Player bawaan scene dibuang; posisi dan batas kameranya dipakai untuk pemain co-op.
func _take_embedded_player(world: Node, area: Area) -> void:
	var embedded := _find_player_root(world)
	if embedded == null:
		return
	var body := embedded.get_node_or_null("CharacterBody2D") as Node2D
	var xf := Transform2D.IDENTITY
	var node: Node = body if body != null else embedded
	while node != null:
		if node is Node2D:
			xf = (node as Node2D).transform * xf
		if node == world:
			break
		node = node.get_parent()
	area.default_spawn = xf.origin
	var cam := embedded.get_node_or_null("CharacterBody2D/Camera2D") as Camera2D
	if cam != null:
		area.has_camera_limits = true
		area.limit_left = cam.limit_left
		area.limit_top = cam.limit_top
		area.limit_right = cam.limit_right
		area.limit_bottom = cam.limit_bottom
	var parent := embedded.get_parent()
	area.player_parent = world.get_path_to(parent) if parent != world else NodePath(".")
	parent.remove_child(embedded)
	embedded.free()

func _find_player_root(node: Node) -> Node2D:
	for child in node.get_children():
		if child is Node2D and child.get_script() == PLAYER_ROOT_SCRIPT:
			return child
		var found := _find_player_root(child)
		if found != null:
			return found
	return null

func _player_parent(area: Area) -> Node:
	var parent := area.world.get_node_or_null(area.player_parent)
	return parent if parent != null else area.world

## Lepas area yang tidak ada pemainnya.
func _unload_unused() -> void:
	for key in _areas.keys():
		if _area_of.has(key):
			continue
		var area: Area = _areas[key]
		_areas.erase(key)
		if is_instance_valid(area.host):
			area.host.queue_free()


# ── Pemain ──────────────────────────────────────────────────────────

func _spawn_player(index: int, area: Area) -> void:
	var proot: Node2D = PLAYER_SCENE.instantiate()
	proot.set("player_index", index)
	proot.name = "Player%d" % (index + 1)
	_player_parent(area).add_child(proot)

	var body := proot.get_node("CharacterBody2D") as Player
	var view := _views[index]
	# UI dan kamera pindah ke layar pemain ini; pemain lain tidak memegang menu pengaturan.
	for ui_name in ["HotbarUi", "HUD", "UIInventory", "SettingsMenu"]:
		var ui := proot.get_node_or_null(ui_name)
		if ui == null:
			continue
		if ui_name == "SettingsMenu" and index > 0:
			ui.queue_free()
			continue
		if ui.process_mode == Node.PROCESS_MODE_INHERIT:
			ui.process_mode = Node.PROCESS_MODE_PAUSABLE
		ui.reparent(view, false)
	var cam := body.get_node_or_null("Camera2D") as Camera2D
	if cam != null:
		cam.process_mode = Node.PROCESS_MODE_PAUSABLE
		cam.reparent(view, false)
		if cam.has_method("set_coop_mode"):
			cam.set_coop_mode(Coop.get_input(index).uses_mouse(), UI_SCALE)
		cam.make_current()

	_roots[index] = proot
	_bodies[index] = body
	_cameras[index] = cam
	_area_of[index] = _key(area.path)
	view.world_2d = area.host.world_2d
	body.refresh_world()
	_set_player_position(index, _spread(area.default_spawn, index))
	_apply_camera(index)
	if cam != null:
		cam.global_position = body.global_position
		cam.reset_smoothing()

## Root Player yang dipindah (player_root.gd menyalin gerak body ke root tiap frame fisika).
func _set_player_position(index: int, pos: Vector2) -> void:
	_roots[index].global_position = pos
	_bodies[index].position = Vector2.ZERO

func _spread(spawn: Vector2, index: int) -> Vector2:
	var count := float(Coop.player_count())
	return spawn + Vector2((float(index) - (count - 1.0) * 0.5) * SPAWN_SPREAD, 0.0)

func _apply_camera(index: int) -> void:
	var cam := _cameras[index]
	if cam == null or _area_of[index].is_empty() or not _areas.has(_area_of[index]):
		return
	var area: Area = _areas[_area_of[index]]
	if area.has_camera_limits:
		cam.limit_left = area.limit_left
		cam.limit_top = area.limit_top
		cam.limit_right = area.limit_right
		cam.limit_bottom = area.limit_bottom
	var count := Coop.player_count()
	var effective: float = EFFECTIVE_ZOOM.get(count, 2.0)
	if cam.has_method("set_default_zoom"):
		cam.set_default_zoom(effective * UI_SCALE)
	else:
		cam.zoom = Vector2.ONE * effective * UI_SCALE

## Pindahkan satu pemain ke area lain (pintu). Pemain lain tidak ikut.
func move_player(body: Player, path: String, spawn: Variant = null) -> void:
	var index := body.player_index
	if index < 0 or index >= _bodies.size() or _busy[index]:
		return
	_busy[index] = true
	body.set_input_locked(&"transition", true)
	body.velocity = Vector2.ZERO
	await _fade(index, 1.0)

	var area := _area(path)
	if area != null:
		_place(index, area, spawn)
		_unload_unused()

	await get_tree().create_timer(0.1, true).timeout
	await _fade(index, 0.0)
	body.set_input_locked(&"transition", false)
	_busy[index] = false

## Semua pemain ke satu area (mis. pingsan, bangun di rumah).
func move_all(path: String, spawn: Variant = null) -> void:
	var area := _area(path)
	if area == null:
		return
	for i in _bodies.size():
		var base: Variant = spawn
		if spawn is Vector2:
			base = _spread(spawn, i)
		_place(i, area, base)
	_unload_unused()

func _place(index: int, area: Area, spawn: Variant) -> void:
	var proot := _roots[index]
	var body := _bodies[index]
	if not is_instance_valid(proot) or not is_instance_valid(body):
		return
	var target_parent := _player_parent(area)
	if proot.get_parent() != target_parent:
		proot.reparent(target_parent, false)
	_area_of[index] = _key(area.path)
	_views[index].world_2d = area.host.world_2d
	body.refresh_world()
	body.velocity = Vector2.ZERO
	_set_player_position(index, spawn if spawn is Vector2 else _spread(area.default_spawn, index))
	_apply_camera(index)
	var cam := _cameras[index]
	if cam != null:
		cam.global_position = body.global_position
		cam.reset_smoothing()

func _fade(index: int, alpha: float) -> void:
	var fade := _fades[index]
	var tw := fade.create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(fade, "modulate:a", alpha, FADE_TIME)
	await tw.finished


# ── Tidur bersama ───────────────────────────────────────────────────

func set_sleeping(player: Player, sleeping: bool) -> int:
	if sleeping:
		_sleeping[player.player_index] = true
	else:
		_sleeping.erase(player.player_index)
	player.set_input_locked(&"sleep", sleeping)
	return _sleeping.size()

func is_sleeping(player: Player) -> bool:
	return player != null and _sleeping.has(player.player_index)

func clear_sleeping() -> void:
	for index in _sleeping.keys():
		var body := body_of(index)
		if is_instance_valid(body):
			body.set_input_locked(&"sleep", false)
	_sleeping.clear()


# ── Lain-lain ───────────────────────────────────────────────────────

func _on_time_tick(hour: int, minute: int) -> void:
	if _spare_label == null:
		return
	_spare_label.text = "Nusa Vale\n%s hari %d\n%02d:%02d" % [
		DayCycle.get_season_display_name(), DayCycle.get_day_of_season(), hour, minute,
	]

func _on_joy_connection_changed(device: int, connected: bool) -> void:
	for i in Coop.inputs.size():
		if Coop.inputs[i].device != device:
			continue
		var body := body_of(i)
		if is_instance_valid(body):
			body.set_input_locked(&"disconnected", not connected)
		if connected:
			Notify.say("P%d: kontroler tersambung lagi." % (i + 1))
		else:
			Notify.say("P%d: kontroler terputus. Sambungkan lagi untuk lanjut." % (i + 1))
