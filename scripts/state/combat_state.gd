class_name CombatState
extends State

## Serangan dengan senjata yang dipegang di hotbar (pedang, busur, tongkat sihir).
## Dibuat ToolController saat _ready; dimulai lewat start() lalu change_state().
## Frame data (GDD 8.2-A5): startup sampai WeaponStyle.hit_frame_ratio, hitbox tebasan aktif
## sampai active_end_ratio, lalu recovery. Serangan tidak bisa dibatalkan, kecuali recovery
## akhir dengan roll (recovery_cancel_ratio).

## Jenis serangan (GDD 8.2-A3/A6): ringan (combo), berat (tahan klik), setelah lari, setelah roll,
## riposte ke musuh yang terhuyung, dan weapon art.
enum Kind { LIGHT, HEAVY, SPRINT, ROLL, RIPOSTE, ART }

var idle_state: State
var weapon: ItemData
var style: WeaponStyle
var aim := Vector2.DOWN
## Anak panah yang sudah diambil dari tas untuk tembakan ini (null untuk pedang/tongkat).
var arrow: ItemData
## Urutan pukulan dalam combo (0 = pertama). Diatur ToolController.
var combo_step := 0
## Klik kiri saat serangan berjalan: sambung pukulan berikutnya begitu animasi selesai.
var combo_queued := false
var kind := Kind.LIGHT
var art: WeaponArt
## Musuh terhuyung yang menjadi sasaran riposte.
var riposte_target: Node2D
## Efek visual/suara tier senjata (WeaponTierFx, dari ItemData.equipment_tier).
var fx: WeaponTierFx
var _performed := false
var _hit_frame := 0
var _active_end := 0
var _frames := 1
var _hit_targets := {}
var _attack := 1
var _lunge_left := 0.0

func start(p_weapon: ItemData, p_style: WeaponStyle, p_aim: Vector2, p_arrow: ItemData = null, p_combo_step: int = 0, p_kind: Kind = Kind.LIGHT, p_art: WeaponArt = null) -> void:
	weapon = p_weapon
	style = p_style
	aim = p_aim.normalized() if p_aim.length() > 0.01 else player.facing_direction
	arrow = p_arrow
	combo_step = p_combo_step
	combo_queued = false
	kind = p_kind
	art = p_art
	fx = WeaponTierFx.for_item(weapon)
	animation_name = style.animation_name

func is_finisher() -> bool:
	return kind == Kind.LIGHT and style != null and style.is_finisher(combo_step)

## Serangan berbobot: angka damage dan hitstop besar.
func is_heavy() -> bool:
	return is_finisher() or kind in [Kind.HEAVY, Kind.RIPOSTE, Kind.ART]

func enter() -> void:
	_performed = false
	_hit_targets.clear()
	player.velocity = Vector2.ZERO
	player.update_facing_direction(aim, true)
	var from_aim_pose := animation_controller.release_pose()
	super.enter()
	var sprite := animation_controller.sprite
	sprite.speed_scale = style.speed_scale * _speed_scale()
	_frames = sprite.sprite_frames.get_frame_count(sprite.animation) if sprite.sprite_frames != null else 1
	_hit_frame = clampi(int(_frames * style.hit_frame_ratio), 0, maxi(0, _frames - 1))
	_active_end = clampi(int(ceil(_frames * style.active_end_ratio)), _hit_frame, maxi(0, _frames - 1))
	_lunge_left = style.sprint_lunge if kind == Kind.SPRINT else 0.0
	if kind == Kind.RIPOSTE and is_instance_valid(riposte_target):
		_lunge_left = maxf(0.0, (riposte_target.global_position - (player.global_position + Player.FEET_OFFSET)).length() - style.melee_reach)
	# Tali busur sudah ditarik saat membidik: lanjutkan dari pose itu, langsung lepas.
	if from_aim_pose and style.aim_pose_frame >= 0 and kind in [Kind.LIGHT, Kind.HEAVY]:
		sprite.set_frame_and_progress(mini(style.aim_pose_frame, _hit_frame), 0.0)
	Juice.play(style.swing_feedback, player.global_position, -3.0 if is_heavy() else 0.0)
	if style.melee_radius > 0.0:
		# Desau ayunan makin berat seiring tier pedang.
		Juice.sfx(SfxSynth.whoosh(), -16.0 + fx.muzzle_scale * 3.0 + (2.0 if is_heavy() else 0.0), 0.08, -fx.muzzle_scale * 2.0)
	if kind == Kind.ART and art != null:
		CombatJuice.float_text(player, art.display_name, art.color)
	elif kind == Kind.HEAVY:
		CombatJuice.float_text(player, "Berat!", CombatJuice.HEAVY_COLOR)
	animation_controller.frame_changed.connect(_on_frame_changed)
	animation_controller.animated_finished.connect(_on_animation_finished)

func _speed_scale() -> float:
	match kind:
		Kind.HEAVY, Kind.RIPOSTE:
			return style.heavy_speed
		Kind.ROLL:
			return style.roll_speed
		Kind.LIGHT:
			return style.combo_speed_at(combo_step)
	return 1.0

