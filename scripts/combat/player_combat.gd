class_name PlayerCombat
extends Node2D

## Mekanika tempur soulslike milik satu pemain (GDD 8.2-A): bar stamina tempur, Exhausted,
## poise, block/parry, serangan berat (tahan klik kiri), dodge roll, dan weapon art.
## Dibuat Player saat _ready; angka di Combat.RULES (resources/combat/combat_rules.tres).
## Bar stamina tempur digambar di atas kepala, terpisah dari stamina harian di HUD.

signal stamina_changed(current: float, maximum: float)
signal exhausted_changed(active: bool)

enum HitOutcome { HIT, EVADED, PARRIED, BLOCKED }

const BAR_SIZE := Vector2(18, 2)
const BAR_OFFSET := Vector2(0, -27)
const STAMINA_COLOR := Color(0.45, 0.9, 0.35)
const EXHAUSTED_COLOR := Color(0.95, 0.35, 0.3)
const GUARD_COLOR := Color(0.75, 0.9, 1.0)

var player: Player
var stamina := 100.0
var poise := 10.0
var guarding := false
## Klik kiri sedang ditahan untuk serangan berat.
var charging := false
## Tes otomatis: tahan block tanpa menekan tombol.
var force_guard := false

var _rest := 0.0
var _exhausted := 0.0
var _poise_rest := 0.0
var _guard_started_ms := -100000
var _parry_blocked_until_ms := 0
var _charge_time := 0.0
var _run_pressed_ms := -1
var _last_run_ms := -100000
var _roll_ended_ms := -100000
var _iframes := 0.0
var _art_ready_ms := {}
var _bar_alpha := 0.0
var _flash := 0.0

func _ready() -> void:
	z_index = 20
	z_as_relative = false
	stamina = max_stamina()
	poise = max_poise()

func max_stamina() -> float:
	return float(Combat.RULES.combat_stamina_max)

func max_poise() -> float:
	return Combat.RULES.player_poise_base + Combat.RULES.player_poise_per_weight * Combat.equip_load(player.data)

func is_exhausted() -> bool:
	return _exhausted > 0.0

## Pengali kecepatan gerak (Exhausted dan menahan block).
func speed_scale() -> float:
	if is_exhausted():
		return Combat.RULES.exhausted_speed_scale
	if guarding:
		return Combat.RULES.guard_speed_scale
	return 1.0

## Pulihkan stamina tempur (Berkah Peri, tier Fairy). Tidak berlaku saat Exhausted.
func restore(amount: float) -> void:
	if amount <= 0.0 or is_exhausted():
		return
	_set_stamina(minf(max_stamina(), stamina + amount))

## Pakai stamina tempur. Ditolak saat Exhausted atau bar kosong; boleh menguras sampai 0
## (sisa kurang dari biaya tetap jalan), lalu Exhausted.
func spend(amount: float) -> bool:
	# Role Combat Lv2/Lv4 (GDD 13): serangan, roll, dan art lebih hemat stamina.
	amount *= 1.0 - clampf(SkillSystem.stat(player.data, &"combat_stamina"), 0.0, 0.9)
	if amount <= 0.0:
		return not is_exhausted()
	if is_exhausted() or stamina <= 0.0:
		_flash = 0.4
		return false
	_set_stamina(stamina - amount)
	_rest = Combat.RULES.regen_delay
	if stamina <= 0.0:
		_start_exhausted()
	return true

func _set_stamina(value: float) -> void:
	stamina = clampf(value, 0.0, max_stamina())
	stamina_changed.emit(stamina, max_stamina())

func _start_exhausted() -> void:
	_exhausted = Combat.RULES.exhausted_time
	guarding = false
	charging = false
	_flash = 0.6
	CombatJuice.float_text(player, "Lelah!", EXHAUSTED_COLOR)
	exhausted_changed.emit(true)

## Pulihkan semua (tidur, bangun dari kalah, tes).
func reset() -> void:
	_exhausted = 0.0
	_iframes = 0.0
	guarding = false
	charging = false
	_set_stamina(max_stamina())
	poise = max_poise()

