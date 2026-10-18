class_name Boss
extends Enemy

## Boss Guardian gua (GDD 8.2-C). Memakai badan Enemy (HP, DEF, poise, stagger, parry, efek
## status), tetapi otaknya pola jurus boss, bukan Behavior Tree:
## - Hantaman: melompat ke posisi pemain; retakan tanah + ikon bahaya muncul dulu. Tak bisa
##   ditahan atau di-parry, hanya roll/menjauh. Fase 2-3 menghantam beruntun.
## - Terjangan: kilat merah + panah tanda arah, lalu menerjang. Bisa di-parry.
## - Semburan: gumpalan emas menyebar. Bisa ditahan.
## - Pecah (fase 2+): memanggil anak slime. Hujan Emas (fase 3): retakan beruntun di sekitar pemain.
## - Anti-kiting: pemain menjaga jarak terlalu lama = lompatan penghancur jarak / semburan cepat.
## - Murka: tidak di-stagger selama BossData.enrage_time = lebih cepat dan lebih sakit sebentar.
## Angka semua jurus ada di BossData (resources/enemies/boss_*.tres). Dibangun BossArena.

signal woke
signal phase_changed(phase: int)
signal enrage_changed(active: bool)

enum Move { NONE, SLAM, CHARGE, SPIT, SPLIT, RAIN, ROAR }

const GOLD := Color(1.0, 0.82, 0.25)
const DANGER := Color(1.0, 0.25, 0.15)
## Warna aura per fase (fase 1 tanpa aura) dan saat murka.
const PHASE_AURA: Array[Color] = [Color(1.0, 0.85, 0.3, 0.0), Color(1.0, 0.6, 0.15, 0.35), Color(0.85, 0.1, 0.1, 0.45)]
const ENRAGE_AURA := Color(1.0, 0.15, 0.05, 0.55)
## Tinggi lompatan hantaman (piksel).
const SLAM_HEIGHT := 44.0
## Jarak terdekat boss berhenti mendekat (piksel).
const PERSONAL_SPACE := 22.0

var boss: BossData
var phase := 1
var awake := false
var enraged := false
var move := Move.NONE
## Batas gerak di dunia (dari BossArena). Kosong = tanpa batas.
var arena_rect := Rect2()
var minions: Array[Enemy] = []
var _step := 0
var _move_time := 0.0
var _rest := 0.0
var _since_stagger := 0.0
var _enrage_left := 0.0
var _far_time := 0.0
var _combo_left := 0
var _split_ready := 0.0
var _rain_ready := 0.0
var _rain_left := 0
var _rain_timer := 0.0
var _slam_from := Vector2.ZERO
var _slam_to := Vector2.ZERO
var _slam_hazard: Hazard
var _slam_windup := 0.0
var _hazards: Array[Node2D] = []
## Ikon bahaya di atas boss selama ancang-ancang jurus yang tak bisa ditahan.
var _unblockable_windup := false
## Jurus sekarang adalah respons anti-kiting.
var kite_response := false
var _charge_hit := false
var _time := 0.0
var _last_move := Move.NONE
var _embers: CPUParticles2D

static func spawn_boss(p_data: BossData, parent: Node, world_pos: Vector2) -> Boss:
	if p_data == null or parent == null:
		return null
	var created := Boss.new()
	created.data = p_data
	created.name = "Boss_%s" % p_data.id
	created.home = world_pos
	parent.add_child(created)
	created.global_position = world_pos
	return created

func _ready() -> void:
	super._ready()
	boss = data as BossData
	if boss == null:
		push_warning("Boss tanpa BossData")
		queue_free()
		return
	add_to_group(&"bosses")
	_sprite.scale = Vector2.ONE * boss.sprite_scale
	_face(Vector2.DOWN)
	_play("idle")

## Pemain masuk arena: boss bangun dengan raungan pembuka.
func wake(player: Player = null) -> void:
	if awake or _dead:
		return
	awake = true
	target = player if _target_valid(player) else _nearest_player()
	_set_alert(Alert.AGGRO)
	_since_stagger = 0.0
	_far_time = 0.0
	_split_ready = boss.split_cooldown * 0.5
	_rain_ready = 0.0
	_begin(Move.ROAR)
	woke.emit()