func exit() -> void:
	animation_controller.sprite.speed_scale = 1.0
	if animation_controller.frame_changed.is_connected(_on_frame_changed):
		animation_controller.frame_changed.disconnect(_on_frame_changed)
	if animation_controller.animated_finished.is_connected(_on_animation_finished):
		animation_controller.animated_finished.disconnect(_on_animation_finished)
	# Serangan terputus (pemain tumbang, terhuyung, pindah area): panah yang sudah diambil kembali ke tas.
	if not _performed and arrow != null:
		player.data.add_item(arrow, 1)
	arrow = null
	riposte_target = null

func physics_update(delta: float) -> void:
	player.velocity = Vector2.ZERO
	# Sprint attack / riposte: tubuh maju selama startup.
	if _lunge_left > 0.0 and not _performed:
		var step := minf(_lunge_left, 180.0 * delta)
		_lunge_left -= step
		player.velocity = aim * step / maxf(delta, 0.0001)
		player.move_and_slide()
		player.velocity = Vector2.ZERO

## Recovery akhir boleh dibatalkan dengan roll.
func can_cancel() -> bool:
	if not _performed or _frames <= 0:
		return false
	var sprite := animation_controller.sprite
	return (sprite.frame + sprite.frame_progress) / float(_frames) >= style.recovery_cancel_ratio

func _on_frame_changed(frame: int) -> void:
	if frame >= _hit_frame and not _performed:
		_perform()
	elif _performed and frame <= _active_end and style.melee_radius > 0.0 and kind != Kind.ART:
		# Hitbox tetap aktif selama active frames: musuh yang baru masuk ikut kena (sekali).
		_melee(_attack)

func _on_animation_finished() -> void:
	_perform()
	var chain := combo_queued and kind == Kind.LIGHT
	transitioned.emit(idle_state)
	player.tool_controller.on_attack_finished(chain)

func _damage_scale() -> float:
	match kind:
		Kind.HEAVY:
			return style.heavy_damage
		Kind.SPRINT:
			return style.sprint_damage
		Kind.ROLL:
			return style.roll_damage
		Kind.RIPOSTE:
			return Combat.RULES.riposte_multiplier
		Kind.ART:
			return art.damage_scale if art != null else 1.0
	return style.combo_damage_at(combo_step)

func _poise_scale() -> float:
	match kind:
		Kind.HEAVY:
			return 2.5
		Kind.SPRINT, Kind.ROLL:
			return 1.5
		Kind.ART:
			return art.poise_scale if art != null else 1.5
	return 1.5 if is_finisher() else 1.0

func _perform() -> void:
	if _performed:
		return
	_performed = true
	player.bind_context()
	var base := weapon.attack_bonus + (arrow.attack_bonus if arrow != null else 0)
	_attack = maxi(1, roundi(base * _damage_scale()))
	if is_finisher() and not style.finisher_feedback.is_empty():
		Juice.play(style.finisher_feedback, player.global_position + Player.FEET_OFFSET + aim * style.melee_reach)
	if combo_step > 0 and kind == Kind.LIGHT:
		CombatJuice.combo_text(player, combo_step + 1, is_finisher())
	if is_finisher() or kind in [Kind.HEAVY, Kind.RIPOSTE]:
		CombatJuice.zoom_punch(player)
	if kind == Kind.ART and art != null:
		_perform_art()
	elif style.melee_radius > 0.0:
		_melee(_attack)
	else:
		_shoot(_attack)
	arrow = null

func _knockback() -> float:
	var push := style.knockback
	if is_finisher():
		push *= style.finisher_knockback_scale
	elif kind in [Kind.HEAVY, Kind.RIPOSTE]:
		push *= style.heavy_knockback_scale
	return push

## Tebasan jarak dekat: lingkaran di depan kaki pemain, searah bidikan.
## radius_override > 0 = tebasan art (target dihitung terpisah); reach_override 0 = berpusat di pemain.
func _melee(attack: int, radius_override: float = -1.0, reach_override: float = -1.0, color: Color = Color.WHITE) -> void:
	var space := player.get_world_2d().direct_space_state
	if space == null:
		return
	var reach := style.melee_reach if reach_override < 0.0 else reach_override
	var center := player.global_position + Player.FEET_OFFSET + aim * reach
	var shape := CircleShape2D.new()
	var radius := style.melee_radius
	if radius_override > 0.0:
		radius = radius_override
	elif is_finisher():
		radius *= style.finisher_radius_scale
	elif kind in [Kind.HEAVY, Kind.RIPOSTE]:
		radius *= style.heavy_radius_scale
	shape.radius = radius
	var hit := {} if radius_override > 0.0 else _hit_targets
	if radius_override > 0.0 or not _hit_targets.has(&"_slashed"):
		_hit_targets[&"_slashed"] = true
		CombatJuice.slash(player, aim, reach, shape.radius, is_heavy(), color, fx)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, center)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.exclude = [player.get_rid()]
	for result in space.intersect_shape(query, 32):
		var target := Combat.find_damageable(result.get("collider") as Node)
		if target == null or hit.has(target):
			continue
		hit[target] = true
		var dir := aim
		if reach <= 0.0 and target is Node2D:
			dir = ((target as Node2D).global_position - player.global_position).normalized()
		_strike(target, attack, dir * _knockback(), center)

