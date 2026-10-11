class_name FishingMinigame
extends CanvasLayer

signal finished(success: bool)

const TEX_FRAME: Texture2D = preload("res://assets/farm_rpg/ui/fishing/fishing_frame.png")
const TEX_REEL: Texture2D = preload("res://assets/farm_rpg/ui/fishing/fishing_reel.png")
const TEX_ZONE: Texture2D = preload("res://assets/farm_rpg/ui/fishing/bar_zone.png")
const TEX_FISH: Texture2D = preload("res://assets/farm_rpg/ui/fishing/fish_icon.png")
const TEX_FISH_LEGENDARY: Texture2D = preload("res://assets/farm_rpg/ui/fishing/fish_icon_legendary.png")

# --- Isi sebenarnya tiap gambar (tanpa padding transparan), satuan piksel gambar ---
const ZONE_RECT := Rect2(5, 3, 10, 24)
const FISH_RECT := Rect2(5, 4, 7, 9)
const FISH_LEGENDARY_RECT := Rect2(5, 3, 7, 10)

# 9-slice zona: ujung membulat tidak ikut melar
const ZONE_MARGIN_X := 3
const ZONE_MARGIN_TOP := 5
const ZONE_MARGIN_BOTTOM := 3

# --- Tata letak di dalam bingkai fishing_frame.png (gaya Stardew) ---
const FRAME_W := 27.0
const FRAME_H := 105.0         # bingkai tinggi ramping ala Stardew (rasio ~1:4)
const SLOT_X := 5.0             # kolom air tempat zona dan ikan bergerak
const SLOT_Y := 7.0
const SLOT_W := 10.0
const SLOT_H := 92.0
const PROGRESS_X := 19.0        # kolom progres di kanan
const PROGRESS_W := 3.0
const REEL_SIZE := 11            # fishing_reel.png: 4 frame 11x11
const REEL_FRAMES := 4
const REEL_POS := Vector2(-5, 91) # gulungan menempel di sudut kiri bawah bingkai
const REEL_FRAME_TIME := 0.07
const ZONE_ALPHA := 0.85         # zona sedikit tembus pandang, air tetap terlihat
const INTRO_TIME := 0.18         # bar "tumbuh" dari bawah saat muncul

# --- Ukuran zona dalam piksel gambar ---
const ZONE_PX_EASY := 41.0
const ZONE_PX_HARD := 25.0

# --- Proporsi meniru Stardew Valley (hasil ukur screenshot) ---
const SIZE_RATIO := 4.88        # tinggi bar : tinggi karakter
const GAP_RATIO := 0.50         # jarak tepi karakter ke tepi bar (satuan tinggi karakter)
const V_OFFSET_RATIO := -0.15   # pusat bar sedikit lebih tinggi dari pusat karakter
const PREFER_LEFT := true       # Stardew menaruh bar di kiri karakter
const PIXEL_PERFECT := true     # true = skala dibulatkan (tajam, tetapi ukuran bisa melenceng)

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
const FILL_RATE_EASY := 0.32
const FILL_RATE_HARD := 0.24
const DRAIN_RATE_EASY := 0.15
const DRAIN_RATE_HARD := 0.30

# --- Umpan balik (Juice) ---
const REEL_TICK_INTERVAL := 0.09   # detik antar bunyi gulungan saat ikan di dalam zona
const REEL_PITCH_RANGE := 7.0      # semitone: nada gulungan naik seiring progres
const DANGER_PROGRESS := 0.25      # di bawah ini bar berkedip merah dan bergetar
# Warna isi progres: merah -> kuning -> hijau seperti Stardew (dari palet).
const FILL_LOW := Color8(228, 33, 43)
const FILL_MID := Color8(255, 199, 27)
const FILL_HIGH := Color8(126, 196, 51)
const FILL_DANGER := Color8(246, 70, 78)
const FILL_SHINE := Color8(249, 230, 207)

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
var _fill_rate := 0.30
var _drain_rate := 0.20
var _fish_speed_mult := 1.0
var _time := 0.0
var _done := false
var _tick_timer := 0.0
var _inside := false

