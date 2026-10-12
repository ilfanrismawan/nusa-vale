class_name ItemPickup
extends Area2D

## Jarak barang buangan dari kaki pemain (px).
const DROP_DISTANCE := 18.0

var item_id: String = ""
var amount: int = 1
var _can_collect: bool = false
var _icon: Texture2D
## Tekstur asli tanpa outline untuk ikon yang dibawa karakter.
var _raw_icon: Texture2D
## Body yang tidak bisa memungut sampai ia keluar dulu dari area pickup
## (pemain yang baru membuang barang ini dari tas).
var _ignore_body: Node2D


static func spawn(
	parent: Node,
	world_pos: Vector2,
	p_item_id: String,
	p_amount: int = 1,
	p_icon: Texture2D = null
) -> ItemPickup:
	if parent == null or p_item_id.is_empty() or p_amount <= 0:
		return null

	var pickup := ItemPickup.new()
	parent.add_child(pickup)

	pickup.global_position = world_pos
	# Di tanah pakai versi ikon ber-outline putih (lihat OutlineIcon).
	pickup.setup(
		p_item_id,
		p_amount,
		OutlineIcon.get_for(p_icon if p_icon != null else _icon_for(p_item_id))
	)
	pickup._raw_icon = p_icon if p_icon != null else _icon_for(p_item_id)

	return pickup


## Barang yang dibuang pemain dari tas: jatuh di depan kakinya dan baru bisa
## dipungut pemain itu lagi setelah ia melangkah keluar lalu masuk lagi.
static func drop_from(
	player: Player,
	p_item_id: String,
	p_amount: int,
	p_icon: Texture2D = null
) -> ItemPickup:
	if not is_instance_valid(player):
		return null
	var holder: Node = player.get_parent().get_parent() if player.get_parent() != null else null
	if holder == null:
		holder = player.world_root()
	var land: Vector2 = player.global_position + Player.FEET_OFFSET \
		+ player.facing_direction.normalized() * DROP_DISTANCE
	var pickup := spawn(holder, land, p_item_id, p_amount, p_icon)
	if pickup:
		pickup._ignore_body = player
		player.bind_context()
		Juice.play_sound(&"item_drop")
		player.play_item_gesture()
	return pickup


static func _icon_for(p_item_id: String) -> Texture2D:
	var item_path := "res://resources/item_data/%s.tres" % p_item_id

	if ResourceLoader.exists(item_path):
		var item: ItemData = load(item_path)

		if item and item.icon:
			return item.icon

	var icon_path := "res://resources/icons/icon_%s.tres" % p_item_id

	if ResourceLoader.exists(icon_path):
		return load(icon_path)

	var img := Image.create(
		12,
		12,
		false,
		Image.FORMAT_RGBA8
	)

	img.fill(Color(0.95, 0.82, 0.35))

	return ImageTexture.create_from_image(img)


func setup(
	p_item_id: String,
	p_amount: int,
	icon: Texture2D
) -> void:

	item_id = p_item_id
	amount = p_amount
	_icon = icon

	# Pickup belum bisa diambil selama animasi pop.
	_can_collect = false

	# Aman karena setup() dipanggil sebelum pickup mulai
	# digunakan oleh physics.
	monitoring = false

	collision_layer = 0
	collision_mask = 1
	z_index = 20


	# =========================
	# SPRITE
	# =========================

	var sprite := Sprite2D.new()

	sprite.texture = icon
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = true

	add_child(sprite)


	# =========================
	# AMOUNT LABEL
	# =========================

	if amount > 1:
		var label := Label.new()

		label.text = "x%d" % amount
		label.position = Vector2(4, 2)

		label.add_theme_font_size_override(
			"font_size",
			8
		)

		label.add_theme_color_override(
			"font_outline_color",
			Color.BLACK
		)

		label.add_theme_constant_override(
			"outline_size",
			4
		)

		add_child(label)


	# =========================
	# COLLISION
	# =========================

	var shape := CollisionShape2D.new()

	var circle := CircleShape2D.new()
	circle.radius = 10.0

	shape.shape = circle

	add_child(shape)


	# =========================
	# SIGNAL
	# =========================

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


	# =========================
	# POP ANIMATION
	# =========================

	_play_pop(sprite)


func _play_pop(sprite: Sprite2D) -> void:

	sprite.scale = Vector2(0.4, 0.4)

	var start := global_position

	var peak := start + Vector2(
		randf_range(-6.0, 6.0),
		-18.0
	)

	var land := start + Vector2(
		randf_range(-4.0, 4.0),
		randf_range(-2.0, 4.0)
	)

	var tw := create_tween()

	tw.set_parallel(true)

	tw.tween_property(
		self,
		"global_position",
		peak,
		0.18
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	tw.tween_property(
		sprite,
		"scale",
		Vector2.ONE,
		0.18
	)

	tw.set_parallel(false)

	tw.tween_property(
		self,
		"global_position",
		land,
		0.22
	).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

	tw.tween_callback(_enable_collect)


func _enable_collect() -> void:

	_can_collect = true

	# Jangan mengubah monitoring secara langsung
	# dari callback/tween yang berhubungan dengan physics.
	set_deferred("monitoring", true)

	# Barang buangan yang mendarat tidak menyentuh pemain: langsung boleh dipungut.
	# Kalau masih menyentuh, tunggu body_exited.
	if _ignore_body != null:
		await get_tree().physics_frame
		await get_tree().physics_frame
		if is_instance_valid(_ignore_body) and not overlaps_body(_ignore_body):
			_ignore_body = null


func _on_body_entered(body: Node2D) -> void:

	if not _can_collect:
		return

	if body == _ignore_body:
		return

	if not (
		body is Player
		or body.is_in_group("player")
	):
		return


	# Lock supaya tidak diproses dua kali.
	_can_collect = false

	# INI sumber error utama sebelumnya.
	# Jangan:
	# monitoring = false

	set_deferred("monitoring", false)


	# =========================
	# INVENTORY
	# =========================

	# Co-op: masuk ke tas pemain yang menyentuh item.
	if body is Player:
		(body as Player).bind_context()

	var leftover: int = int(GameState.add_item(
		item_id,
		amount
	))

	var got: int = amount - leftover


	# =========================
	# INVENTORY FULL
	# =========================

	if got <= 0:

		Notify.say("Tas penuh!")

		_can_collect = true

		set_deferred("monitoring", true)

		return


	# =========================
	# NOTIFICATION
	# =========================

	Notify.say(
		"+%d %s" % [
			got,
			_display_name()
		]
	)

	Juice.collect(item_id, _raw_icon if _raw_icon != null else _icon, global_position)
	if body is Player:
		(body as Player).play_item_gesture(true, _raw_icon if _raw_icon != null else _icon, item_id)


	# =========================
	# PARTIALLY COLLECTED
	# =========================

	if leftover > 0:

		amount = leftover

		_can_collect = true

		set_deferred("monitoring", true)

		return


	# =========================
	# FULLY COLLECTED
	# =========================

	queue_free()


func _on_body_exited(body: Node2D) -> void:
	if body == _ignore_body:
		_ignore_body = null


func _display_name() -> String:

	var path := (
		"res://resources/item_data/%s.tres"
		% item_id
	)

	if ResourceLoader.exists(path):

		var item: ItemData = load(path)

		if item:
			return item.display_name

	return item_id
