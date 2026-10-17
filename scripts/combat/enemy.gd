class_name Enemy
extends CharacterBody2D

## Musuh dasar Phase 4B-1: diam di tempat (belum ada AI), bisa diserang, melukai pemain
## yang menyentuhnya, lalu mati dan menjatuhkan item. Data dari EnemyData (resources/enemies).
## AI gerak dan pola serangan menyusul di Phase 4B-2.

signal died(enemy: Enemy)

const HIT_INVULNERABLE := 0.2
const CONTACT_COOLDOWN := 0.8
const KNOCKBACK_DECAY := 10.0

var data: EnemyData
var hp := 1
var _sprite: AnimatedSprite2D
var _contact: Area2D
var _invulnerable := 0.0
var _knockback := Vector2.ZERO
var _dead := false
var _touching: Array[Player] = []
var _contact_timer := 0.0

static func spawn(p_data: EnemyData, parent: Node, world_pos: Vector2) -> Enemy:
	if p_data == null or parent == null:
		return null
	var enemy := Enemy.new()
	enemy.data = p_data
	enemy.name = "Enemy_%s" % p_data.id
	parent.add_child(enemy)
	enemy.global_position = world_pos
	return enemy

func _ready() -> void:
	add_to_group(Combat.DAMAGEABLE_GROUP)
	add_to_group(&"enemies")
	if data == null:
		push_warning("Enemy tanpa EnemyData")
		queue_free()
		return
	hp = data.max_hp
	collision_layer = 1
	collision_mask = 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var body_shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = data.body_radius
	body_shape.shape = circle
	add_child(body_shape)

	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = _build_frames()
	_sprite.offset = data.sprite_offset
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	_sprite.animation_finished.connect(_on_animation_finished)
	_play(&"idle")

	_contact = Area2D.new()
	_contact.monitorable = false
	_contact.collision_mask = 0xFFFFFFFF
	var contact_shape := CollisionShape2D.new()
	var contact_circle := CircleShape2D.new()
	contact_circle.radius = data.body_radius + 3.0
	contact_shape.shape = contact_circle
	_contact.add_child(contact_shape)
	add_child(_contact)
	_contact.body_entered.connect(func(body: Node2D):
		if body is Player and not _touching.has(body):
			_touching.append(body)
			_contact_timer = 0.0)
	_contact.body_exited.connect(func(body: Node2D):
		if body is Player:
			_touching.erase(body))

## Baris pertama tiap sheet (menghadap ke bawah). Jumlah frame dihitung dari lebar gambar.
func _build_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for entry in [[&"idle", "Idle.png", true], [&"damage", "Damage.png", false], [&"dead", "Dead.png", false]]:
		var anim: StringName = entry[0]
		frames.add_animation(anim)
		frames.set_animation_loop(anim, entry[2])
		frames.set_animation_speed(anim, data.animation_fps)
		var path: String = data.sprite_folder.path_join(entry[1])
		if not ResourceLoader.exists(path):
			continue
		var sheet := load(path) as Texture2D
		var columns := maxi(1, floori(float(sheet.get_width()) / data.frame_size.x))
		for column in columns:
			var atlas := AtlasTexture.new()
			atlas.atlas = sheet
			atlas.region = Rect2(Vector2(column * data.frame_size.x, 0), Vector2(data.frame_size))
			frames.add_frame(anim, atlas)
	return frames

func _play(anim: StringName) -> void:
	if _sprite.sprite_frames.get_frame_count(anim) > 0:
		_sprite.play(anim)

func _physics_process(delta: float) -> void:
	if _dead:
		return
	_invulnerable = maxf(0.0, _invulnerable - delta)
	velocity = _knockback
	_knockback = _knockback.lerp(Vector2.ZERO, minf(1.0, KNOCKBACK_DECAY * delta))
	if _knockback.length() > 0.5:
		move_and_slide()
	if data.contact_damage and not _touching.is_empty():
		_contact_timer -= delta
		if _contact_timer <= 0.0:
			_contact_timer = CONTACT_COOLDOWN
			for player: Player in _touching.duplicate():
				if is_instance_valid(player):
					var push: Vector2 = (player.global_position - global_position).normalized() * 14.0
					player.take_hit(data.attack, self, push)

## Dipanggil serangan pemain. Mengembalikan true bila pukulan masuk.
func take_hit(attack: int, _source: Node, knockback: Vector2 = Vector2.ZERO) -> bool:
	if _dead or _invulnerable > 0.0:
		return false
	_invulnerable = HIT_INVULNERABLE
	var damage := Combat.damage_after_defense(attack, data.defense)
	hp = maxi(0, hp - damage)
	var heavy := CombatJuice.heavy_hit
	CombatJuice.damage_number(str(damage) + ("!" if heavy else ""), global_position + Vector2(0, -14), CombatJuice.HEAVY_COLOR if heavy else CombatJuice.HIT_COLOR, heavy)
	if not data.hit_feedback.is_empty():
		Juice.play(data.hit_feedback, global_position)
	CombatJuice.impact(damage, heavy)
	_knockback = knockback * 6.0 * (1.0 - data.knockback_resist)
	_flash()
	CombatJuice.squash(_sprite, 0.4 if heavy else 0.28)
	if hp <= 0:
		_die()
	else:
		_play(&"damage")
	return true

func is_dead() -> bool:
	return _dead

func _flash() -> void:
	_sprite.modulate = Color(3, 3, 3)
	var tw := create_tween()
	tw.tween_property(_sprite, "modulate", Color.WHITE, 0.15)

func _on_animation_finished() -> void:
	if _dead:
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.3)
		tw.tween_callback(queue_free)
	elif _sprite.animation == &"damage":
		_play(&"idle")

func _die() -> void:
	_dead = true
	_touching.clear()
	remove_from_group(Combat.DAMAGEABLE_GROUP)
	collision_layer = 0
	_contact.set_deferred("monitoring", false)
	if not data.death_feedback.is_empty():
		Juice.play(data.death_feedback, global_position)
	CombatJuice.death_burst(global_position, _particle_color())
	CombatJuice.squash(_sprite, 0.5)
	_drop_loot()
	died.emit(self)
	if _sprite.sprite_frames.get_frame_count(&"dead") > 0:
		_sprite.play(&"dead")
	else:
		_on_animation_finished()

## Warna partikel ledakan mati: ikut warna partikel suara-kena musuh ini.
func _particle_color() -> Color:
	var fb := Juice.get_feedback(data.hit_feedback) if not data.hit_feedback.is_empty() else null
	return fb.particle_color if fb != null and fb.particle_count > 0 else Color(0.95, 0.95, 0.9)

func _drop_loot() -> void:
	if data.drop_item_id.is_empty() or randf() > data.drop_chance:
		return
	var amount := randi_range(data.drop_min, maxi(data.drop_min, data.drop_max))
	var parent := get_parent()
	var spot := global_position
	var item_id := data.drop_item_id
	# Satu pickup per butir (maks. 6) supaya jarahan berhamburan; sisanya di pickup terakhir.
	var pieces := clampi(amount, 1, 6)
	for i in pieces:
		var count := 1 if i < pieces - 1 else amount - (pieces - 1)
		(func(): ItemPickup.spawn(parent, spot, item_id, count)).call_deferred()