var _zone_rect: NinePatchRect
var _fish_rect: TextureRect
var _fish_x := 0.0
var _fill_rect: ColorRect
var _fill_shine: ColorRect
var _reel_rect: TextureRect
var _reel_tex: AtlasTexture
var _reel_frame := 0
var _reel_timer := 0.0


func setup(p_difficulty: float, zone_bonus: float = 0.0, legendary: bool = false) -> void:
	difficulty = clampf(p_difficulty, 0.0, 1.0)
	_legendary = legendary
	var zone_px := lerpf(ZONE_PX_EASY, ZONE_PX_HARD, difficulty)
	_zone_size = clampf(zone_px / SLOT_H + zone_bonus, 0.2, 0.7)
	_fill_rate = lerpf(FILL_RATE_EASY, FILL_RATE_HARD, difficulty)
	_drain_rate = lerpf(DRAIN_RATE_EASY,DRAIN_RATE_HARD, difficulty)

## Kemampuan pancing (RodData). Dipanggil setelah setup().
func apply_rod(rod: RodData) -> void:
	if rod == null:
		return
	_zone_size = clampf(_zone_size * rod.zone_mult, 0.2, 0.7)
	_drain_rate *= rod.drain_mult
	_fish_speed_mult = rod.fish_speed_mult

func _ready() -> void:
	layer = 10
	process_priority = 100 # jalan setelah kamera, supaya posisi tidak telat satu frame
	_block_w = FRAME_W

	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_root)

	var frame := TextureRect.new()
	frame.texture = TEX_FRAME
	_root.add_child(frame)

	_fill_rect = ColorRect.new()
	_fill_rect.size.x = PROGRESS_W
	_fill_rect.position.x = PROGRESS_X
	_root.add_child(_fill_rect)

	_fill_shine = ColorRect.new()
	_fill_shine.color = FILL_SHINE
	_fill_shine.size = Vector2(PROGRESS_W, 1)
	_fill_shine.position.x = PROGRESS_X
	_root.add_child(_fill_shine)

	_zone_rect = NinePatchRect.new()
	_zone_rect.texture = TEX_ZONE
	_zone_rect.region_rect = ZONE_RECT
	_zone_rect.patch_margin_left = ZONE_MARGIN_X
	_zone_rect.patch_margin_right = ZONE_MARGIN_X
	_zone_rect.patch_margin_top = ZONE_MARGIN_TOP
	_zone_rect.patch_margin_bottom = ZONE_MARGIN_BOTTOM
	_zone_rect.modulate.a = ZONE_ALPHA
	_root.add_child(_zone_rect)

	var fish_tex: AtlasTexture
	if _legendary:
		fish_tex = _atlas(TEX_FISH_LEGENDARY, FISH_LEGENDARY_RECT)
	else:
		fish_tex = _atlas(TEX_FISH, FISH_RECT)
	_fish_rect = TextureRect.new()
	_fish_rect.texture = fish_tex
	_fish_x = SLOT_X + roundf((SLOT_W - fish_tex.get_width()) * 0.5)
	_fish_rect.position.x = _fish_x
	_fish_h = float(fish_tex.get_height())
	_fish_min = (_fish_h * 0.5) / SLOT_H
	_root.add_child(_fish_rect)

	_reel_tex = _atlas(TEX_REEL, Rect2(0, 0, REEL_SIZE, REEL_SIZE))
	_reel_rect = TextureRect.new()
	_reel_rect.texture = _reel_tex
	_reel_rect.position = REEL_POS
	_root.add_child(_reel_rect)

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
	_fish_position = move_toward(_fish_position, _fish_target, lerpf(0.35, 0.9, difficulty) * _fish_speed_mult * delta)

	var reeling: bool = follow_target.input.pressed(&"use_tool") if follow_target is Player else Input.is_action_pressed("use_tool")
	if reeling:
		_reel_timer -= delta
		if _reel_timer <= 0.0:
			_reel_timer = REEL_FRAME_TIME
			_reel_frame = (_reel_frame + 1) % REEL_FRAMES
			_reel_tex.region = Rect2(_reel_frame * REEL_SIZE, 0, REEL_SIZE, REEL_SIZE)

	var acceleration := LIFT if reeling else -GRAVITY
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
	_progress += (_fill_rate if inside else - _drain_rate) * delta
	_inside = inside

	if inside:
		_tick_timer -= delta
		if _tick_timer <= 0.0:
			_tick_timer = REEL_TICK_INTERVAL
			Juice.play_sound(&"reel", clampf(_progress, 0.0, 1.0) * REEL_PITCH_RANGE)
	else:
		_tick_timer = 0.0

	_redraw()

	if _progress >= 1.0:
		_end(true)
	elif _progress <= 0.0 or _time >= MAX_TIME:
		_end(false)

