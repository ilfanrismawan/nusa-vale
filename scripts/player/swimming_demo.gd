extends Node2D
## Contoh mandiri: F6 pada swimming_demo.tscn. Tidak mengubah map utama.
## Ganti _is_water() dengan pemeriksaan tile air untuk integrasi ke world.

enum Mode { WALK, SWIM, DIVE, CLIMB }

const SHEETS := "res://assets/farm_rpg/Character/Pre-made/Josh/"
const POOL := Rect2(220, 130, 340, 230)
const WALK_SPEED := 100.0
const SWIM_SPEED := 60.0
const DIVE_SPEED := 45.0

var mode := Mode.WALK
var actor := CharacterBody2D.new()
var sprite := AnimatedSprite2D.new()
var status := Label.new()
var direction := "down"
var dive_held := false

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("24352f"))
	actor.position = Vector2(160, 245)
	add_child(actor)
	actor.add_child(sprite)
	sprite.position.y = -8
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.sprite_frames = SpriteFrames.new()
	sprite.sprite_frames.remove_animation("default")
	_add_sheet("idle", "Idle.png", 4, 6.0, true)
	_add_sheet("walk", "Walk.png", 6, 10.0, true)
	_add_sheet("swim", "Swim/Swim.png", 4, 7.0, true)
	_add_sheet("swim_idle", "Swim/Idle.png", 4, 6.0, true)
	_add_sheet("dive", "Swim/submerged.png", 4, 7.0, true)
	_add_sheet("climb", "Swim/Coming out of the water.png", 3, 9.0, false)
	sprite.animation_finished.connect(_finish_climb)
	var camera := Camera2D.new()
	camera.position = Vector2(390, 245)
	camera.zoom = Vector2(2, 2)
	add_child(camera)
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var help := Label.new()
	help.text = "DEMO BERENANG\nWASD: bergerak\nMasuk kolam: berenang otomatis\nTahan Spasi: menyelam; lepas: muncul\nKeluar kolam: animasi naik ke darat"
	help.position = Vector2(20, 16)
	canvas.add_child(help)
	status.position = Vector2(20, 150)
	canvas.add_child(status)
	_play("idle")
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	# Input lokal demo, tanpa menambah/mengubah InputMap proyek.
	if event is InputEventKey and event.physical_keycode == KEY_SPACE:
		dive_held = event.pressed
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		dive_held = false

func _physics_process(_delta: float) -> void:
	if mode == Mode.CLIMB:
		actor.velocity = Vector2.ZERO
		return
	# Hanya boleh menyelam saat sudah berada di air.
	if mode == Mode.SWIM and dive_held:
		mode = Mode.DIVE
	elif mode == Mode.DIVE and not dive_held:
		mode = Mode.SWIM
	var movement := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if movement != Vector2.ZERO:
		direction = "right" if movement.x != 0 else ("up" if movement.y < 0 else "down")
		sprite.flip_h = movement.x < 0
	var movement_speed := WALK_SPEED
	if mode == Mode.SWIM:
		movement_speed = SWIM_SPEED
	elif mode == Mode.DIVE:
		movement_speed = DIVE_SPEED
	actor.velocity = movement * movement_speed
	actor.move_and_slide()
	actor.position = actor.position.clamp(Vector2(100, 85), Vector2(680, 405))
	var in_water := _is_water(actor.position)
	if mode == Mode.WALK and in_water:
		mode = Mode.DIVE if dive_held else Mode.SWIM
	elif mode in [Mode.SWIM, Mode.DIVE] and not in_water:
		mode = Mode.CLIMB
		_play("climb")
		status.text = "Status: naik ke darat"
		return
	if mode == Mode.DIVE:
		_play("dive")
		status.text = "Status: menyelam (lepas Spasi untuk muncul)"
	elif mode == Mode.SWIM:
		_play("swim_idle" if movement == Vector2.ZERO else "swim")
		status.text = "Status: berenang"
	else:
		_play("idle" if movement == Vector2.ZERO else "walk")
		status.text = "Status: di darat"

func _is_water(feet: Vector2) -> bool:
	return POOL.has_point(feet)

func _finish_climb() -> void:
	if mode == Mode.CLIMB:
		mode = Mode.WALK
		_play("idle")

func _play(action: String) -> void:
	var animation := action + "_" + direction
	if sprite.animation != animation:
		sprite.play(animation)

func _add_sheet(action: String, file: String, columns: int, fps: float, loop: bool) -> void:
	var texture := load(SHEETS + file) as Texture2D
	for row in range(3):
		var animation: String = action + "_" + ["down", "up", "right"][row]
		sprite.sprite_frames.add_animation(animation)
		sprite.sprite_frames.set_animation_speed(animation, fps)
		sprite.sprite_frames.set_animation_loop(animation, loop)
		for column in range(columns):
			var frame := AtlasTexture.new()
			frame.atlas = texture
			frame.region = Rect2(column * 32, row * 32, 32, 32)
			sprite.sprite_frames.add_frame(animation, frame)

func _draw() -> void:
	draw_rect(Rect2(85, 70, 610, 350), Color("7aa35c"))
	draw_rect(POOL.grow(7), Color("d6c18a"))
	draw_rect(POOL, Color("438dad"))
	for y in range(150, 350, 24):
		for x in range(240, 550, 40):
			draw_line(Vector2(x, y), Vector2(x + 12, y), Color("78b9ca"), 1.0)
