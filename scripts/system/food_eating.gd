class_name FoodEating
extends RefCounted
## Makan: klik kiri masakan di hotbar, klik kanan makanan apa pun yang dipegang, atau klik kanan
## slot makanan di tas. Aturan (stamina penuh, efek) tetap di CookingManager.eat; di sini efeknya:
## makanan diangkat ke mulut, digigit beberapa kali (remah, kunyah, tubuh mengangguk / animasi
## "eat"), lalu ditelan dengan kilau dan angka stamina/HP melayang. Angka di EatFeedback.

const FEEDBACK: EatFeedback = preload("res://resources/feedback/eat.tres")
const LOCK := &"eat"
const EFFECT_NODE := &"EatEffect"

static func is_eating(player: Player) -> bool:
	return is_instance_valid(player) and player.has_node(NodePath(EFFECT_NODE))

## Item di slot hotbar yang sedang dipegang bila bisa dimakan, selain itu null.
static func held_edible(player: Player) -> ItemData:
	if not is_instance_valid(player) or player.tool_controller == null:
		return null
	var item: ItemData = player.tool_controller.current_item
	return item if item != null and item.is_edible() else null

static func held_slot(player: Player) -> int:
	return player.data.hotbar_page * 8 + player.tool_controller.current_index

static func eat(player: Player, slot: int, fb: EatFeedback = FEEDBACK) -> Dictionary:
	if not is_instance_valid(player):
		return {"ok": false, "message": ""}
	if fb.block_while_eating and is_eating(player):
		return {"ok": false, "message": ""}
	var data := player.data
	var entry: Variant = data.inventory[slot] if slot >= 0 and slot < data.bag_size else null
	var item: ItemData = entry.item if entry is Dictionary and entry.get("item") is ItemData else null
	var stamina_before := data.stamina
	var hp_before := data.hp
	var result := CookingManager.eat(player, slot)
	if result.ok and item != null:
		play(player, item, data.stamina - stamina_before, data.hp - hp_before, fb)
	if not str(result.message).is_empty():
		Notify.say(result.message)
	return result

static func play(player: Player, item: ItemData, stamina_gain: int, hp_gain: int, fb: EatFeedback = FEEDBACK) -> void:
	if is_eating(player):
		player.get_node(NodePath(EFFECT_NODE)).free()
	var fx := Node2D.new()
	fx.name = EFFECT_NODE
	# Ikon makanan di depan tubuh pemain.
	fx.z_index = 1
	player.add_child(fx)
	if fb.lock_input:
		player.set_input_locked(LOCK, true)
		fx.tree_exiting.connect(func():
			if is_instance_valid(player):
				player.set_input_locked(LOCK, false))
	var anim := player.animation_controller
	if fb.face_camera:
		player.facing_direction = Vector2.DOWN
		anim.set_direction(Vector2.DOWN)
	var animated := anim.play_item_gesture(fb.animation_name, fb.animation_speed)
	var body := anim.sprite
	var body_scale := body.scale

	var icon := Sprite2D.new()
	icon.texture = item.icon
	icon.position = fb.mouth_offset + Vector2(0, 8)
	icon.scale = Vector2.ONE * fb.icon_scale * 0.5
	fx.add_child(icon)

	var crumbs: ActionFeedback = null
	if fb.crumbs != null:
		crumbs = fb.crumbs.duplicate()
		if fb.sample_icon_color:
			var tint := _icon_color(item.icon)
			if tint.a > 0.0:
				crumbs.particle_color = tint
				crumbs.particle_color_alt = tint.lightened(0.35)

	var tw := fx.create_tween()
	tw.tween_property(icon, "position", fb.mouth_offset, fb.lift_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(icon, "scale", Vector2.ONE * fb.icon_scale, fb.lift_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var size := fb.icon_scale
	for i in fb.bites:
		size *= fb.shrink_per_bite
		tw.tween_callback(_bite.bind(player, icon, crumbs, fb, i, not animated, body, body_scale))
		tw.tween_property(icon, "scale", Vector2(1.25, 0.7) * size, 0.05)
		tw.tween_property(icon, "scale", Vector2.ONE * size, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_interval(maxf(0.0, fb.bite_interval - 0.15))
	tw.tween_callback(_swallow.bind(player, icon, item, stamina_gain, hp_gain, fb))
	tw.tween_property(icon, "scale", Vector2.ZERO, 0.08)
	tw.tween_interval(0.12)
	tw.tween_callback(func():
		if is_instance_valid(body):
			body.scale = body_scale
		fx.queue_free())

static func _bite(player: Player, icon: Sprite2D, crumbs: ActionFeedback, fb: EatFeedback, index: int, nod: bool, body: AnimatedSprite2D, body_scale: Vector2) -> void:
	GameState.use_player(player)
	if fb.chew_sound != null:
		Juice.sfx(fb.chew_sound, fb.chew_volume_db, 0.06, fb.chew_pitch_step * index)
	if crumbs != null:
		Juice.burst(icon.global_position + Vector2(0, 2), crumbs)
	if nod and is_instance_valid(body):
		body.scale = body_scale * fb.bite_squash
		body.create_tween().tween_property(body, "scale", body_scale, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

static func _swallow(player: Player, icon: Sprite2D, item: ItemData, stamina_gain: int, hp_gain: int, fb: EatFeedback) -> void:
	GameState.use_player(player)
	if fb.gulp_sound != null:
		Juice.sfx(fb.gulp_sound, fb.gulp_volume_db, 0.04, 3.0)
	var mouth := icon.global_position
	if fb.finish != null:
		Juice.play_feedback(fb.finish, mouth)
	var lines: Array = []
	if stamina_gain > 0:
		lines.append(["+%d Stamina" % stamina_gain, fb.stamina_color])
	if hp_gain > 0:
		lines.append(["+%d HP" % hp_gain, fb.hp_color])
	for effect in item.food_effects:
		if effect != null and effect.is_valid_effect() and not effect.display_name.is_empty():
			lines.append([effect.display_name, fb.effect_color])
	var head := player.global_position + fb.mouth_offset + Vector2(0, -10)
	for i in lines.size():
		var show := func():
			GameState.use_player(player)
			Juice.float_text(lines[i][0], head + Vector2(0, -9 * i), lines[i][1], fb.text_hold)
		if i == 0 or fb.text_stagger <= 0.0:
			show.call()
		else:
			player.get_tree().create_timer(fb.text_stagger * i, false).timeout.connect(show)

## Warna rata-rata piksel buram ikon, untuk remah yang senada dengan makanannya.
static func _icon_color(texture: Texture2D) -> Color:
	if texture == null:
		return Color(0, 0, 0, 0)
	var image := texture.get_image()
	if image == null or image.is_empty():
		return Color(0, 0, 0, 0)
	if image.is_compressed():
		image.decompress()
	var total := Vector3.ZERO
	var count := 0
	var step := maxi(1, int(image.get_width() / 16.0))
	for y in range(0, image.get_height(), step):
		for x in range(0, image.get_width(), step):
			var c := image.get_pixel(x, y)
			if c.a > 0.5 and c.get_luminance() > 0.12:
				total += Vector3(c.r, c.g, c.b)
				count += 1
	if count == 0:
		return Color(0, 0, 0, 0)
	total /= count
	return Color(total.x, total.y, total.z)
