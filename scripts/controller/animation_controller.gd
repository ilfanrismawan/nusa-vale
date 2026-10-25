class_name AnimationController
extends Node

signal animated_finished
signal frame_changed(frame: int)

@onready var sprite: AnimatedSprite2D = $"../AnimatedSprite2D"

var _action := "idle"
var _direction := "down"
var _visual_override: StringName
var _facing_left := false
var item_gesture_playing := false
var carrying_item := false
## Menunggang kuda: idle/walk/run diganti horse_idle/horse_walk/horse_run (PNG/14.x Horse).
var riding_horse := false
## Frame yang ditahan untuk pose bidik (mis. busur ditarik). -1 = tidak menahan pose.
var _pose_hold := -1
## Saat membidik sambil bergerak, kaki tetap memakai animasi jalan/lari ini.
const AIM_MOVE_ACTIONS := ["walk", "run"]
const AIM_MOVE_PREFIX := "aim_move_"
## Batas pinggang (bagian tinggi frame): di bawahnya kaki diambil dari animasi jalan.
const AIM_WAIST_RATIO := 20.0 / 32.0
## Animasi bidik-jalan yang sudah dibuat di sesi bidik ini (dibuat ulang tiap mulai membidik
## supaya ganti senjata/pakaian ikut terbawa).
var _aim_move_built := {}

func set_carrying_item(value: bool) -> void:
	if carrying_item == value:
		return
	carrying_item = value
	_apply(true)

func set_riding_horse(value: bool) -> void:
	if riding_horse == value:
		return
	riding_horse = value
	_apply(true)

func _ready() -> void:
	sprite.animation_finished.connect(func():
		if item_gesture_playing:
			item_gesture_playing = false
			_visual_override = &""
			sprite.speed_scale = 1.0
			_apply(false)
		elif _visual_override.is_empty():
			animated_finished.emit())
	sprite.frame_changed.connect(func():
		if _visual_override.is_empty():
			frame_changed.emit(sprite.frame))
	set_direction(Vector2.DOWN)

func restart() -> void:
	sprite.set_frame_and_progress(0, 0.0)
	sprite.play()
		
func play(action: StringName) -> void:	
	_action = String(action).to_lower()
	_apply(false)

## Pose sementara (tidur) tetap bertahan saat state locomotion diperbarui.
func set_visual_override(action: StringName) -> void:
	if item_gesture_playing:
		sprite.speed_scale = 1.0
	item_gesture_playing = false
	_pose_hold = -1
	_visual_override = action
	_apply(false)

## Pose diam selama membidik: animasi `action` berhenti di `frame` sampai release_pose().
## Tidak menimpa pose lain (tidur, duduk, gesture item).
func hold_pose(action: StringName, frame: int) -> void:
	if _visual_override == action and _pose_hold == frame:
		return
	if not can_hold_pose():
		return
	if _pose_hold < 0:
		_aim_move_built.clear()
	_visual_override = action
	_pose_hold = frame
	_apply(false)

func can_hold_pose() -> bool:
	return not item_gesture_playing and (_visual_override.is_empty() or _pose_hold >= 0)

## Lepas pose bidik. true bila tadi sedang menahan pose.
func release_pose() -> bool:
	if _pose_hold < 0:
		return false
	_pose_hold = -1
	_visual_override = &""
	_apply(false)
	return true

## Cosmetic one-shot without emitting tool hit frames or changing the action state.
func play_item_gesture(action: StringName, speed: float = 1.0) -> bool:
	if not _visual_override.is_empty():
		return false
	var found := false
	for suffix in ["down", "up", "right", "left"]:
		found = found or sprite.sprite_frames.has_animation("%s_%s" % [action, suffix])
	if not found:
		return false
	item_gesture_playing = true
	_visual_override = action
	sprite.speed_scale = speed
	_apply(false)
	return true
	
func set_direction(direction: Vector2) -> void:	
	if direction.x != 0:
		_direction = "right"
	else:
		_direction = "up" if direction.y < 0 else "down"
	_facing_left = direction.x < 0
	_apply(true)