## Semua pemain keluar/tumbang: boss pulih penuh dan tidur lagi di tengah arena.
func reset_fight() -> void:
	_cancel_move()
	_clear_hazards()
	for minion in minions:
		if is_instance_valid(minion):
			minion.queue_free()
	minions.clear()
	awake = false
	enraged = false
	phase = 1
	hp = data.max_hp
	poise = data.poise
	target = null
	_since_stagger = 0.0
	_far_time = 0.0
	_burn_left = 0.0
	_chill_left = 0.0
	_chill_scale = 1.0
	_status_defense = 1.0
	_apply_status_tint()
	global_position = home
	_enter(AiState.IDLE)
	_set_alert(Alert.CALM)
	_update_phase_visuals()
	queue_redraw()

func is_enraged() -> bool:
	return enraged

## Ancang-ancang jurus yang tak bisa ditahan sedang berjalan (ikon bahaya tampil).
func shows_danger() -> bool:
	return _unblockable_windup and not _dead

#region Otak boss

func _think(delta: float) -> Vector2:
	_time += delta
	_state_time += delta
	queue_redraw()
	if not awake:
		return Vector2.ZERO
	_split_ready = maxf(0.0, _split_ready - delta)
	_rain_ready = maxf(0.0, _rain_ready - delta)
	_prune_minions()
	_update_enrage(delta)
	if ai_state == AiState.STAGGER:
		if _state_time >= _stagger_time:
			poise = data.poise
			_rest = boss.rest_time * 0.5
			_enter(AiState.CHASE)
		return Vector2.ZERO
	if not _target_valid(target) or not _in_arena(_target_point(target)):
		target = _nearest_player()
	if target == null and move == Move.NONE:
		_play("idle")
		return Vector2.ZERO
	if target != null:
		if _target_distance() > boss.kite_distance:
			_far_time += delta
		else:
			_far_time = maxf(0.0, _far_time - delta * 2.0)
	match move:
		Move.SLAM:
			return _run_slam(delta)
		Move.CHARGE:
			return _run_charge(delta)
		Move.SPIT:
			return _run_spit(delta)
		Move.SPLIT:
			return _run_split(delta)
		Move.RAIN:
			return _run_rain(delta)
		Move.ROAR:
			return _run_roar(delta)
	return _approach(delta)

## Di antara jurus: ganti fase bila HP lewat ambang, lalu mendekat sambil menunggu jeda.
func _approach(delta: float) -> Vector2:
	if boss.phase_for_ratio(float(hp) / float(data.max_hp)) > phase:
		_next_phase()
		return Vector2.ZERO
	_rest -= delta
	if _rest <= 0.0:
		_choose_move()
		return Vector2.ZERO
	if ai_state != AiState.CHASE:
		_enter(AiState.CHASE)
	var dir := _direction_to_target()
	_face(dir)
	if _target_distance() < PERSONAL_SPACE:
		_play("idle")
		return Vector2.ZERO
	_play("walk")
	return dir * data.chase_speed

func _choose_move() -> void:
	var distance := _target_distance()
	kite_response = false
	if _far_time >= boss.kite_time:
		# Anti-kiting (GDD 8.2-C4): pemain menjaga jarak terlalu lama.
		_far_time = 0.0
		kite_response = true
		CombatJuice.enemy_text(global_position + Vector2(0, -boss.sprite_scale * 22.0), "Jangan lari!", DANGER, true)
		_begin(Move.SLAM if _last_move != Move.SLAM else Move.SPIT)
		return
	if phase >= 3 and _rain_ready <= 0.0:
		_begin(Move.RAIN)
		return
	if phase >= 2 and boss.minion != null and boss.split_count > 0 and _split_ready <= 0.0 and minions.size() < boss.split_max:
		_begin(Move.SPLIT)
		return
	var options: Array[Move] = []
	if distance <= boss.charge_range:
		options.append_array([Move.CHARGE, Move.CHARGE, Move.SLAM])
	else:
		options.append_array([Move.SPIT, Move.SPIT, Move.SLAM])
	# Jangan mengulang jurus yang sama terlalu sering.
	if options.has(_last_move) and randf() < 0.6:
		options.erase(_last_move)
	_begin(options[randi() % options.size()])

