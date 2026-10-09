class_name FishingMinigame
extends CanvasLayer

signal finished(success: bool)

const TEX_TRACK: Texture2D = preload("res://assets/farm_rpg/ui/fishing/bar_track.png")
const TEX_ZONE: Texture2D = preload("res://assets/farm_rpg/ui/fishing/bar_zone.png")
const TEX_FISH: Texture2D = preload("res://assets/farm_rpg/ui/fishing/fish_icon.png")
const TEX_FISH_LEGENDARY: Texture2D = preload("res://assets/farm_rpg/ui/fishing/fish_icon_legendary.png")

# --- Isi sebenarnya tiap gambar (tanpa padding transparan), satuan piksel gambar ---
const TRACK_RECT := Rect2(10, 8, 9, 59)
const ZONE_RECT := Rect2(5, 3, 10, 24)
const FISH_RECT := Rect2(5, 4, 7, 9)
const FISH_LEGENDARY_RECT := Rect2(5, 3, 7, 10)

# 9-slice zona: ujung membulat tidak ikut melar
const ZONE_MARGIN_X := 3
const ZONE_MARGIN_TOP := 5
const ZONE_MARGIN_BOTTOM := 3

# --- Tata letak di dalam track (koordinat setelah dipotong) ---
const TRACK_W := 9.0
const TRACK_H := 59.0
const SLOT_Y := 16.0
const SLOT_H := 40.0
const ZONE_X := 1.0
const ZONE_W := 7.0
const PROGRESS_W := 3.0
const PROGRESS_GAP := 2.0

# --- Ukuran zona dalam piksel gambar ---
const ZONE_PX_EASY := 18.0
const ZONE_PX_HARD := 11.0

# --- Proporsi meniru Stardew Valley (hasil ukur screenshot) ---
const SIZE_RATIO := 4.88        # tinggi bar : tinggi karakter
const GAP_RATIO := 0.50         # jarak tepi karakter ke tepi bar (satuan tinggi karakter)
const V_OFFSET_RATIO := -0.15   # pusat bar sedikit lebih tinggi dari pusat karakter
const PREFER_LEFT := true       # Stardew menaruh bar di kiri karakter
const PIXEL_PERFECT := false    # true = skala dibulatkan (tajam, tetapi ukuran bisa melenceng)

# --- Ukuran karakter Anda (sprite Idle 32x32, bagian yang terlihat) ---
const PLAYER_H := 19.5          # tinggi terlihat, piksel dunia
const PLAYER_W := 12.0          # lebar terlihat, piksel dunia

# --- Tampilan responsif ---
const FALLBACK_HEIGHT_RATIO := 0.40 # dipakai bila tidak ada pemain untuk diikuti
const MIN_SCALE := 1.0
const MAX_SCALE := 8.0
const SCREEN_MARGIN := 8.0

# --- Penyetelan gameplay ---
const MAX_TIME := 25.0
const LIFT := 2.2
const GRAVITY := 2.0
const MAX_ZONE_SPEED := 1.0
const FILL_RATE := 0.30
const DRAIN_RATE := 0.20

var difficulty := 0.5
var follow_target: Node2D # diisi FishingState; null = tempel di sisi kanan layar

var _legendary := false
var _block_w := 0.0
var _root: Control
var _side := 0             # 0 = belum ditentukan, -1 = kiri pemain, 1 = kanan pemain

var _zone_size := 0.3
var _zone_position := 0.5
var _zone_velocity := 0.0
var _fish_position := 0.5
var _fish_target := 0.5
var _fish_timer := 0.0
var _fish_h := 9.0
var _fish_min := 0.11
var _progress := 0.3
var _time := 0.0
var _done := false

var _zone_rect: NinePatchRect
var _fish_rect: TextureRect
var _fill_rect: ColorRect

func setup(p_difficulty: float, zone_bonus: float = 0.0, legendary: bool = false) -> void:
	difficulty = clampf(p_difficulty, 0.0, 1.0)
	_legendary = legendary
	var zone_px := lerpf(ZONE_PX_EASY, ZONE_PX_HARD, difficulty)
	_zone_size = clampf(zone_px / SLOT_H + zone_bonus, 0.2, 0.7)

func _ready() -> void:
	layer = 10
	process_priority = 100 # jalan setelah kamera, supaya posisi tidak telat satu frame
	_block_w = TRACK_W + PROGRESS_GAP + PROGRESS_W + 2.0

	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_root)

	var track := TextureRect.new()
	track.texture = _atlas(TEX_TRACK, TRACK_RECT)
	_root.add_child(track)

	_zone_rect = NinePatchRect.new()
	_zone_rect.texture = TEX_ZONE
	_zone_rect.region_rect = ZONE_RECT
	_zone_rect.patch_margin_left = ZONE_MARGIN_X
	_zone_rect.patch_margin_right = ZONE_MARGIN_X
	_zone_rect.patch_margin_top = ZONE_MARGIN_TOP
	_zone_rect.patch_margin_bottom = ZONE_MARGIN_BOTTOM
	_root.add_child(_zone_rect)

	var fish_tex: AtlasTexture
	if _legendary:
		fish_tex = _atlas(TEX_FISH_LEGENDARY, FISH_LEGENDARY_RECT)
	else:
		fish_tex = _atlas(TEX_FISH, FISH_RECT)
	_fish_rect = TextureRect.new()
	_fish_rect.texture = fish_tex
	_fish_rect.position.x = roundf((TRACK_W - fish_tex.get_width()) * 0.5)
	_fish_h = float(fish_tex.get_height())
	_fish_min = (_fish_h * 0.5) / SLOT_H
	_root.add_child(_fish_rect)

	var bar_frame := ColorRect.new()
	bar_frame.color = Color8(28, 10, 24)
	bar_frame.position = Vector2(TRACK_W + PROGRESS_GAP, SLOT_Y - 1.0)
	bar_frame.size = Vector2(PROGRESS_W + 2.0, SLOT_H + 2.0)
	_root.add_child(bar_frame)

	var bar_bg := ColorRect.new()
	bar_bg.color = Color8(74, 33, 35)
	bar_bg.position = Vector2(1, 1)
	bar_bg.size = Vector2(PROGRESS_W, SLOT_H)
	bar_frame.add_child(bar_bg)

	_fill_rect = ColorRect.new()
	_fill_rect.color = Color8(236, 196, 58)
	_fill_rect.size.x = PROGRESS_W
	bar_bg.add_child(_fill_rect)

	_layout()
	_redraw()

