class_name CombatJuice
extends RefCounted

## Rasa pukulan combat: reaksi musuh, angka damage, jejak senjata, ledakan saat musuh mati,
## efek layar saat pemain terluka, dan penghitung combo. Hanya visual dan suara, tanpa
## mengubah angka combat. Efek umum (suara, partikel, getar, hitstop) tetap lewat Juice.

const HIT_COLOR := Color(1.0, 0.9, 0.4)
const HEAVY_COLOR := Color(1.0, 0.55, 0.2)
const HURT_COLOR := Color(1.0, 0.35, 0.35)
## HP pemain di bawah bagian ini membuat pukulan musuh terasa melambat sesaat.
const LOW_HP_RATIO := 0.25

## true selama pukulan finisher mengenai target (diset CombatState/CombatProjectile).
static var heavy_hit := false
## Efek tier senjata penyerang selama Combat.hit() berjalan (null = tanpa bonus tier).
static var hit_fx: WeaponTierFx

## Hitstop dan getar kamera sebanding damage; finisher lebih berat. Senjata tier tinggi
## menambah bonus hitstop/guncangan (WeaponTierFx).
static func impact(damage: int, heavy: bool) -> void:
	var bonus_ms := hit_fx.hitstop_bonus_ms if hit_fx != null else 0
	var bonus_shake := hit_fx.shake_bonus if hit_fx != null else 0.0
	Juice.hitstop(clampi(25 + damage * 3, 25, 70) + (40 if heavy else 0) + bonus_ms)
	Juice.shake(clampf(0.8 + damage * 0.08, 0.8, 2.5) + (1.5 if heavy else 0.0) + bonus_shake, 0.18 if heavy else 0.12)