func _begin(next: Move) -> void:
	move = next
	_step = 0
	_move_time = 0.0
	_unblockable_windup = false
	if next != Move.ROAR:
		_last_move = next
	match next:
		Move.SLAM:
			_combo_left = boss.slam_combo_for(phase)
			_start_slam(boss.slam_windup)
		Move.CHARGE, Move.SPIT:
			_enter(AiState.WINDUP)
		Move.SPLIT:
			_enter(AiState.WINDUP)
			CombatJuice.enemy_text(global_position + Vector2(0, -boss.sprite_scale * 22.0), "Pecah!", GOLD)
		Move.RAIN:
			_enter(AiState.WINDUP)
			_unblockable_windup = true
			_rain_left = boss.rain_count
			_rain_timer = 0.0
			CombatJuice.enemy_text(global_position + Vector2(0, -boss.sprite_scale * 24.0), "Hujan Emas!", DANGER, true)
		Move.ROAR:
			_enter(AiState.IDLE)
			_invulnerable = boss.roar_time
			CombatJuice.squash(_sprite, 0.5)
			Juice.shake(3.0, 0.5)
			Juice.sfx(SfxSynth.boom(), -4.0, 0.0, -5.0)

func _end_move() -> void:
	move = Move.NONE
	_step = 0
	_move_time = 0.0
	_unblockable_windup = false
	kite_response = false
	collision_layer = 1
	_sprite.position = Vector2.ZERO
	_rest = boss.rest_time * _tempo() * randf_range(0.8, 1.2)
	_enter(AiState.CHASE)

## Jurus dihentikan paksa (stagger, reset). Retakan hantaman yang belum meledak ikut hilang.
func _cancel_move() -> void:
	if is_instance_valid(_slam_hazard) and not _slam_hazard.detonated:
		_slam_hazard.queue_free()
	_slam_hazard = null
	move = Move.NONE
	_step = 0
	_unblockable_windup = false
	kite_response = false
	collision_layer = 1
	if _sprite != null:
		_sprite.position = Vector2.ZERO
	_rest = boss.rest_time * 0.5 if boss != null else 0.5

## Hantaman: jongkok (retakan tumbuh di titik jatuh) -> melayang -> mendarat meledakkan retakan.
func _start_slam(windup: float) -> void:
	_step = 0
	_move_time = 0.0
	_slam_windup = windup * _tempo()
	_enter(AiState.WINDUP)
	_unblockable_windup = true
	_slam_to = _clamp_to_arena(_target_point(target) + target.velocity * 0.2 if target != null else global_position)
	var total := _slam_windup + boss.slam_air_time
	_slam_hazard = _spawn_hazard(_slam_to, boss.slam_radius, total, _power(boss.slam_damage), false)
	_slam_hazard.auto_detonate = false

func _run_slam(delta: float) -> Vector2:
	_move_time += delta
	match _step:
		0:
			if _move_time >= _slam_windup:
				_step = 1
				_move_time = 0.0
				_slam_from = global_position
				_stop_windup_tint()
				collision_layer = 0
				_face(_slam_to - global_position)
				_play("walk", true)
				CombatJuice.squash(_sprite, 0.45)
				Juice.sfx(SfxSynth.whoosh(), -6.0, 0.05, -7.0)
		1:
			var t := clampf(_move_time / maxf(0.05, boss.slam_air_time), 0.0, 1.0)
			global_position = _slam_from.lerp(_slam_to, t)
			_sprite.position.y = -sin(t * PI) * SLAM_HEIGHT
			if t >= 1.0:
				_land()
		2:
			if _move_time >= 0.4 * _tempo():
				if _combo_left > 0:
					_start_slam(boss.slam_windup * 0.6)
					_step = 0
				else:
					_end_move()
	return Vector2.ZERO

func _land() -> void:
	_sprite.position = Vector2.ZERO
	collision_layer = 1
	_unblockable_windup = false
	if is_instance_valid(_slam_hazard):
		_slam_hazard.detonate()
	_slam_hazard = null
	_combo_left -= 1
	_step = 2
	_move_time = 0.0
	_enter(AiState.RECOVER)
	CombatJuice.squash(_sprite, 0.6)
	CombatJuice.dust(global_position, Vector2.LEFT)
	CombatJuice.dust(global_position, Vector2.RIGHT)