func _atlas(tex: Texture2D, region: Rect2) -> AtlasTexture:
	var a := AtlasTexture.new()
	a.atlas = tex
	a.region = region
	return a

func _process(delta: float) -> void:
	if _done:
		return
	_time += delta

	_layout()

	_fish_timer -= delta
	if _fish_timer <= 0.0:
		_fish_target = randf_range(_fish_min, 1.0 - _fish_min)
		_fish_timer = maxf(0.3, randf_range(0.6, 1.6) - difficulty * 0.4)
	_fish_position = move_toward(_fish_position, _fish_target, lerpf(0.35, 0.9, difficulty) * delta)

	var acceleration := LIFT if Input.is_action_pressed("use_tool") else -GRAVITY
	_zone_velocity = clampf(_zone_velocity + acceleration * delta, -MAX_ZONE_SPEED, MAX_ZONE_SPEED)
	_zone_position += _zone_velocity * delta

	var half := _zone_size * 0.5
	if _zone_position < half:
		_zone_position = half
		_zone_velocity = 0.0
	elif _zone_position > 1.0 - half:
		_zone_position = 1.0 - half
		_zone_velocity = 0.0

	var inside := absf(_fish_position - _zone_position) <= half
	_progress += (FILL_RATE if inside else -DRAIN_RATE) * delta

	_redraw()

	if _progress >= 1.0:
		_end(true)
	elif _progress <= 0.0 or _time >= MAX_TIME:
		_end(false)

# ── Layout: ukuran proporsional terhadap karakter, posisi di samping karakter ──
func _compute_scale(vp: Vector2, target_h: float) -> float:
	var s := target_h / TRACK_H
	if PIXEL_PERFECT:
		s = roundf(s)
	s = clampf(s, MIN_SCALE, MAX_SCALE)
	# jangan pernah lebih besar dari layar (jendela sangat kecil)
	var fit_h := maxf((vp.y - SCREEN_MARGIN * 2.0) / TRACK_H, 0.25)
	var fit_w := maxf((vp.x - SCREEN_MARGIN * 2.0) / _block_w, 0.25)
	return minf(s, minf(fit_h, fit_w))

func _layout() -> void:
	var vp := get_viewport().get_visible_rect().size
	var has_target := is_instance_valid(follow_target)
	var ct := get_viewport().get_canvas_transform()
	var zoom := ct.get_scale().x
	var player_h := PLAYER_H * zoom # tinggi karakter di layar

	var target_h := vp.y * FALLBACK_HEIGHT_RATIO
	if has_target:
		target_h = SIZE_RATIO * player_h

	var s := _compute_scale(vp, target_h)
	_root.scale = Vector2.ONE * s
	var size_px := Vector2(_block_w, TRACK_H) * s

	var pos: Vector2
	if has_target:
		var anchor: Vector2 = ct * follow_target.global_position
		var gap := GAP_RATIO * player_h + PLAYER_W * 0.5 * zoom
		var left_x := anchor.x - gap - size_px.x
		var right_x := anchor.x + gap
		if _side == 0: # sisi ditentukan sekali, supaya bar tidak berpindah-pindah
			_side = -1 if PREFER_LEFT else 1
			if _side < 0 and left_x < SCREEN_MARGIN:
				_side = 1
			elif _side > 0 and right_x + size_px.x > vp.x - SCREEN_MARGIN:
				_side = -1
		var x := left_x if _side < 0 else right_x
		pos = Vector2(x, anchor.y + V_OFFSET_RATIO * player_h - size_px.y * 0.5)
	else:
		pos = Vector2(vp.x - size_px.x - SCREEN_MARGIN, (vp.y - size_px.y) * 0.5)

	pos.x = clampf(pos.x, SCREEN_MARGIN, maxf(SCREEN_MARGIN, vp.x - size_px.x - SCREEN_MARGIN))
	pos.y = clampf(pos.y, SCREEN_MARGIN, maxf(SCREEN_MARGIN, vp.y - size_px.y - SCREEN_MARGIN))
	_root.position = pos.round()

func _redraw() -> void:
	var zone_top := SLOT_Y + SLOT_H * (1.0 - (_zone_position + _zone_size * 0.5))
	_zone_rect.position = Vector2(ZONE_X, roundf(zone_top))
	_zone_rect.size = Vector2(ZONE_W, roundf(SLOT_H * _zone_size))

	var fish_center := SLOT_Y + SLOT_H * (1.0 - _fish_position)
	_fish_rect.position.y = roundf(fish_center - _fish_h * 0.5)

	_fill_rect.size.y = roundf(SLOT_H * clampf(_progress, 0.0, 1.0))
	_fill_rect.position.y = SLOT_H - _fill_rect.size.y

func _end(success: bool) -> void:
	if _done:
		return
	_done = true
	finished.emit(success)
	queue_free()