## Satu pukulan ke satu target, membawa poise, kritis, dan penembus zirah lewat Combat.hit().
func _strike(target: Node, attack: int, knockback: Vector2, fallback_pos: Vector2) -> void:
	var critical := kind == Kind.RIPOSTE
	var landed := Combat.hit(target, attack, player, knockback, style.poise_damage * _poise_scale(), art != null and art.ignore_defense, critical, is_heavy(), fx)
	if not landed:
		return
	var at := (target as Node2D).global_position if target is Node2D else fallback_pos
	if not style.hit_feedback.is_empty():
		Juice.play(style.hit_feedback, at)
	CombatJuice.tier_impact(at, fx, knockback.normalized() if knockback.length() > 0.01 else aim, is_heavy())

func _shoot(attack: int) -> void:
	var count := style.finisher_projectiles if is_finisher() else 1
	var size := style.finisher_projectile_scale if is_finisher() else (style.heavy_projectile_scale if kind == Kind.HEAVY else 1.0)
	_launch(attack, count, deg_to_rad(style.finisher_spread_deg), size)

func _launch(attack: int, count: int, spread: float, size: float, pierce: bool = false, color: Variant = null) -> void:
	var texture := style.projectile_texture
	if arrow != null and arrow.icon != null:
		texture = arrow.icon
	# Bidikan penuh (klik kanan ditahan sampai berdenting) = tembakan "charged": lebih terang dan berat.
	var power := player.aim_fx.release() if is_instance_valid(player.aim_fx) else 0.0
	CombatJuice.muzzle(player, player.global_position + aim * 8.0, aim, fx, style.projectile_texture == null, power)
	for i in count:
		var dir := aim.rotated(spread * (i - (count - 1) * 0.5)) if count > 1 else aim
		var projectile := CombatProjectile.launch(player, player.global_position + dir * 8.0, dir, attack, style, texture, size, fx, power >= 1.0)
		if projectile == null:
			continue
		projectile.poise_damage = style.poise_damage * _poise_scale()
		projectile.pierce = pierce
		projectile.ignore_defense = art != null and art.ignore_defense
		if color is Color:
			projectile.modulate = color
		if is_heavy():
			projectile.knockback_scale = style.finisher_knockback_scale if is_finisher() else style.heavy_knockback_scale
			projectile.heavy = true

#region Weapon art

func _perform_art() -> void:
	if not art.feedback.is_empty():
		Juice.play(art.feedback, player.global_position)
	match art.kind:
		WeaponArt.Kind.MULTI_SLASH:
			_multi_slash(_attack)
		WeaponArt.Kind.SPIN, WeaponArt.Kind.BURST:
			_melee(_attack, art.radius, 0.0, art.color)
			CombatJuice.ring(player.global_position + Player.FEET_OFFSET, art.radius, art.color)
		WeaponArt.Kind.VOLLEY:
			_launch(_attack, art.count, deg_to_rad(art.spread_deg), 1.0, false, art.color)
		WeaponArt.Kind.PIERCE_SHOT:
			_launch(_attack, 1, 0.0, 1.4, true, art.color)
		WeaponArt.Kind.HEAL_CIRCLE:
			_heal_circle(_attack)

## Tebasan beruntun: tebasan pertama sekarang, sisanya menyusul tiap art.interval detik
## dengan arah sedikit berselang-seling.
func _multi_slash(attack: int) -> void:
	var reach := style.melee_reach
	var radius := (style.melee_radius if style.melee_radius > 0.0 else 14.0) * 1.1
	var used := art
	_melee(attack, radius, reach, used.color)
	var base_aim := aim
	for i in range(1, used.count):
		get_tree().create_timer(used.interval * i, false).timeout.connect(func():
			if not is_instance_valid(player) or player.is_defeated:
				return
			var saved_aim := aim
			var saved_art := art
			aim = base_aim.rotated(deg_to_rad(18.0 if i % 2 == 1 else -18.0))
			art = used
			_melee(attack, radius, reach, used.color)
			aim = saved_aim
			art = saved_art)

## Lingkaran penyembuh: pulihkan HP semua pemain di dalam lingkaran, lukai musuh di dalamnya.
func _heal_circle(attack: int) -> void:
	var center := player.global_position + Player.FEET_OFFSET
	CombatJuice.ring(center, art.radius, art.color)
	for node in player.get_tree().get_nodes_in_group(Combat.PLAYER_GROUP):
		var other := node as Player
		if other == null or other.is_defeated or other.get_world_2d() != player.get_world_2d():
			continue
		if (other.global_position + Player.FEET_OFFSET).distance_to(center) <= art.radius:
			other.data.restore_hp(art.heal_amount)
			CombatJuice.damage_number("+%d" % art.heal_amount, other.global_position + Vector2(0, -18), art.color)
	_melee(attack, art.radius, 0.0, art.color)

#endregion