## Terjangan: kilat merah + panah arah (mengunci arah di 60% ancang-ancang), lalu menerjang.
func _run_charge(delta: float) -> Vector2:
	_move_time += delta
	var windup := boss.charge_windup * _tempo()
	match _step:
		0:
			if _move_time < windup * 0.6:
				_attack_dir = _direction_to_target()
				_face(_attack_dir)
			if _move_time >= windup:
				_step = 1
				_move_time = 0.0
				_charge_hit = false
				_enter(AiState.ATTACK)
				Juice.sfx(SfxSynth.whoosh(), -4.0, 0.05, -4.0)
			return Vector2.ZERO
		1:
			if not _charge_hit and target != null and _target_distance() <= data.body_radius + 10.0:
				_charge_hit = true
				_attack_landed = true
				_strike(target, _power(boss.charge_damage), _attack_dir)
			var blocked := _move_time > 0.1 and get_slide_collision_count() > 0 and get_real_velocity().length() < boss.charge_speed * 0.3
			if _move_time >= boss.charge_time or blocked:
				if blocked:
					Juice.shake(2.0, 0.2)
					CombatJuice.dust(global_position, -_attack_dir)
				_step = 2
				_move_time = 0.0
				_enter(AiState.RECOVER)
				return Vector2.ZERO
			if int(_move_time * 20.0) % 2 == 0:
				CombatJuice.dust(global_position, -_attack_dir)
			return _attack_dir * boss.charge_speed
		2:
			if _move_time >= 0.55 * _tempo():
				_end_move()
	return Vector2.ZERO

## Semburan: gumpalan emas menyebar ke arah pemain. Anti-kiting = lebih cepat.
func _run_spit(delta: float) -> Vector2:
	_move_time += delta
	match _step:
		0:
			_attack_dir = _direction_to_target()
			_face(_attack_dir)
			if _move_time >= boss.spit_windup * _tempo():
				_fire_spit()
				_step = 1
				_move_time = 0.0
				_enter(AiState.RECOVER)
		1:
			if _move_time >= 0.45 * _tempo():
				_end_move()
	return Vector2.ZERO

func _fire_spit() -> void:
	var count := boss.spit_count_for(phase)
	var speed := boss.spit_speed * (boss.kite_spit_speed_scale if kite_response else 1.0)
	var spread := deg_to_rad(boss.spit_spread_deg)
	for i in count:
		var angle := (float(i) - float(count - 1) * 0.5) * spread
		var spit := Spit.new()
		spit.direction = _attack_dir.rotated(angle)
		spit.speed = speed
		spit.damage = _power(boss.spit_damage)
		spit.bounds = arena_rect.grow(4.0)
		get_parent().add_child(spit)
		spit.global_position = global_position + _attack_dir * (data.body_radius + 4.0)
		_hazards.append(spit)
	CombatJuice.squash(_sprite, 0.35)
	Juice.play(data.hit_feedback, global_position, -6.0)

func _run_split(delta: float) -> Vector2:
	_move_time += delta
	match _step:
		0:
			if _move_time >= 0.7 * _tempo():
				_spawn_minions()
				_split_ready = boss.split_cooldown
				_step = 1
				_move_time = 0.0
				_enter(AiState.RECOVER)
		1:
			if _move_time >= 0.6 * _tempo():
				_end_move()
	return Vector2.ZERO

func _spawn_minions() -> void:
	var start := randf() * TAU
	for i in boss.split_count:
		if minions.size() >= boss.split_max:
			break
		var pos := _clamp_to_arena(global_position + Vector2.from_angle(start + TAU * i / boss.split_count) * (data.body_radius + 18.0))
		var minion := Enemy.spawn(boss.minion, get_parent(), pos)
		if minion == null:
			continue
		minions.append(minion)
		if target != null:
			minion.answer_help(target, self)
		CombatJuice.death_burst(pos, GOLD)
	CombatJuice.squash(_sprite, 0.5)

## Hujan Emas (fase 3): retakan beruntun di sekitar pemain, masing-masing dengan gumpalan jatuh.
func _run_rain(delta: float) -> Vector2:
	_move_time += delta
	match _step:
		0:
			if _move_time >= 0.8 * _tempo():
				_step = 1
				_move_time = 0.0
				_enter(AiState.RECOVER)
		1:
			_rain_timer -= delta
			if _rain_left > 0 and _rain_timer <= 0.0:
				_rain_timer = 0.22 * _tempo()
				var center := _target_point(target) if target != null else global_position
				var offset := Vector2.ZERO if _rain_left == boss.rain_count else Vector2.from_angle(randf() * TAU) * randf_range(10.0, 48.0)
				var drop := _spawn_hazard(_clamp_to_arena(center + offset), boss.rain_radius, boss.rain_delay, _power(boss.rain_damage), true)
				drop.falling = true
				_rain_left -= 1
				_unblockable_windup = _rain_left > 0
			if _rain_left <= 0 and _move_time >= boss.rain_delay + 0.3:
				_rain_ready = boss.rain_cooldown
				_end_move()
	return Vector2.ZERO

