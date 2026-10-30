class_name Forageable
extends Area2D
## Barang liar di tanah. Seperti Stardew: hadap ke barang lalu tekan E (ditangani ForageSpawner),
## atau klik barangnya dengan Tangan (HarvestEffect tanpa alat).
## Dibuat oleh ForageSpawner; jangan ditaruh manual di scene.

const LAYER_BIT := 1 << 10
## Titik y-sort digeser ke atas supaya sejajar dengan titik y-sort pemain
## (badan pemain 8 px di atas kakinya). Tanpa ini barang tergambar di atas kaki pemain.
const SORT_SHIFT := Vector2(0, -4)
const GROUP := &"forageable"
const RADIUS := 8.0
const GroundShadow := preload("res://scripts/effects/ground_shadow.gd")
## Bayangan di bawah ikon barang (ikon 16 px berpusat di tengah sel).
const SHADOW_RADIUS := 5.0
const SHADOW_OFFSET := Vector2(0, 6)

var item: ItemData
var location_id: String = ""
var cell: Vector2i = Vector2i.ZERO
var _sprite: Sprite2D
var _taken: bool = false


func setup(p_item: ItemData, p_location_id: String, p_cell: Vector2i) -> void:
	item = p_item
	location_id = p_location_id
	cell = p_cell
	name = "Forage_%d_%d" % [cell.x, cell.y]

	collision_layer = LAYER_BIT
	collision_mask = 0
	monitoring = false
	monitorable = true
	add_to_group(GROUP)

	GroundShadow.attach(self, SHADOW_RADIUS, -SORT_SHIFT + SHADOW_OFFSET)

	_sprite = Sprite2D.new()
	_sprite.texture = OutlineIcon.get_for(item.icon)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.position = -SORT_SHIFT
	_sprite.offset = Vector2(0, -4)
	add_child(_sprite)

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = RADIUS
	shape.shape = circle
	shape.position = -SORT_SHIFT
	add_child(shape)


## Dipanggil ForageSpawner setelah node ditaruh di tengah sel.
func apply_sort_shift() -> void:
	position += SORT_SHIFT


## Muncul dengan "pop" kecil (dipakai untuk barang yang baru tumbuh hari ini).
func play_appear() -> void:
	if _sprite == null:
		return
	_sprite.scale = Vector2(0.2, 0.2)
	var tw := create_tween()
	tw.tween_property(_sprite, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Titik tengah sel barang ini (node-nya digeser SORT_SHIFT untuk y-sort).
func ground_position() -> Vector2:
	return global_position - SORT_SHIFT


func interact() -> void:
	if _taken or item == null:
		return

	# Kualitas Forage (GDD 5.2): Forager Lv5+ perak, Lv8+ emas
	var quality := ""
	var forager_lvl := SkillSystem.level_for_points(GameState.current.skills.points.get(&"forager", 0)) if GameState.current and GameState.current.skills != null else 0
	if forager_lvl >= 8:
		if randf() < 0.25: quality = "_gold"
		elif randf() < 0.50: quality = "_silver"
	elif forager_lvl >= 5:
		if randf() < 0.35: quality = "_silver"

	var target_item: ItemData = GameState._resolve_item(item.item_id + quality) if not quality.is_empty() else item
	if target_item == null:
		target_item = item

	var leftover: int = int(GameState.add_item(target_item, 1))
	if leftover > 0:
		Notify.say("Tas penuh!")
		return
	_taken = true
	set_deferred("monitorable", false)
	ForageManager.take_item(location_id, cell)
	# Role Forager (GDD 13): EXP + peluang memungut 2x.
	SkillSystem.gain(null, &"forager", SkillSystem.RULES.forage_exp)
	if SkillSystem.roll(null, &"forage_double") and int(GameState.add_item(target_item, 1)) == 0:
		Notify.say("+2 %s (pungutan ganda)" % target_item.display_name)
	else:
		Notify.say("+1 %s" % target_item.display_name)
	Juice.collect(target_item.item_id, target_item.icon, global_position)
	queue_free()
