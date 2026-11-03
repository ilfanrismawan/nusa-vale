extends StaticBody2D

## Penghuni Menara Penyihir (Hutan Dalam). Diam di balik meja, menghadap pemain saat diajak
## bicara, sesekali merapal sihir (animasi `mage_*` dari layer PNG/23. Mage).
## Sprite disusun saat runtime dari layer karakter (CharacterSpriteBuilder) memakai `appearance`,
## jadi topi penyihir (Acc/Wizard) dan baju ikut aset pack yang sama dengan pemain.
## Bicara pertama kali per hari = sapaan; berikutnya langsung membuka toko sihir.

const CATALOG: CharacterCatalog = preload("res://resources/character/character_catalog.tres")
const ANIMS: PackedStringArray = ["idle_down", "idle_up", "idle_side", "mage_down"]

@export var npc_name := "Nyai Kenanga"
@export var appearance: CharacterAppearance
@export var shop_data: ShopData
## Baris sapaan; satu per hari, bergiliran.
@export var lines: PackedStringArray = []
## Jeda acak (detik) antar rapalan sihir saat menganggur.
@export var cast_interval := Vector2(6.0, 12.0)

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var _greeted_day := -1
var _line_index := 0
var _cast_timer := 0.0
var _talk_timer := 0.0


func _ready() -> void:
	set_meta("player_interaction", true)
	_build_frames()
	_cast_timer = randf_range(cast_interval.x, cast_interval.y)
	sprite.animation_finished.connect(_on_animation_finished)


func _build_frames() -> void:
	if appearance == null:
		return
	var frames: SpriteFrames = CharacterSpriteBuilder.build(CATALOG, appearance, {}, ANIMS)["frames"]
	if frames.get_animation_names().is_empty():
		return
	sprite.sprite_frames = frames
	_play("idle_down")


func _process(delta: float) -> void:
	if _talk_timer > 0.0:
		_talk_timer -= delta
		return
	_cast_timer -= delta
	if _cast_timer <= 0.0:
		_cast_timer = randf_range(cast_interval.x, cast_interval.y)
		if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(&"mage_down"):
			sprite.flip_h = false
			_play("mage_down")


func _on_animation_finished() -> void:
	if sprite.animation == &"mage_down":
		_play("idle_down")


func interact(player: Player = null) -> void:
	_face(player)
	_talk_timer = 4.0
	if _greeted_day != DayCycle.current_day and not lines.is_empty():
		_greeted_day = DayCycle.current_day
		Notify.say("%s: %s" % [npc_name, lines[_line_index]])
		_line_index = (_line_index + 1) % lines.size()
		return
	_open_shop(player)


func _open_shop(player: Player) -> void:
	if shop_data == null or player == null:
		return
	var shop := ShopUI.new()
	shop.player = player
	shop.shop_data = shop_data
	Coop.ui_parent(player).add_child(shop)


func _face(player: Node2D) -> void:
	if player == null or sprite.sprite_frames == null:
		return
	var dir := player.global_position - global_position
	if absf(dir.x) > absf(dir.y):
		sprite.flip_h = dir.x < 0
		_play("idle_side")
	else:
		sprite.flip_h = false
		_play("idle_down" if dir.y > 0 else "idle_up")


func _play(anim: String) -> void:
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(anim):
		sprite.play(anim)