func _run_roar(delta: float) -> Vector2:
	_move_time += delta
	if int(_move_time * 10.0) % 3 == 0:
		CombatJuice.squash(_sprite, 0.12)
	if _move_time >= boss.roar_time:
		_invulnerable = 0.0
		_end_move()
		_rest = 0.4
	return Vector2.ZERO

func _next_phase() -> void:
	phase = boss.phase_for_ratio(float(hp) / float(data.max_hp))
	poise = data.poise
	_begin(Move.ROAR)
	CombatJuice.enemy_text(global_position + Vector2(0, -boss.sprite_scale * 26.0), "Fase %d!" % phase, PHASE_AURA[clampi(phase - 1, 0, 2)].lightened(0.3), true)
	CombatJuice.ring(global_position, data.body_radius * 4.0, PHASE_AURA[clampi(phase - 1, 0, 2)])
	Juice.shake(5.0, 0.6)
	_update_phase_visuals()
	phase_changed.emit(phase)

func _update_enrage(delta: float) -> void:
	if ai_state == AiState.STAGGER or move == Move.ROAR:
		return
	if enraged:
		_enrage_left -= delta
		if _enrage_left <= 0.0:
			_set_enraged(false)
	else:
		_since_stagger += delta
		if _since_stagger >= boss.enrage_time:
			_set_enraged(true)

func _set_enraged(value: bool) -> void:
	if enraged == value:
		return
	enraged = value
	_since_stagger = 0.0
	if value:
		_enrage_left = boss.enrage_duration
		CombatJuice.enemy_text(global_position + Vector2(0, -boss.sprite_scale * 26.0), "MURKA!", DANGER, true)
		CombatJuice.ring(global_position, data.body_radius * 4.0, ENRAGE_AURA)
		Juice.shake(4.0, 0.4)
		Juice.sfx(SfxSynth.boom(), -6.0, 0.0, 3.0)
	_update_phase_visuals()
	enrage_changed.emit(value)

#endregion

#region Badan

func _tempo() -> float:
	return super._tempo() * boss.tempo_for(phase) * (boss.enrage_tempo if enraged else 1.0)

## Damage jurus setelah pengali fase dan murka.
func _power(base: int) -> int:
	return maxi(1, roundi(base * boss.attack_scale_for(phase) * (boss.enrage_attack_scale if enraged else 1.0)))

func _strike(player: Player, amount: int, direction: Vector2) -> void:
	player.take_hit(amount, self, direction * 16.0)

func _contact_active() -> bool:
	return awake and super._contact_active() and not (move == Move.SLAM and _step == 1)

## Parry hanya untuk terjangan (Enemy: ai_state ATTACK).
func can_be_parried() -> bool:
	return super.can_be_parried() and move == Move.CHARGE

func stagger(seconds: float) -> void:
	if _dead:
		return
	_cancel_move()
	_since_stagger = 0.0
	if enraged:
		_set_enraged(false)
	super.stagger(seconds)