# ── Layout: ukuran proporsional terhadap karakter, posisi di samping karakter ──
func _compute_scale(vp: Vector2, target_h: float) -> float:
	var s := target_h / FRAME_H
	if PIXEL_PERFECT:
		s = roundf(s)
	s = clampf(s, MIN_SCALE, MAX_SCALE)
	# jangan pernah lebih besar dari layar (jendela sangat kecil)
	var fit_h := maxf((vp.y - SCREEN_MARGIN * 2.0) / FRAME_H, 0.25)
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
	var size_px := Vector2(_block_w, FRAME_H) * s
	# Muncul: tumbuh dari bawah dengan sedikit overshoot.
	var t := clampf(_time / INTRO_TIME, 0.0, 1.0)
	var grow := 1.0 - pow(1.0 - t, 3.0)
	_root.scale = Vector2(s, s * grow)

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
	pos.y += size_px.y * (1.0 - grow)
	_root.position = pos.round()

func _redraw() -> void:
	var zone_top := SLOT_Y + SLOT_H * (1.0 - (_zone_position + _zone_size * 0.5))
	_zone_rect.position = Vector2(SLOT_X, roundf(zone_top))
	_zone_rect.size = Vector2(SLOT_W, roundf(SLOT_H * _zone_size))

	var fish_center := SLOT_Y + SLOT_H * (1.0 - _fish_position)
	_fish_rect.position.y = roundf(fish_center - _fish_h * 0.5)
	# Ikan meronta saat tertangkap zona (seperti Stardew).
	_fish_rect.position.x = _fish_x + (float(randi_range(-1, 1)) if _inside and randf() < 0.35 else 0.0)

	var p := clampf(_progress, 0.0, 1.0)
	var fill_h := roundf(SLOT_H * p)
	_fill_rect.size.y = fill_h
	_fill_rect.position.y = SLOT_Y + SLOT_H - fill_h
	_fill_shine.position.y = _fill_rect.position.y
	_fill_shine.visible = fill_h >= 2.0

	# Bahaya: progres rendah dan ikan di luar zona -> bar merah berkedip dan bergetar 1 px.
	var danger := not _inside and _progress < DANGER_PROGRESS
	if danger:
		var blink := 0.5 + 0.5 * sin(_time * 18.0)
		_fill_rect.color = FILL_LOW.lerp(FILL_DANGER, blink)
		_root.position.x += float(randi_range(-1, 1))
	else:
		_fill_rect.color = _progress_color(p)

func _progress_color(p: float) -> Color:
	if p < 0.5:
		return FILL_LOW.lerp(FILL_MID, p / 0.5)
	return FILL_MID.lerp(FILL_HIGH, (p - 0.5) / 0.5)

func _end(success: bool) -> void:
	if _done:
		return
	_done = true
	finished.emit(success)
	queue_free()