#region Input

func _unhandled_input(event: InputEvent) -> void:
	if player == null or player.is_input_locked() or player.is_defeated:
		return
	var input := player.input
	if input.is_event(event, &"dodge"):
		if request_dodge():
			get_viewport().set_input_as_handled()
	elif input.is_event(event, &"run") and _run_pressed_ms < 0:
		# Trigger gamepad mengirim event berulang selama ditekan; hitung dari tekanan pertama saja.
		_run_pressed_ms = Time.get_ticks_msec()

## Tombol combat yang bisa berupa trigger (LT/RT) dibaca per frame: Input Map menghitung
## "baru ditekan" sekali walau trigger mengirim banyak event gerak.
func _poll_combat_buttons() -> void:
	if player.is_input_locked() or player.is_defeated or not player.holds_weapon():
		return
	var input := player.input
	if input.just_pressed(&"weapon_art"):
		player.tool_controller.weapon_art()
	if input.just_pressed(&"heavy_attack"):
		# RT (soulslike): serangan berat langsung tanpa menahan.
		charging = false
		player.tool_controller.attack(CombatState.Kind.HEAVY)
	if input.just_pressed(&"lock_on") and player.lock_on != null:
		player.lock_on.toggle()

func _process(delta: float) -> void:
	if player == null:
		return
	var rules := Combat.RULES
	var state := player.state_machine.current_state
	var input := player.input
	var free := not player.is_input_locked() and not player.is_defeated
	_poll_combat_buttons()
	# Lari ditekan singkat sambil memegang senjata = roll (Shift / gamepad B, seperti soulslike).
	if _run_pressed_ms >= 0 and not input.pressed(&"run"):
		var held := (Time.get_ticks_msec() - _run_pressed_ms) / 1000.0
		_run_pressed_ms = -1
		if free and held <= rules.tap_run_roll_time and player.holds_weapon() and not player.is_jumping():
			request_dodge()
	if state is RunState:
		_last_run_ms = Time.get_ticks_msec()

	if _exhausted > 0.0:
		_exhausted -= delta
		if _exhausted <= 0.0:
			_exhausted = 0.0
			exhausted_changed.emit(false)
	_iframes = maxf(0.0, _iframes - delta)
	_flash = maxf(0.0, _flash - delta)

	# Lari sambil memegang senjata menguras stamina tempur; tidak pulih selama berlari.
	var running := state is RunState and player.holds_weapon()
	if running and not is_exhausted():
		_set_stamina(stamina - rules.run_cost_per_second * delta)
		_rest = rules.regen_delay
		if stamina <= 0.0:
			_start_exhausted()
	elif _rest > 0.0:
		_rest -= delta
	elif not is_exhausted() and stamina < max_stamina():
		_set_stamina(stamina + rules.combat_stamina_regen * delta * (rules.guard_regen_scale if guarding else 1.0))

	if _poise_rest > 0.0:
		_poise_rest -= delta
	else:
		poise = minf(max_poise(), poise + rules.poise_regen_per_second * delta)

	_update_guard(free, state)
	_update_charge(free, delta)
	_update_bar(delta)
	queue_redraw()

func _update_guard(free: bool, state: State) -> void:
	var want := free and player.holds_weapon() and (player.input.pressed(&"guard") or force_guard) and not is_exhausted() \
		and (state is IdleState or state is MoveState)
	if want and not guarding:
		guarding = true
		var now := Time.get_ticks_msec()
		# Anti-spam: menekan ulang terlalu cepat tidak membuka jendela parry.
		_guard_started_ms = now if now >= _parry_blocked_until_ms else -100000
		_parry_blocked_until_ms = now + int(Combat.RULES.parry_cooldown * 1000.0)
	elif not want and guarding:
		guarding = false
	if guarding:
		var dir := player.aim_vector()
		player.update_facing_direction(dir, true)