## Seperti Enemy.take_hit, tetapi boss tidak tersentak tiap pukulan dan tidak terdorong.
## Kebal saat tidur dan saat meraung (transisi fase).
func take_hit(attack: int, source: Node, knockback: Vector2 = Vector2.ZERO) -> bool:
	if _dead or not awake or _invulnerable > 0.0 or move == Move.ROAR:
		return false
	_invulnerable = HIT_INVULNERABLE
	var critical := Combat.hit_critical
	var staggered := is_staggered()
	var damage := Combat.damage_after_defense(attack, 0 if Combat.hit_ignores_defense else defense())
	if staggered and not critical:
		damage = roundi(damage * Combat.RULES.staggered_damage_scale)
	hp = maxi(0, hp - damage)
	var heavy := CombatJuice.heavy_hit
	if critical:
		CombatJuice.enemy_text(global_position + Vector2(0, -boss.sprite_scale * 22.0), "KRITIS!", Color(1.0, 0.4, 0.3), true)
	CombatJuice.damage_number(str(damage) + ("!" if heavy else ""), global_position + Vector2(randf_range(-8.0, 8.0), -boss.sprite_scale * 14.0), CombatJuice.HEAVY_COLOR if heavy else CombatJuice.HIT_COLOR, heavy)
	if not data.hit_feedback.is_empty():
		Juice.play(data.hit_feedback, global_position)
	CombatJuice.impact(damage, heavy)
	_knockback = knockback * 6.0 * (1.0 - data.knockback_resist)
	_flash()
	CombatJuice.squash(_sprite, 0.22 if heavy else 0.12)
	if hp <= 0:
		_die()
		return true
	var attacker := source as Player
	if _target_valid(attacker) and attacker != target and (target == null or randf() < 0.25):
		target = attacker
	if critical:
		poise = data.poise
	elif not staggered:
		poise -= Combat.hit_poise if Combat.hit_poise >= 0.0 else float(attack)
		_poise_rest = data.poise_regen_delay
		# Melayang di udara tidak bisa dijatuhkan; poise pecah setelah mendarat.
		if poise <= 0.0 and not (move == Move.SLAM and _step == 1):
			stagger(data.stagger_time)
	return true

func _die() -> void:
	_cancel_move()
	_clear_hazards()
	super._die()
	Juice.hitstop(160)
	Juice.shake(6.0, 0.7)
	CombatJuice.ring(global_position, data.body_radius * 5.0, GOLD)
	for minion in minions:
		if is_instance_valid(minion) and not minion.is_dead():
			minion.take_hit(99999, self)
	minions.clear()
	if _embers != null:
		_embers.emitting = false

func _nearest_player() -> Player:
	var best: Player = null
	var best_distance := INF
	for node in get_tree().get_nodes_in_group(Combat.PLAYER_GROUP):
		var player := node as Player
		if not _target_valid(player) or not _in_arena(_target_point(player)):
			continue
		var distance := global_position.distance_to(_target_point(player))
		if distance < best_distance:
			best = player
			best_distance = distance
	return best

func _in_arena(point: Vector2) -> bool:
	return not arena_rect.has_area() or arena_rect.has_point(point)

func _clamp_to_arena(point: Vector2) -> Vector2:
	if not arena_rect.has_area():
		return point
	var inner := arena_rect.grow(-data.body_radius)
	return point.clamp(inner.position, inner.end)

func _prune_minions() -> void:
	for i in range(minions.size() - 1, -1, -1):
		if not is_instance_valid(minions[i]) or minions[i].is_dead():
			minions.remove_at(i)

func _spawn_hazard(at: Vector2, radius: float, delay: float, damage: int, auto: bool) -> Hazard:
	var hazard := Hazard.new()
	hazard.radius = radius
	hazard.delay = delay
	hazard.damage = damage
	hazard.auto_detonate = auto
	get_parent().add_child(hazard)
	hazard.global_position = at
	_hazards.append(hazard)
	return hazard

func _clear_hazards() -> void:
	for node in _hazards:
		if is_instance_valid(node):
			node.queue_free()
	_hazards.clear()

#endregion

#region Gambar

func _aura_color() -> Color:
	if enraged:
		return ENRAGE_AURA
	return PHASE_AURA[clampi(phase - 1, 0, PHASE_AURA.size() - 1)]

## Bara aura (fase 2+ dan murka).
func _update_phase_visuals() -> void:
	var aura := _aura_color()
	if aura.a <= 0.0:
		if _embers != null:
			_embers.emitting = false
		return
	if _embers == null:
		_embers = CPUParticles2D.new()
		_embers.amount = 18
		_embers.lifetime = 0.9
		_embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		_embers.emission_sphere_radius = data.body_radius * 1.4
		_embers.direction = Vector2.UP
		_embers.spread = 30.0
		_embers.gravity = Vector2(0, -45)
		_embers.initial_velocity_min = 8.0
		_embers.initial_velocity_max = 20.0
		_embers.scale_amount_min = 1.0
		_embers.scale_amount_max = 2.0
		_embers.position = Vector2(0, -data.body_radius)
		add_child(_embers)
	_embers.color = Color(aura, 0.9).lightened(0.2)
	_embers.amount = 30 if enraged else 18
	_embers.emitting = true

