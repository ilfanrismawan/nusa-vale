## Zoom kamera player.
## Kontrol: Ctrl + scroll mouse, tombol = / - (atau numpad + / -), 0 untuk reset.
## Pasang script ini ke node Camera2D di Player.tscn.
## Nilai zoom dibawa antar scene lewat static var; tidak disimpan di save.
extends Camera2D

const ZOOM_MIN: float = 1.0
const ZOOM_MAX: float = 3.0
const ZOOM_STEP: float = 0.25
const TWEEN_TIME: float = 0.15

const ACTION_ZOOM_IN: StringName = &"camera_zoom_in"
const ACTION_ZOOM_OUT: StringName = &"camera_zoom_out"
const ACTION_ZOOM_RESET: StringName = &"camera_zoom_reset"

# Zoom terakhir selama game berjalan (0 = belum pernah diubah, pakai zoom bawaan scene).
static var _session_zoom: float = 0.0

var _default_zoom: float = 1.0
var _target_zoom: float = 1.0
var _tween: Tween

## Co-op: hanya kamera P1 (keyboard + mouse) yang menerima tombol zoom, zoom tidak dibawa
## lewat _session_zoom, dan batas zoom dikali `_zoom_scale` (layar co-op digambar 2x).
var _accept_input := true
var _share_zoom := true
var _zoom_scale := 1.0

func _ready() -> void:
	_ensure_input_actions()
	_default_zoom = zoom.x
	var start_zoom: float = _session_zoom if _session_zoom > 0.0 else _default_zoom
	_target_zoom = _clamp_zoom(start_zoom)
	zoom = Vector2(_target_zoom, _target_zoom)
	get_viewport().size_changed.connect(_on_viewport_size_changed)

## Dipanggil CoopRoot setelah kamera dipindah ke layar pemain.
func set_coop_mode(accept_input: bool, zoom_scale: float) -> void:
	_accept_input = accept_input
	_share_zoom = false
	_zoom_scale = zoom_scale
	var vp := get_viewport()
	if vp != null and not vp.size_changed.is_connected(_on_viewport_size_changed):
		vp.size_changed.connect(_on_viewport_size_changed)

## Zoom bawaan baru (mis. per jumlah pemain co-op); zoom saat ini ikut di-reset.
func set_default_zoom(value: float) -> void:
	_default_zoom = value
	_target_zoom = _clamp_zoom(value)
	if _tween != null and _tween.is_valid():
		_tween.kill()
	zoom = Vector2(_target_zoom, _target_zoom)

# Pakai _input (bukan _unhandled_input) supaya Ctrl + scroll diproses sebelum
# HotbarUi/ToolController yang memakai scroll untuk ganti slot.
# Saat inventory/toko/menu terbuka, tree di-pause sehingga zoom otomatis nonaktif.
func _input(event: InputEvent) -> void:
	if not _accept_input:
		return
	if event.is_action_pressed(ACTION_ZOOM_IN, false, true):
		_set_zoom(_target_zoom + ZOOM_STEP)
	elif event.is_action_pressed(ACTION_ZOOM_OUT, false, true):
		_set_zoom(_target_zoom - ZOOM_STEP)
	elif event.is_action_pressed(ACTION_ZOOM_RESET, false, true):
		_set_zoom(_default_zoom)
	else:
		return
	get_viewport().set_input_as_handled()

func _set_zoom(value: float) -> void:
	var new_zoom: float = _clamp_zoom(value)
	if _share_zoom:
		_session_zoom = new_zoom
	if is_equal_approx(new_zoom, _target_zoom):
		return
	_target_zoom = new_zoom
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "zoom", Vector2(new_zoom, new_zoom), TWEEN_TIME)

func _clamp_zoom(value: float) -> float:
	# Jangan zoom out melebihi area limit kamera, supaya tidak terlihat area hitam di luar peta.
	var min_zoom: float = maxf(ZOOM_MIN * _zoom_scale, _min_zoom_for_limits())
	return clampf(value, min_zoom, maxf(min_zoom, ZOOM_MAX * _zoom_scale))

func _min_zoom_for_limits() -> float:
	var view_size: Vector2 = get_viewport_rect().size
	var limit_width: float = float(limit_right - limit_left)
	var limit_height: float = float(limit_bottom - limit_top)
	if limit_width <= 0.0 or limit_height <= 0.0:
		return 0.0
	return maxf(view_size.x / limit_width, view_size.y / limit_height)

func _on_viewport_size_changed() -> void:
	_set_zoom(_target_zoom)

# Daftarkan action default bila belum ada di Project Settings > Input Map.
# Jika action dibuat sendiri di Input Map, binding dari sana yang dipakai.
func _ensure_input_actions() -> void:
	_add_default_action(ACTION_ZOOM_IN, [_key_event(KEY_EQUAL), _key_event(KEY_KP_ADD), _wheel_event(MOUSE_BUTTON_WHEEL_UP)])
	_add_default_action(ACTION_ZOOM_OUT, [_key_event(KEY_MINUS), _key_event(KEY_KP_SUBTRACT), _wheel_event(MOUSE_BUTTON_WHEEL_DOWN)])
	_add_default_action(ACTION_ZOOM_RESET, [_key_event(KEY_0)])

func _add_default_action(action: StringName, events: Array[InputEvent]) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for e in events:
		InputMap.action_add_event(action, e)

func _key_event(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	return e

func _wheel_event(button: MouseButton) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.ctrl_pressed = true
	e.pressed = true
	return e
