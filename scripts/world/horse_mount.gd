extends Node2D
## Menunggang kuda: pemain memakai pose penunggang berlayer horse_idle/horse_walk/horse_run
## (PNG/14.x Horse, kulit, rambut, dan baju pemain), dan node ini menggambar kudanya
## (warna sesuai varian kuda) di bawah pemain dengan frame yang sama.
## State tunggangan ada di StructureManager.
## Juice: lompat naik ke pelana, debu tiap langkah derap, dan lompat turun.
## Turun otomatis saat pemain masuk interior, gua, atau ranch indoor; kuda ditinggal di area luar terakhir.
## Sprite pemain diangkat RIDE_LIFT supaya kaki kuda berpijak di titik kaki pemain.
const RIDE_LIFT := 10.0
## Bayangan pemain selebar kuda selama menunggang.
const RIDE_SHADOW_RADIUS := 11.0
const HOP_HEIGHT := 14.0
const HOP_TIME := 0.28
const HorseActor := preload("res://scripts/world/horse_actor.gd")
var _player: Player
var _body: Node2D
var _home_offset := Vector2.ZERO
var _dust_timer := 0.0
var _hopping_off := false
## Kuda di bawah penunggang; selama pemain melompat naik ia diam di tempat.
var _horse: AnimatedSprite2D
var _riding := false
## Area luar terakhir yang dilewati; tempat kuda ditinggal saat pemain turun di dalam ruangan.
var last_scene := ""
var last_position := Vector2.ZERO
var _dust := ActionFeedback.new()

func _ready() -> void:
	_player = get_parent() as Player
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_body = _player.animation_controller.sprite as Node2D
	_home_offset = _body.position
	_dust.particle_count = 5
	_dust.particle_lifetime = 0.35
	_dust.particle_spread = 70.0
	_dust.particle_speed = 18.0
	_dust.particle_gravity = 30.0
	_dust.particle_size = 2
	_dust.particle_color = Color("c8a77a")
	_dust.particle_color_alt = Color("8f6f4f")
	_remember_spot()
	_play_mount()

func _play_mount() -> void:
	# Kuda tetap terlihat di tempatnya selama pemain melompat busur ke pelana.
	var info: Dictionary = _player.get_meta("riding_horse", {})
	_horse = AnimatedSprite2D.new()
	_horse.sprite_frames = HorseActor.horse_frames(str(info.get("coat", "1")))
	# Sama dengan _sync_horse: kuda mengikuti sprite penunggang (termasuk offset kaki sprite).
	_horse.position = _home_offset + _body.offset + Vector2(0, 8 - RIDE_LIFT)
	_horse.play(HorseActor.anim_name("idle", _player.facing_direction))
	add_child(_horse)
	# Urutan anak menaruh kuda di bawah sprite pemain tanpa mengubah z_index terhadap tanah.
	_player.move_child.call_deferred(self, _body.get_index())
	_body.position = _home_offset + Vector2(-10, 0)
	var hop := _player.create_tween()
	hop.tween_method(func(t: float): _body.position = _home_offset + Vector2(lerpf(-10.0, 0.0, t), -RIDE_LIFT * t - sin(t * PI) * HOP_HEIGHT), 0.0, 1.0, HOP_TIME).set_trans(Tween.TRANS_SINE)
	hop.tween_callback(_land)