func _draw() -> void:
	super._draw()
	if _dead or boss == null:
		return
	var lift := -_sprite.position.y
	# Bayangan di tanah: mengecil saat boss melayang (tanda titik jatuh selain retakan).
	var shadow := data.body_radius * 1.5 * (1.0 - 0.4 * lift / SLAM_HEIGHT)
	draw_set_transform(Vector2(0, 2), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, shadow, Color(0, 0, 0, 0.3))
	var aura := _aura_color()
	if aura.a > 0.0:
		var pulse := 0.5 + 0.5 * sin(_time * (10.0 if enraged else 5.0))
		draw_circle(Vector2(0, -lift / 0.45), data.body_radius * 2.0 + pulse * 3.0, Color(aura, aura.a * (0.35 + 0.25 * pulse)))
		draw_arc(Vector2(0, -lift / 0.45), data.body_radius * 2.3 + pulse * 3.0, 0.0, TAU, 32, Color(aura.lightened(0.3), aura.a), 1.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if move == Move.CHARGE and _step == 0:
		_draw_charge_line()
	if shows_danger():
		draw_danger_icon(self, Vector2(0, -data.body_radius * 2.2 - 14.0 - lift), _time)

## Tanda terjangan: panah merah bertitik sepanjang jarak terjangan.
func _draw_charge_line() -> void:
	var length := boss.charge_speed * boss.charge_time
	var progress := clampf(_move_time / maxf(0.05, boss.charge_windup * _tempo()), 0.0, 1.0)
	var alpha := 0.3 + 0.5 * progress
	var distance := data.body_radius
	while distance < length * progress:
		var at := _attack_dir * distance
		var side := _attack_dir.orthogonal() * 4.0
		draw_line(at - _attack_dir * 3.0 + side, at, Color(DANGER, alpha), 1.5)
		draw_line(at - _attack_dir * 3.0 - side, at, Color(DANGER, alpha), 1.5)
		distance += 10.0

## Ikon bahaya (segitiga merah dengan tanda seru): serangan ini tidak bisa ditahan/di-parry.
static func draw_danger_icon(canvas: CanvasItem, at: Vector2, time: float) -> void:
	var p := (at + Vector2(0, sin(time * 8.0))).round()
	var blink := 0.75 + 0.25 * sin(time * 16.0)
	var points := PackedVector2Array([p + Vector2(0, -7), p + Vector2(7, 5), p + Vector2(-7, 5)])
	canvas.draw_colored_polygon(points, Color(DANGER, 0.95 * blink))
	points.append(points[0])
	canvas.draw_polyline(points, Color(1.0, 0.9, 0.3, blink), 1.0)
	canvas.draw_rect(Rect2(p + Vector2(-1, -4), Vector2(2, 4)), Color.WHITE)
	canvas.draw_rect(Rect2(p + Vector2(-1, 1.5), Vector2(2, 2)), Color.WHITE)

#endregion


## Retakan tanah bertelegraf (hantaman / Hujan Emas). Lingkaran merah mengisi dari tengah,
## retakan memanjang, ikon bahaya berkedip; saat meledak melukai semua pemain di dalam radius.
## Tak bisa ditahan (is_unblockable); roll dengan i-frame tetap lolos.
class Hazard extends Node2D:
	const LINGER := 0.5
	var radius := 24.0
	var delay := 0.8
	var damage := 10
	## false = menunggu detonate() dari boss (hantaman mendarat).
	var auto_detonate := true
	## Gumpalan emas jatuh dari atas (Hujan Emas).
	var falling := false
	var detonated := false
	var _time := 0.0
	var _detonated_at := 0.0
	var _cracks: Array[PackedVector2Array] = []

	func _ready() -> void:
		z_index = -7
		z_as_relative = false
		var count := 7
		for i in count:
			var angle := TAU * i / count + randf_range(-0.3, 0.3)
			var line := PackedVector2Array([Vector2.ZERO])
			var reach := radius * randf_range(0.75, 1.05)
			for k in range(1, 5):
				var along := reach * k / 4.0
				line.append(Vector2.from_angle(angle + randf_range(-0.25, 0.25)) * along)
			_cracks.append(line)

	func is_unblockable() -> bool:
		return true

	func poise_damage_to_player() -> float:
		return damage * 2.0

	func progress() -> float:
		return clampf(_time / maxf(0.05, delay), 0.0, 1.0)

	func _process(delta: float) -> void:
		_time += delta
		if not detonated and auto_detonate and _time >= delay:
			detonate()
		elif detonated and _time >= _detonated_at + LINGER:
			queue_free()
		queue_redraw()

	func detonate() -> void:
		if detonated or not is_inside_tree():
			return
		detonated = true
		_detonated_at = _time
		for node in get_tree().get_nodes_in_group(Combat.PLAYER_GROUP):
			var player := node as Player
			if player == null or player.is_defeated or not player.is_inside_tree() or player.data.hp <= 0:
				continue
			var offset := player.global_position + Player.FEET_OFFSET - global_position
			if offset.length() <= radius + 4.0:
				var push := offset.normalized() if offset.length() > 0.5 else Vector2.DOWN
				player.take_hit(damage, self, push * 16.0)
		CombatJuice.ring(global_position, radius, Boss.GOLD)
		CombatJuice.death_burst(global_position, Boss.GOLD)
		Juice.sfx(SfxSynth.boom(), -5.0, 0.08)
		Juice.shake(3.0 if falling else 4.5, 0.25)

	func _draw() -> void:
		var t := progress()
		if not detonated:
			var pulse := 0.5 + 0.5 * sin(_time * 18.0)
			draw_circle(Vector2.ZERO, radius * t, Color(Boss.DANGER, 0.14 + 0.12 * pulse))
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(Boss.DANGER, 0.45 + 0.4 * pulse), 1.0)
			for crack in _cracks:
				var shown := maxi(2, ceili(crack.size() * t))
				draw_polyline(crack.slice(0, shown), Color(0.2, 0.08, 0.02, 0.5 + 0.4 * t), 1.0)
			if falling:
				var height := (1.0 - t) * 90.0
				draw_circle(Vector2(0, -height), 4.0, Boss.GOLD)
				draw_circle(Vector2(-1, -height - 1), 1.5, Color(1, 1, 0.85))
			Boss.draw_danger_icon(self, Vector2(0, -radius - 10.0), _time)
		else:
			var fade := 1.0 - clampf((_time - _detonated_at) / LINGER, 0.0, 1.0)
			for crack in _cracks:
				draw_polyline(crack, Color(0.15, 0.06, 0.02, 0.8 * fade), 2.0)
			draw_arc(Vector2.ZERO, radius * (1.0 + 0.4 * (1.0 - fade)), 0.0, TAU, 32, Color(1.0, 0.9, 0.5, fade), 2.0)