func is_parry_window() -> bool:
	return guarding and Time.get_ticks_msec() - _guard_started_ms <= int((Combat.RULES.parry_window + SkillSystem.stat(player.data, &"parry_window")) * 1000.0)

## Dipanggil ToolController saat klik kiri ditekan dengan senjata: mulai menahan.
func begin_charge() -> void:
	charging = true
	_charge_time = 0.0

func charge_ratio() -> float:
	return clampf(_charge_time / maxf(0.01, Combat.RULES.heavy_charge_time), 0.0, 1.0) if charging else 0.0

func _update_charge(free: bool, delta: float) -> void:
	if not charging:
		return
	if not free or not player.holds_weapon() or is_exhausted() or guarding:
		charging = false
		return
	_charge_time += delta
	if player.input.pressed(&"use_tool"):
		return
	charging = false
	var heavy := _charge_time >= Combat.RULES.heavy_charge_time
	player.tool_controller.attack(CombatState.Kind.HEAVY if heavy else CombatState.Kind.LIGHT)

#endregion

#region Roll

## Roll ke arah gerak (atau arah bidik/hadap saat diam). Boleh membatalkan recovery serangan
## di akhir animasi (WeaponStyle.recovery_cancel_ratio).
func request_dodge() -> bool:
	var tools := player.tool_controller
	var state := player.state_machine.current_state
	var cancel := state == tools.combat_state and tools.combat_state.can_cancel()
	if not (state is IdleState or state is MoveState or cancel):
		return false
	if is_exhausted():
		_flash = 0.4
		return false
	var roll := Combat.roll_class(player.data)
	if not spend(CombatRules.pick(Combat.RULES.roll_cost, roll, 20.0)):
		return false
	var dir := player.get_input_vector()
	if dir.length() < 0.1:
		dir = player.aim_vector()
	charging = false
	guarding = false
	tools.dodge_state.start(dir, roll)
	player.state_machine.change_state(tools.dodge_state)
	return true

func begin_iframes(seconds: float) -> void:
	_iframes = seconds + SkillSystem.stat(player.data, &"iframes")

func on_roll_finished() -> void:
	_roll_ended_ms = Time.get_ticks_msec()

func is_evading() -> bool:
	return _iframes > 0.0

func ran_recently() -> bool:
	return Time.get_ticks_msec() - _last_run_ms <= int(Combat.RULES.sprint_attack_window * 1000.0)

func rolled_recently() -> bool:
	return Time.get_ticks_msec() - _roll_ended_ms <= int(Combat.RULES.roll_attack_window * 1000.0)

#endregion

#region Terkena serangan

## Dipanggil Player.take_hit sebelum damage. [hasil, damage yang tersisa].
func intercept(raw_attack: int, source: Node) -> Array:
	if is_evading():
		CombatJuice.float_text(player, "Hindar", Color(0.8, 0.95, 1.0))
		return [HitOutcome.EVADED, 0]
	if guarding and _faces(source) and _unblockable(source):
		# Serangan bertanda bahaya (GDD 8.2-C): menahan tidak berguna, hanya roll/jaga jarak.
		CombatJuice.float_text(player, "Tak bisa ditahan!", EXHAUSTED_COLOR)
		return [HitOutcome.HIT, raw_attack]
	if guarding and _faces(source):
		# Senjata beradu (block/parry) terdengar musuh di sekitar (GDD 8.2-B2).
		Perception.noise(player, player.global_position, Perception.RULES.clash_noise_radius, player)
		if is_parry_window() and source != null and source.has_method("can_be_parried") and source.can_be_parried():
			_parry(source)
			return [HitOutcome.PARRIED, 0]
		var style := Combat.style_for(player.tool_controller.current_item)
		var reduction := style.block_reduction if style != null else 0.5
		var kept := maxi(0, roundi(raw_attack * (1.0 - reduction)))
		spend(raw_attack * reduction * Combat.RULES.guard_stamina_per_damage)
		Juice.play(&"mine", player.global_position, -4.0)
		CombatJuice.spark(_guard_point(), GUARD_COLOR, 6)
		if is_exhausted():
			# Stamina habis karena menahan: block jebol.
			CombatJuice.float_text(player, "Block jebol!", EXHAUSTED_COLOR)
			poise = 0.0
		return [HitOutcome.BLOCKED, kept]
	return [HitOutcome.HIT, raw_attack]