func _apply(keep_frame: bool) -> void:
	var action := String(_visual_override) if not _visual_override.is_empty() else _action
	if _visual_override.is_empty() and carrying_item and action in ["idle", "walk", "run"]:
		action = "carry_" + action
	elif _visual_override.is_empty() and riding_horse and action in ["idle", "walk", "run"] and not _resolve_animation("horse_" + action).is_empty():
		action = "horse_" + action
	var resolved := _resolve_animation(action)
	if resolved.is_empty():
		push_warning("Animasi '%s_%s' tidak ada di SpriteFrames." % [action, _direction])
		return
	var anim_name: StringName = resolved[0]
	sprite.flip_h = resolved[1]
	# Membidik sambil berjalan: badan + senjata dari pose bidik, kaki tetap melangkah.
	var freeze := _pose_hold >= 0
	if freeze and _action in AIM_MOVE_ACTIONS:
		var moving := _aim_move_animation(anim_name, resolved[1])
		if not moving.is_empty():
			anim_name = moving
			freeze = false
	
	if sprite.animation == anim_name and keep_frame:
		if freeze:
			_freeze_pose()
		elif not sprite.is_playing():
			sprite.play(anim_name)
		return

	var frame := sprite.frame
	var progress := sprite.frame_progress
	sprite.play(anim_name)
	if freeze:
		_freeze_pose()
	elif keep_frame:
		sprite.set_frame_and_progress(frame, progress)
	else:
		sprite.set_frame_and_progress(0, 0.0)

## [nama animasi, flip_h] untuk action ke arah hadap sekarang; kosong bila tidak ada.
func _resolve_animation(action: String) -> Array:
	var direction := "left" if _facing_left else _direction
	var anim_name := "%s_%s" % [action, direction]
	if sprite.sprite_frames.has_animation(anim_name):
		return [StringName(anim_name), false]
	anim_name = "%s_%s" % [action, _direction]
	if sprite.sprite_frames.has_animation(anim_name):
		return [StringName(anim_name), direction == "left"]
	if sprite.sprite_frames.has_animation(action):
		return [StringName(action), false]
	return []

## Animasi gabungan "bidik sambil jalan": tiap frame jalan/lari diberi badan dari frame pose bidik.
## Baris di bawah pinggang diambil dari frame jalan, kecuali piksel senjata (piksel pose yang
## berbeda dari frame diam). Dibuat sekali per sesi bidik lalu disimpan di SpriteFrames pemain.
## Kosong = tidak bisa digabung (pakai pose diam seperti biasa).
func _aim_move_animation(pose_anim: StringName, pose_flip: bool) -> StringName:
	var frames := sprite.sprite_frames
	var legs := _resolve_animation(_action)
	var stand := _resolve_animation("idle")
	if legs.is_empty() or stand.is_empty() or legs[1] != pose_flip or stand[1] != pose_flip:
		return &""
	var legs_anim: StringName = legs[0]
	var anim_name := StringName("%s%s__%s" % [AIM_MOVE_PREFIX, legs_anim, pose_anim])
	if _aim_move_built.has(anim_name) and frames.has_animation(anim_name):
		return anim_name
	var pose := _frame_image(frames, pose_anim, mini(_pose_hold, frames.get_frame_count(pose_anim) - 1))
	var still := _frame_image(frames, stand[0], 0)
	if pose == null or still == null or pose.get_size() != still.get_size():
		return &""
	if frames.has_animation(anim_name):
		frames.clear(anim_name)
	else:
		frames.add_animation(anim_name)
	frames.set_animation_speed(anim_name, frames.get_animation_speed(legs_anim))
	frames.set_animation_loop(anim_name, frames.get_animation_loop(legs_anim))
	var size := pose.get_size()
	var waist := roundi(size.y * AIM_WAIST_RATIO)
	for i in frames.get_frame_count(legs_anim):
		var step := _frame_image(frames, legs_anim, i)
		if step == null or step.get_size() != size:
			continue
		var out := pose.duplicate() as Image
		for y in range(waist, size.y):
			for x in size.x:
				var pixel := pose.get_pixel(x, y)
				if pixel.a > 0.0 and pixel != still.get_pixel(x, y):
					continue
				out.set_pixel(x, y, step.get_pixel(x, y))
		frames.add_frame(anim_name, ImageTexture.create_from_image(out), frames.get_frame_duration(legs_anim, i))
	if frames.get_frame_count(anim_name) == 0:
		frames.remove_animation(anim_name)
		return &""
	_aim_move_built[anim_name] = true
	return anim_name

func _frame_image(frames: SpriteFrames, anim: StringName, index: int) -> Image:
	if index < 0 or index >= frames.get_frame_count(anim):
		return null
	var texture := frames.get_frame_texture(anim, index)
	if texture == null:
		return null
	var image := texture.get_image()
	if image == null:
		return null
	if image.is_compressed():
		image.decompress()
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	return image

func _freeze_pose() -> void:
	sprite.pause()
	sprite.set_frame_and_progress(mini(_pose_hold, sprite.sprite_frames.get_frame_count(sprite.animation) - 1), 0.0)