## Gumpalan semburan boss. Bisa ditahan (block) dan dihindari roll; meletus di batas arena.
class Spit extends Node2D:
	var direction := Vector2.RIGHT
	var speed := 150.0
	var damage := 10
	var bounds := Rect2()
	var max_distance := 420.0
	var _travelled := 0.0

	func _ready() -> void:
		z_index = 5

	func poise_damage_to_player() -> float:
		return damage * 1.5

	func _physics_process(delta: float) -> void:
		var step := direction * speed * delta
		global_position += step
		_travelled += step.length()
		for node in get_tree().get_nodes_in_group(Combat.PLAYER_GROUP):
			var player := node as Player
			if player == null or player.is_defeated or not player.is_inside_tree():
				continue
			if (player.global_position + Player.FEET_OFFSET).distance_to(global_position) <= 9.0:
				if player.take_hit(damage, self, direction * 14.0):
					_pop()
					return
		if _travelled >= max_distance or (bounds.has_area() and not bounds.has_point(global_position)):
			_pop()
			return
		queue_redraw()

	func _pop() -> void:
		CombatJuice.spark(global_position + Vector2(0, -6), Boss.GOLD, 6)
		queue_free()

	func _draw() -> void:
		# Digambar sedikit di atas tanah supaya terlihat melayang.
		for i in range(3, 0, -1):
			draw_circle(-direction * i * 3.0 + Vector2(0, -6), 3.2 - i * 0.6, Color(Boss.GOLD, 0.25 * (4 - i)))
		draw_circle(Vector2(0, -6), 3.4, Boss.GOLD)
		draw_circle(Vector2(-1, -7), 1.2, Color(1, 1, 0.85))
		draw_set_transform(Vector2(0, 1), 0.0, Vector2(1.0, 0.4))
		draw_circle(Vector2.ZERO, 3.0, Color(0, 0, 0, 0.25))