func _land() -> void:
	if not is_instance_valid(_player) or _hopping_off:
		return
	_riding = true
	_player.animation_controller.set_riding_horse(true)
	if is_instance_valid(_player.ground_shadow):
		_player.ground_shadow.radius = RIDE_SHADOW_RADIUS
	_body.position = _home_offset + Vector2(0, -RIDE_LIFT)
	# Kuda tertekan sedikit saat diduduki lalu memantul kembali.
	_body.scale = Vector2(1.15, 0.85)
	create_tween().tween_property(_body, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	var feet := _player.global_position + Player.FEET_OFFSET
	Juice.burst(feet, _dust)
	Juice.play_sound(&"pickup", 5.0)
	Juice.float_text("♥", _player.global_position + Player.SPRITE_OFFSET + Vector2(0, -34), Color("ff7073"))
	Juice.shake(1.5, 0.12)

## Dipanggil StructureManager.dismount sebelum node dihapus: lompat turun ke samping.
func play_dismount() -> void:
	if not is_instance_valid(_player):
		return
	_hopping_off = true
	_riding = false
	if is_instance_valid(_horse):
		_horse.hide()
	_reset_shadow()
	_player.animation_controller.set_riding_horse(false)
	_body.scale = Vector2.ONE
	var body := _body
	var home := _home_offset
	var tween := _player.create_tween()
	tween.tween_method(func(t: float): body.position = home + Vector2(0, -RIDE_LIFT * (1.0 - t) - sin(t * PI) * HOP_HEIGHT * 0.6), 0.0, 1.0, HOP_TIME * 0.8)
	Juice.burst(_player.global_position + Player.FEET_OFFSET, _dust)
	Juice.play_sound(&"swish", -2.0)

func _process(_delta: float) -> void:
	_sync_horse()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(_player):
		return
	if _indoors():
		StructureManager.dismount(_player)
		Notify.say("Kuda menunggu di luar.")
		return
	_remember_spot()
	# Derap: debu kecil di kaki kuda dan langkah berbunyi lebih rapat dari jalan kaki.
	if _player.velocity.length() > 1.0:
		_dust_timer -= delta
		if _dust_timer <= 0.0:
			_dust_timer = 0.22
			Juice.burst(_player.global_position + Player.FEET_OFFSET - _player.velocity.normalized() * 8.0, _dust)
			Juice.play_footstep("dirt", true, randi() % 4)
	else:
		_dust_timer = 0.0

## Kuda mengikuti sprite penunggang: animasi horse_walk_left -> walk_left, frame sama,
## posisi 8 px di bawah pusat badan (layer kuda 32x48 dan badan 32x32 sejajar di atas).
func _sync_horse() -> void:
	if not _riding or not is_instance_valid(_horse):
		return
	var sprite := _player.animation_controller.sprite
	var anim := String(sprite.animation)
	if anim.begins_with("horse_"):
		var horse_anim := StringName(anim.trim_prefix("horse_"))
		if _horse.sprite_frames.has_animation(horse_anim):
			if _horse.animation != horse_anim:
				_horse.play(horse_anim)
			_horse.pause()
			_horse.frame = mini(sprite.frame, _horse.sprite_frames.get_frame_count(horse_anim) - 1)
	_horse.flip_h = sprite.flip_h
	_horse.position = sprite.position + sprite.offset + Vector2(0, 8)
	_horse.scale = sprite.scale

## Posisi kaki kuda di area luar terakhir (dipakai StructureManager.horse_spot saat turun).
func _remember_spot() -> void:
	var world := _player.world_root()
	if world != null and not _indoors():
		last_scene = str(world.scene_file_path)
		last_position = _player.global_position + Player.FEET_OFFSET

func _indoors() -> bool:
	var world := _player.world_root()
	if world == null:
		return false
	var path := str(world.scene_file_path)
	return world.has_meta("ranch_uid") or path.contains("/interior/") or path.contains("/cave/")

func _exit_tree() -> void:
	if not is_instance_valid(_player):
		return
	_player.animation_controller.set_riding_horse(false)
	_reset_shadow()
	# Turun tanpa animasi (tidur, pingsan, cheat): kembalikan posisi sprite pemain.
	if not _hopping_off and is_instance_valid(_body):
		_body.position = _home_offset
		_body.scale = Vector2.ONE

func _reset_shadow() -> void:
	if is_instance_valid(_player.ground_shadow):
		_player.ground_shadow.radius = Player.GroundShadow.DEFAULT_RADIUS