func _unblockable(source: Node) -> bool:
	return source != null and source.has_method("is_unblockable") and source.is_unblockable()

func _faces(source: Node) -> bool:
	if not source is Node2D:
		return true
	var to_source := (source as Node2D).global_position - (player.global_position + Player.FEET_OFFSET)
	if to_source.length() < 0.5:
		return true
	return absf(rad_to_deg(player.aim_vector().angle_to(to_source))) <= Combat.RULES.guard_half_angle_deg

func _parry(source: Node) -> void:
	source.on_parried(player)
	SkillSystem.gain(player.data, &"combat", SkillSystem.RULES.parry_exp)
	_set_stamina(stamina + 10.0)
	CombatJuice.parry_flash(player, _guard_point())

func _guard_point() -> Vector2:
	return player.global_position + Player.FEET_OFFSET * 0.5 + player.aim_vector() * 10.0

## Kurangi poise. true bila poise pecah (pemain terhuyung).
func take_poise(amount: float) -> bool:
	_poise_rest = Combat.RULES.poise_regen_delay
	poise -= amount
	if poise > 0.0:
		return false
	poise = max_poise()
	return true

#endregion

#region Weapon art

func art_ready(art: WeaponArt) -> bool:
	return Time.get_ticks_msec() >= int(_art_ready_ms.get(art.id, 0))

func start_art_cooldown(art: WeaponArt) -> void:
	_art_ready_ms[art.id] = Time.get_ticks_msec() + int(art.cooldown * 1000.0)

func art_cooldown_left(art: WeaponArt) -> float:
	return maxf(0.0, (int(_art_ready_ms.get(art.id, 0)) - Time.get_ticks_msec()) / 1000.0)

#endregion

#region Gambar

func _update_bar(delta: float) -> void:
	var wanted := stamina < max_stamina() - 0.5 or is_exhausted() or guarding or charging or _flash > 0.0
	_bar_alpha = move_toward(_bar_alpha, 1.0 if wanted else 0.0, delta * (6.0 if wanted else 2.0))

func _draw() -> void:
	if player == null:
		return
	var origin := BAR_OFFSET
	if _bar_alpha > 0.01:
		var rect := Rect2(origin - Vector2(BAR_SIZE.x * 0.5, 0), BAR_SIZE)
		draw_rect(rect.grow(1.0), Color(0.05, 0.05, 0.08, 0.75 * _bar_alpha))
		var fill := rect
		fill.size.x = BAR_SIZE.x * stamina / maxf(1.0, max_stamina())
		var color := EXHAUSTED_COLOR if is_exhausted() else STAMINA_COLOR
		if _flash > 0.0 and int(_flash * 20.0) % 2 == 0:
			color = Color.WHITE
		draw_rect(fill, Color(color, _bar_alpha))
	if guarding:
		var dir := player.aim_vector()
		var center := Player.FEET_OFFSET * 0.5 + dir * 9.0
		var color := Color.WHITE if is_parry_window() else GUARD_COLOR
		draw_arc(center, 7.0, dir.angle() - 1.1, dir.angle() + 1.1, 10, Color(color, 0.85), 1.5)
	if charging:
		var ratio := charge_ratio()
		var full := ratio >= 1.0
		var glow := Color(1.0, 0.75, 0.3, 0.35 + 0.4 * ratio) if not full else Color(1.0, 0.95, 0.6, 0.6 + 0.3 * sin(Time.get_ticks_msec() * 0.03))
		draw_arc(Player.FEET_OFFSET * 0.5, 10.0 + 2.0 * ratio, -PI * 0.5, -PI * 0.5 + TAU * ratio, 18, glow, 1.5)

#endregion