## Musuh memipih lalu memantul kembali ke bentuk semula.
static func squash(node: Node2D, amount: float = 0.3) -> void:
	if node == null:
		return
	node.scale = Vector2(1.0 + amount, 1.0 - amount)
	var tw := node.create_tween()
	tw.tween_property(node, "scale", Vector2(1.0 - amount * 0.4, 1.0 + amount * 0.4), 0.06)
	tw.tween_property(node, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Angka damage yang meloncat, melayang miring, lalu memudar. Finisher lebih besar.
static func damage_number(text: String, world_pos: Vector2, color: Color, big: bool = false) -> void:
	var label := _label(text, color, 24 if big else 16, world_pos)
	if label == null:
		return
	var drift := Vector2(randf_range(-10.0, 10.0), -18.0 if big else -14.0)
	label.scale = Vector2(0.3, 0.3)
	var tw := label.create_tween()
	tw.tween_property(label, "scale", Vector2.ONE * (1.4 if big else 1.2), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "scale", Vector2.ONE, 0.08)
	tw.tween_property(label, "position", label.position + drift, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(label, "modulate:a", 0.0, 0.3).set_delay(0.2)
	tw.tween_callback(label.queue_free)

## "x2", "x3!" di atas kepala pemain saat combo menyambung.
static func combo_text(player: Player, hit: int, finisher: bool) -> void:
	var color := HEAVY_COLOR if finisher else Color(1.0, 1.0, 1.0).lerp(HIT_COLOR, 0.5)
	var label := _label("x%d%s" % [hit, "!" if finisher else ""], color, 20 if finisher else 16, player.global_position + Vector2(10, -28))
	if label == null:
		return
	label.scale = Vector2(1.8, 1.8)
	label.rotation = deg_to_rad(randf_range(-8.0, 8.0))
	var tw := label.create_tween()
	tw.tween_property(label, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.25)
	tw.tween_property(label, "modulate:a", 0.0, 0.2)
	tw.tween_callback(label.queue_free)

static func _label(text: String, color: Color, size: int, world_pos: Vector2) -> Label:
	var layer := Juice._screen_layer()
	if layer == null:
		return null
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", Juice.FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 5)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.add_child(label)
	label.reset_size()
	var screen := Juice._screen().get_canvas_transform() * world_pos
	label.position = (screen - Vector2(label.size.x * 0.5, label.size.y)).round()
	label.pivot_offset = label.size * 0.5
	return label

## Busur tebasan pedang di depan pemain, searah bidikan.
## tint selain putih = warna weapon art. fx = efek tier senjata (warna, tebal, gema, partikel).
static func slash(player: Player, aim: Vector2, reach: float, radius: float, heavy: bool, tint: Color = Color.WHITE, fx: WeaponTierFx = null) -> void:
	var parent := player.world_root()
	if parent == null:
		return
	var center := player.global_position + Player.FEET_OFFSET + aim * reach * 0.5
	var arc_radius := radius * (1.25 if heavy else 1.0) + 4.0
	var color := Color(1.0, 0.85, 0.5, 0.95) if heavy else Color(1.0, 1.0, 1.0, 0.85)
	if fx != null:
		color = Color(Color.WHITE.lerp(fx.color, 0.55), 0.92)
		if heavy:
			color = Color(color.lightened(0.25), 0.98)
	if tint != Color.WHITE:
		color = Color(tint, 0.95)
	var duration := 0.18 if heavy else 0.14
	var width := fx.slash_width_scale if fx != null else 1.0
	_spawn_arc(parent, center, aim, arc_radius, color, width, duration, 0.0)
	if fx != null and fx.slash_echo:
		# Gema: busur kedua lebih lebar dan pudar, sedikit terlambat, memberi kesan berat.
		_spawn_arc(parent, center, aim, arc_radius + 4.0, Color(fx.glow, fx.glow.a * 0.8), width * 0.7, duration * 1.3, 0.03)
	if fx != null and fx.slash_particles > 0:
		var count := fx.slash_particles * (2 if heavy else 1)
		for i in 3:
			var angle := aim.angle() + deg_to_rad(-60.0 + 60.0 * i)
			motif_burst(center + Vector2.from_angle(angle) * arc_radius, fx, maxi(1, roundi(count / 3.0)), Vector2.from_angle(angle))

static func _spawn_arc(parent: Node, center: Vector2, aim: Vector2, radius: float, color: Color, width: float, duration: float, delay: float) -> void:
	var arc := SlashArc.new()
	arc.radius = radius
	arc.color = color
	arc.width = width
	arc.z_index = 6
	parent.add_child(arc)
	arc.global_position = center
	arc.rotation = aim.angle()
	var tw := arc.create_tween()
	if delay > 0.0:
		arc.visible = false
		tw.tween_interval(delay)
		tw.tween_callback(arc.show)
	tw.tween_method(arc.set_progress, 0.0, 1.0, duration)
	tw.tween_callback(arc.queue_free)

## Ledakan partikel dan cincin saat musuh mati.
static func death_burst(world_pos: Vector2, color: Color) -> void:
	var fb := ActionFeedback.new()
	fb.particle_count = 18
	fb.particle_color = color
	fb.particle_color_alt = color.lightened(0.4)
	fb.particle_speed = 90.0
	fb.particle_gravity = 120.0
	fb.particle_spread = 180.0
	fb.particle_size = 3
	fb.particle_lifetime = 0.6
	Juice.burst(world_pos, fb)
	Juice.ripple(world_pos, color.lightened(0.3), 16.0)
	Juice.shake(1.5, 0.15)

## Percikan kecil saat proyektil pecah (bola sihir) atau menancap (panah).
static func spark(world_pos: Vector2, color: Color, count: int = 8) -> void:
	var fb := ActionFeedback.new()
	fb.particle_count = count
	fb.particle_color = color
	fb.particle_color_alt = Color.WHITE
	fb.particle_speed = 60.0
	fb.particle_gravity = 40.0
	fb.particle_spread = 180.0
	fb.particle_lifetime = 0.35
	Juice.burst(world_pos, fb)

## Percikan darah dari tubuh ke arah dorongan, lalu beberapa noda di tanah yang memudar.
static func blood(world_pos: Vector2, direction: Vector2, amount: int = 10) -> void:
	var parent := Juice._world_parent()
	if parent == null:
		return
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.amount = amount
	p.lifetime = 0.45
	p.explosiveness = 0.95
	p.local_coords = false
	p.direction = direction.normalized() if direction.length() > 0.1 else Vector2.UP
	p.spread = 55.0
	p.initial_velocity_min = 35.0
	p.initial_velocity_max = 85.0
	p.gravity = Vector2(0, 260)
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	var tint := Gradient.new()
	tint.set_color(0, Color(0.85, 0.08, 0.1))
	tint.set_color(1, Color(0.5, 0.02, 0.05))
	p.color_initial_ramp = tint
	p.z_index = 20
	parent.add_child(p)
	p.global_position = world_pos.round()
	p.emitting = true
	parent.get_tree().create_timer(0.8, false).timeout.connect(p.queue_free)
	var stains := BloodStain.new()
	stains.z_index = -1
	parent.add_child(stains)
	stains.global_position = (world_pos + Vector2(0, 14)).round()
	stains.scatter(direction, 3 + int(amount / 4.0))
	var tw := stains.create_tween()
	tw.tween_interval(1.2)
	tw.tween_property(stains, "modulate:a", 0.0, 0.8)
	tw.tween_callback(stains.queue_free)

## Tetes keringat kecil di atas kepala saat stamina hampir habis.
static func sweat(player: Player) -> void:
	var parent := player.world_root()
	if parent == null:
		return
	var drop := SweatDrop.new()
	drop.z_index = 21
	parent.add_child(drop)
	var side := -1.0 if randf() < 0.5 else 1.0
	drop.global_position = player.global_position + Vector2(6.0 * side, -22.0)
	var tw := drop.create_tween().set_parallel(true)
	tw.tween_property(drop, "position", drop.position + Vector2(3.0 * side, 8.0), 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(drop, "modulate:a", 0.0, 0.25).set_delay(0.35)
	tw.chain().tween_callback(drop.queue_free)

## Pemain terluka: pinggir layar berkedip merah; saat HP rendah waktu melambat sesaat.
static func player_hurt(player: Player) -> void:
	var low := player.data.hp > 0 and player.data.hp <= int(player.data.max_hp * LOW_HP_RATIO)
	Juice.shake(3.0 if low else 2.0, 0.2)
	var layer := Coop.juice_layer_of(player)
	if layer == null:
		layer = Juice._screen_layer()
	if layer != null:
		var vignette := HurtVignette.new()
		layer.add_child(vignette)
		var tw := vignette.create_tween()
		tw.tween_method(vignette.set_strength, 0.9 if low else 0.6, 0.0, 0.5 if low else 0.35)
		tw.tween_callback(vignette.queue_free)
	if low:
		_slow_motion(player, 0.35, 0.3)

## Seperti Juice.hitstop tapi lebih lama dan tidak berhenti total. Mati di co-op.
static func _slow_motion(player: Player, scale: float, seconds: float) -> void:
	if Coop.active or not Juice.hitstop_enabled or Juice._hitstop_active:
		return
	Juice._hitstop_active = true
	var previous := Engine.time_scale
	Engine.time_scale = scale
	await player.get_tree().create_timer(seconds, true, false, true).timeout
	Engine.time_scale = previous
	Juice._hitstop_active = false

## Finisher: kamera mendekat sedikit lalu kembali.
static func zoom_punch(player: Player, amount: float = 0.08) -> void:
	var cam := Coop.camera_of(player)
	if cam == null:
		cam = player.get_viewport().get_camera_2d()
	if cam == null or cam.has_meta(&"zoom_punch_base"):
		return
	var base := cam.zoom
	cam.set_meta(&"zoom_punch_base", base)
	var tw := cam.create_tween()
	tw.tween_property(cam, "zoom", base * (1.0 + amount), 0.06).set_ease(Tween.EASE_OUT)
	tw.tween_property(cam, "zoom", base, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func():
		cam.zoom = base
		cam.remove_meta(&"zoom_punch_base"))

# ── Soulslike (GDD 8.2-A) ──────────────────────────────────────────

## Teks pendek yang melayang di atas kepala pemain (Lelah!, Hindar, nama weapon art).
static func float_text(player: Player, text: String, color: Color) -> void:
	var label := _label(text, color, 14, player.global_position + Vector2(0, -34))
	if label == null:
		return
	var tw := label.create_tween()
	tw.tween_property(label, "position:y", label.position.y - 10.0, 0.5).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(label, "modulate:a", 0.0, 0.25).set_delay(0.35)
	tw.tween_callback(label.queue_free)

## Parry sukses: kilatan bintang putih, dentang nyaring, hitstop, dan teks PARRY!
static func parry_flash(player: Player, world_pos: Vector2) -> void:
	var parent := player.world_root()
	if parent != null:
		var star := ParryStar.new()
		star.z_index = 22
		parent.add_child(star)
		star.global_position = world_pos
		var tw := star.create_tween()
		tw.tween_method(star.set_progress, 0.0, 1.0, 0.25)
		tw.tween_callback(star.queue_free)
	Juice.play(&"mine", world_pos, 9.0)
	Juice.ripple(world_pos, Color(1.0, 1.0, 0.85), 18.0)
	spark(world_pos, Color(1.0, 0.95, 0.6), 14)
	Juice.hitstop(110)
	Juice.shake(3.0, 0.18)
	var label := _label("PARRY!", Color(1.0, 0.95, 0.55), 22, player.global_position + Vector2(0, -36))
	if label != null:
		var lt := label.create_tween()
		label.scale = Vector2.ONE * 1.6
		lt.tween_property(label, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		lt.tween_interval(0.35)
		lt.tween_property(label, "modulate:a", 0.0, 0.25)
		lt.tween_callback(label.queue_free)

## Teks di atas musuh (Goyah!, KRITIS!).
static func enemy_text(world_pos: Vector2, text: String, color: Color, big: bool = false) -> void:
	var label := _label(text, color, 20 if big else 14, world_pos)
	if label == null:
		return
	var tw := label.create_tween()
	tw.tween_property(label, "position:y", label.position.y - 12.0, 0.6).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(label, "modulate:a", 0.0, 0.3).set_delay(0.45)
	tw.tween_callback(label.queue_free)

## Bayangan jejak saat roll: salinan frame karakter yang memudar di tempat.
static func ghost(player: Player) -> void:
	var parent := player.world_root()
	var sprite := player.animation_controller.sprite
	if parent == null or sprite.sprite_frames == null:
		return
	var texture := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	if texture == null:
		return
	var copy := Sprite2D.new()
	copy.texture = texture
	copy.flip_h = sprite.flip_h
	copy.offset = sprite.offset
	copy.centered = sprite.centered
	copy.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	copy.modulate = Color(0.7, 0.85, 1.0, 0.45)
	copy.z_index = player.z_index - 1
	parent.add_child(copy)
	copy.global_transform = sprite.global_transform
	var tw := copy.create_tween()
	tw.tween_property(copy, "modulate:a", 0.0, 0.22)
	tw.tween_callback(copy.queue_free)

## Debu kecil dari kaki (awal roll, Fat-Roll mendarat).
static func dust(world_pos: Vector2, direction: Vector2) -> void:
	var fb := ActionFeedback.new()
	fb.particle_count = 6
	fb.particle_color = Color(0.8, 0.75, 0.65)
	fb.particle_color_alt = Color(0.65, 0.6, 0.5)
	fb.particle_speed = 30.0
	fb.particle_gravity = -10.0
	fb.particle_spread = 50.0
	fb.particle_lifetime = 0.35
	Juice.burst(world_pos - direction * 4.0, fb)

## Cincin area weapon art (tebasan berputar, ledakan sihir, lingkaran penyembuh).
static func ring(world_pos: Vector2, radius: float, color: Color) -> void:
	Juice.ripple(world_pos, color, radius)
	spark(world_pos, color, 12)

# ── Efek tier senjata ─────────────────────────────────────────────

## Partikel khas tier (percikan, kilau, bara, serpih es, asap, debu peri, api gelap).
## direction kosong = ke segala arah.
static func motif_burst(world_pos: Vector2, fx: WeaponTierFx, count: int, direction: Vector2 = Vector2.ZERO) -> void:
	if fx == null or count <= 0:
		return
	var fb := ActionFeedback.new()
	fb.particle_count = mini(count, 64)
	fb.particle_color = fx.color
	fb.particle_color_alt = fx.color_alt
	fb.particle_speed = fx.particle_speed()
	fb.particle_gravity = fx.particle_gravity()
	fb.particle_lifetime = fx.particle_lifetime()
	fb.particle_size = fx.particle_size()
	fb.particle_spread = 180.0 if direction == Vector2.ZERO else 70.0
	Juice.burst(world_pos, fb)
	if fx.motif in [WeaponTierFx.Motif.GLITTER, WeaponTierFx.Motif.FAIRY, WeaponTierFx.Motif.FROST]:
		twinkle(world_pos, fx, clampi(roundi(count / 6.0), 1, 4))

## Bintang kecil yang muncul lalu mengecil (kilau emas/platinum, serpih es, debu peri).
static func twinkle(world_pos: Vector2, fx: WeaponTierFx, count: int) -> void:
	var parent := Juice._world_parent()
	if parent == null:
		return
	for i in count:
		var star := TierStar.new()
		star.color = fx.color_alt if i % 2 == 0 else fx.color
		star.size = randf_range(2.5, 4.5)
		star.z_index = 21
		parent.add_child(star)
		star.global_position = (world_pos + Vector2(randf_range(-10.0, 10.0), randf_range(-12.0, 4.0))).round()
		var tw := star.create_tween()
		tw.tween_interval(randf_range(0.0, 0.12))
		tw.tween_method(star.set_progress, 0.0, 1.0, randf_range(0.3, 0.45))
		tw.tween_callback(star.queue_free)

## Lapisan suara benturan tier (kenney_impact), makin banyak lapisan makin tinggi tiernya.
static func play_tier_impact_sound(fx: WeaponTierFx, heavy: bool) -> void:
	if fx == null:
		return
	var semis := fx.impact_semitones - (2.0 if heavy else 0.0)
	for i in fx.impact_layers.size():
		Juice.sfx(Juice.impact_stream(fx.impact_layers[i]), fx.impact_volume_db - i * 2.0 + (2.0 if heavy else 0.0), 0.06, semis)
	if fx.motif in [WeaponTierFx.Motif.GLITTER, WeaponTierFx.Motif.FAIRY, WeaponTierFx.Motif.FROST]:
		Juice.sfx(SfxSynth.chime(), -19.0, 0.04, float(fx.chime_notes[fx.chime_notes.size() - 1]) if not fx.chime_notes.is_empty() else 0.0)
	if fx.bass_boom:
		Juice.sfx(SfxSynth.boom(), -6.0 if heavy else -11.0, 0.05)

## Benturan senjata ber-tier di target: partikel motif, cincin kejut, dan suara berlapis.
static func tier_impact(world_pos: Vector2, fx: WeaponTierFx, direction: Vector2, heavy: bool) -> void:
	if fx == null:
		return
	motif_burst(world_pos, fx, roundi(fx.hit_particles * (1.5 if heavy else 1.0)), direction)
	if fx.hit_ring > 0.0:
		Juice.ripple(world_pos, fx.color, fx.hit_ring * (1.35 if heavy else 1.0))
	if fx.halo_radius > 0.0:
		flash(world_pos, fx.glow, 3.0 + fx.halo_radius * (1.5 if heavy else 1.0))
	play_tier_impact_sound(fx, heavy)

## Kilatan lingkaran singkat (moncong busur/tongkat, benturan tier tinggi).
static func flash(world_pos: Vector2, color: Color, radius: float) -> void:
	var parent := Juice._world_parent()
	if parent == null or radius <= 0.0:
		return
	var glow := GlowFlash.new()
	glow.color = color
	glow.radius = radius
	glow.z_index = 21
	parent.add_child(glow)
	glow.global_position = world_pos.round()
	var tw := glow.create_tween()
	tw.tween_method(glow.set_progress, 0.0, 1.0, 0.16)
	tw.tween_callback(glow.queue_free)

## Tembakan busur/tongkat dilepas: kilatan moncong, desau, sentakan mundur, dan partikel tier.
## power 0..1 = seberapa penuh bidikan saat dilepas (AimFx.release).
static func muzzle(player: Player, world_pos: Vector2, direction: Vector2, fx: WeaponTierFx, magic: bool, power: float) -> void:
	if fx == null:
		return
	var size := fx.muzzle_scale * (1.0 + 0.6 * power)
	var color := fx.glow if fx.glow.a > 0.0 else Color(fx.color, 0.5)
	flash(world_pos, Color(color, clampf(color.a + 0.3, 0.0, 1.0)), 4.0 * size)
	motif_burst(world_pos + direction * 3.0, fx, roundi((fx.hit_particles / 3.0) * (1.0 + power)), direction)
	Juice.sfx(SfxSynth.whoosh(), -12.0 + 4.0 * power + fx.muzzle_scale * 2.0, 0.08, (4.0 if magic else 0.0) - fx.muzzle_scale * 2.0)
	if not fx.impact_layers.is_empty():
		Juice.sfx(Juice.impact_stream(fx.impact_layers[0]), fx.impact_volume_db - 8.0 + 3.0 * power, 0.05, fx.impact_semitones + 5.0)
	if fx.bass_boom and power >= 1.0:
		Juice.sfx(SfxSynth.boom(), -12.0, 0.05, 3.0)
	if power >= 1.0:
		Juice.shake(0.8 + fx.shake_bonus * 0.6, 0.1)
		zoom_punch(player, 0.02 + 0.015 * fx.muzzle_scale)
	recoil(player, direction, 1.5 + 1.5 * power)

## Badan pemain tersentak sedikit ke belakang saat menembak.
static func recoil(player: Player, direction: Vector2, pixels: float) -> void:
	var sprite := player.animation_controller.sprite if player.animation_controller != null else null
	if sprite == null or sprite.has_meta(&"recoil_base"):
		return
	var base := sprite.position
	sprite.set_meta(&"recoil_base", base)
	var tw := sprite.create_tween()
	tw.tween_property(sprite, "position", base - (direction * pixels).round(), 0.04)
	tw.tween_property(sprite, "position", base, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		sprite.position = base
		sprite.remove_meta(&"recoil_base"))

class TierStar extends Node2D:
	var color := Color.WHITE
	var size := 3.0
	var progress := 0.0

	func set_progress(value: float) -> void:
		progress = value
		queue_redraw()

	func _draw() -> void:
		# Muncul cepat lalu mengecil: bintang empat sudut.
		var grow := sin(PI * clampf(progress, 0.0, 1.0))
		var r := size * grow
		if r < 0.5:
			return
		var c := Color(color, 1.0 - progress * 0.5)
		draw_line(Vector2(-r, 0), Vector2(r, 0), c, 1.0)
		draw_line(Vector2(0, -r), Vector2(0, r), c, 1.0)
		draw_rect(Rect2(-0.5, -0.5, 1.0, 1.0), Color.WHITE)

class GlowFlash extends Node2D:
	var color := Color.WHITE
	var radius := 6.0
	var progress := 0.0

	func set_progress(value: float) -> void:
		progress = value
		queue_redraw()

	func _draw() -> void:
		var fade := 1.0 - progress
		draw_circle(Vector2.ZERO, radius * (0.6 + 0.6 * progress), Color(color, color.a * fade * 0.6))
		draw_circle(Vector2.ZERO, radius * 0.45 * fade, Color(1, 1, 1, fade * 0.9))

class ParryStar extends Node2D:
	var progress := 0.0

	func set_progress(value: float) -> void:
		progress = value
		queue_redraw()

	func _draw() -> void:
		var length := 6.0 + 14.0 * progress
		var c := Color(1.0, 1.0, 0.9, 1.0 - progress)
		for i in 8:
			var dir := Vector2.from_angle(TAU * i / 8.0 + 0.2)
			draw_line(dir * length * 0.3, dir * length * (1.0 if i % 2 == 0 else 0.6), c, 1.5)
		draw_circle(Vector2.ZERO, 3.0 * (1.0 - progress) + 1.0, c)

class SlashArc extends Node2D:
	const SPAN := deg_to_rad(150.0)
	const STEPS := 12
	var radius := 14.0
	var color := Color.WHITE
	## Ketebalan dikali angka ini (WeaponTierFx.slash_width_scale).
	var width := 1.0
	var progress := 0.0

	func set_progress(value: float) -> void:
		progress = value
		queue_redraw()

	func _draw() -> void:
		var start := -SPAN * 0.5
		var sweep := SPAN * clampf(progress * 1.6, 0.0, 1.0)
		if sweep < 0.2:
			return
		var points := PackedVector2Array()
		for i in STEPS + 1:
			points.append(Vector2.from_angle(start + sweep * i / STEPS) * radius)
		for i in range(STEPS, -1, -1):
			var thickness := (1.0 + 5.0 * sin(PI * i / STEPS)) * width
			points.append(Vector2.from_angle(start + sweep * i / STEPS) * (radius - thickness))
		var c := color
		c.a *= 1.0 - clampf((progress - 0.5) * 2.0, 0.0, 1.0)
		draw_colored_polygon(points, c)

class HurtVignette extends ColorRect:
	const SHADER := """
shader_type canvas_item;
uniform vec4 tint : source_color = vec4(0.85, 0.08, 0.08, 1.0);
uniform float strength = 0.0;
void fragment() {
	float edge = smoothstep(0.35, 0.75, length(UV - vec2(0.5)) * 1.3);
	COLOR = vec4(tint.rgb, edge * strength);
}
"""
	static var _shader: Shader

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)
		if _shader == null:
			_shader = Shader.new()
			_shader.code = SHADER
		var mat := ShaderMaterial.new()
		mat.shader = _shader
		material = mat

	func set_strength(value: float) -> void:
		(material as ShaderMaterial).set_shader_parameter(&"strength", value)

class BloodStain extends Node2D:
	var _spots: Array[Vector3] = []

	func scatter(direction: Vector2, count: int) -> void:
		var dir := direction.normalized() if direction.length() > 0.1 else Vector2.ZERO
		for i in count:
			var offset := dir * randf_range(2.0, 12.0) + Vector2(randf_range(-6.0, 6.0), randf_range(-3.0, 3.0))
			_spots.append(Vector3(round(offset.x), round(offset.y), randf_range(0.8, 2.0)))
		queue_redraw()

	func _draw() -> void:
		for spot in _spots:
			draw_circle(Vector2(spot.x, spot.y), spot.z, Color(0.55, 0.03, 0.06, 0.85))

class SweatDrop extends Node2D:
	func _draw() -> void:
		draw_colored_polygon(PackedVector2Array([Vector2(0, -3), Vector2(1.5, 0), Vector2(0, 1.5), Vector2(-1.5, 0)]), Color(0.55, 0.8, 1.0))
		draw_circle(Vector2(0, 0.3), 1.4, Color(0.55, 0.8, 1.0))
		draw_rect(Rect2(-0.5, -1, 1, 1), Color.WHITE)
