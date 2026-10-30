extends Area2D
## Kuda yang berdiri di dunia, gaya Stardew/Harvest Moon: dekati lalu tekan interaksi untuk naik.
## Dibuat dan dihapus StructureManager._sync_horse_actors(); posisi tidak disimpan (pagi kembali ke Barn).
const GROUP := &"horse_actor"
## Kuda dari paket karakter (PNG/14. Horse - Idle, 14.1 Horse - Walk): sel 32x48, 4 arah (down, up, right, left).
const HORSE_FOLDERS := {
	"idle": "res://assets/farm_rpg/Character/PNG/14. Horse - Idle",
	"walk": "res://assets/farm_rpg/Character/PNG/14.1 Horse - Walk",
	"run": "res://assets/farm_rpg/Character/PNG/14.2 Horse - Run",
}
## Kecepatan sama dengan sheet horse_* di character_catalog.tres.
const FPS := {"idle": 6.0, "walk": 8.0, "run": 12.0}
const DIRECTIONS := ["down", "up", "right", "left"]
## Pelana semua kuda [usulan]; pilihan lain di aset: Black, Blue, Green, Pink.
const SADDLE := "Brown"
static var _frames: Dictionary = {}
var uid := 0
var animal_id := 0
var flip := false
var _sprite: AnimatedSprite2D
var _badge: Label
var _idle_timer := 0.0

func _ready() -> void:
	add_to_group(GROUP)
	set_meta("player_interaction", true)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	collision_layer = 1 << 9
	collision_mask = 0
	monitoring = false
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(22, 14)
	shape.shape = rect
	shape.position = Vector2(0, -6)
	add_child(shape)
	_sprite = AnimatedSprite2D.new()
	# Sama dengan posisi kuda saat ditunggangi (HorseMount.RIDE_LIFT) supaya naik/turun tidak melompat.
	_sprite.position.y = -10
	add_child(_sprite)
	preload("res://scripts/effects/ground_shadow.gd").attach(self, 11.0)
	_badge = Label.new()
	_badge.position = Vector2(-20, -48)
	_badge.add_theme_font_override("font", preload("res://assets/fonts/m5x7.ttf"))
	_badge.add_theme_font_size_override("font_size", 12)
	_badge.add_theme_color_override("font_color", Color("fff1c9"))
	_badge.add_theme_color_override("font_outline_color", Color("302333"))
	_badge.add_theme_constant_override("outline_size", 2)
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_badge)
	refresh()
	# Muncul dengan sedikit pantulan supaya terlihat "tiba".
	_sprite.scale = Vector2(1.15, 0.85)
	create_tween().tween_property(_sprite, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func animal() -> Dictionary:
	var record := StructureManager.record_for(uid)
	return {} if record.is_empty() else RanchHusbandry.animal_by_id(StructureManager.coop_state(record), animal_id)

func refresh() -> void:
	var horse := animal()
	if horse.is_empty():
		queue_free()
		return
	_sprite.sprite_frames = horse_frames(RanchHusbandry.horse_coat(horse))
	_sprite.play(anim_name("idle", Vector2.LEFT if flip else Vector2.RIGHT))
	_badge.text = str(horse.name) + (" ♥" if int(horse.pet_day) != DayCycle.current_day else "")

func _process(delta: float) -> void:
	# Sesekali mengibas: squash kecil supaya kuda terasa hidup saat menunggu.
	_idle_timer -= delta
	if _idle_timer <= 0.0:
		_idle_timer = randf_range(2.5, 5.0)
		var tween := create_tween()
		tween.tween_property(_sprite, "scale", Vector2(1.04, 0.96), 0.12)
		tween.tween_property(_sprite, "scale", Vector2.ONE, 0.18)

func interact(player: Node) -> void:
	if player is Player:
		var result := StructureManager.mount_horse(player, uid, animal_id)
		if not result.ok:
			Notify.say(result.message)
			var tween := create_tween()
			tween.tween_property(_sprite, "position:x", 2.0, 0.05)
			tween.tween_property(_sprite, "position:x", -2.0, 0.05)
			tween.tween_property(_sprite, "position:x", 0.0, 0.05)

## Animasi kuda (bayangan + badan warna `coat` + pelana): idle_/walk_/run_<arah>.
## Jumlah frame per arah sama dengan animasi penunggang horse_idle/horse_walk/horse_run,
## sehingga HorseMount bisa menyamakan frame kuda dengan frame pemain.
static func horse_frames(coat: String = "1") -> SpriteFrames:
	if _frames.has(coat):
		return _frames[coat]
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for action in HORSE_FOLDERS:
		var sheet: Image = null
		for relative in ["Horse/Shadow.png", "Horse/%s.png" % coat, "Horse/Saddle/%s.png" % SADDLE]:
			var texture := load(String(HORSE_FOLDERS[action]).path_join(relative)) as Texture2D
			if texture == null:
				continue
			var layer := texture.get_image()
			if layer.is_compressed():
				layer.decompress()
			layer.convert(Image.FORMAT_RGBA8)
			if sheet == null:
				sheet = Image.create_empty(layer.get_width(), layer.get_height(), false, Image.FORMAT_RGBA8)
			sheet.blend_rect(layer, Rect2i(Vector2i.ZERO, layer.get_size()), Vector2i.ZERO)
		if sheet == null:
			continue
		var atlas := ImageTexture.create_from_image(sheet)
		@warning_ignore("integer_division")
		var per_direction := sheet.get_width() / 32 / DIRECTIONS.size()
		for d in DIRECTIONS.size():
			var anim := StringName("%s_%s" % [action, DIRECTIONS[d]])
			frames.add_animation(anim)
			frames.set_animation_speed(anim, FPS[action])
			for col in per_direction:
				var frame := AtlasTexture.new()
				frame.atlas = atlas
				frame.region = Rect2((d * per_direction + col) * 32, 0, 32, sheet.get_height())
				frames.add_frame(anim, frame)
	_frames[coat] = frames
	return frames

static func anim_name(action: String, facing: Vector2) -> StringName:
	var direction := ("right" if facing.x > 0 else "left") if absf(facing.x) > absf(facing.y) else ("up" if facing.y < 0 else "down")
	return StringName("%s_%s" % [action, direction])
