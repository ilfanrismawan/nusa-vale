class_name FishingState
extends State

enum Phase {CAST, WAIT, BITE, REEL, END, CHARGE}

const ANIM_CAST := &"fishing_cast"
const ANIM_WAIT := &"fishing_wait"
const ANIM_HOOKED := &"fishing_hooked"
const ANIM_REEL := &"fishing_reel"
const ANIM_CATCH := &"fishing_catch"
const ANIM_MISS := &"fishing_miss"

const CAST_MAX_TIME := 2.0
const END_MAX_TIME := 2.0
const WAIT_MIN := 2.0
const WAIT_MAX := 6.0
const BITE_WINDOW := 1.2
const NIBBLE_MIN := 0.7
const NIBBLE_MAX := 1.8
const RARE_TIER := 3 # tier ini ke atas dapat kilauan ekstra saat tertangkap
const LEGENDARY_TIER := 4 # ikon ikan legendaris di mini-game
const TILE := 16.0
const FLIGHT_TIME := 0.3         # lama kail terbang (sama dengan CastMeter)
const PERFECT_BITE_MULT := 0.6   # lemparan Sempurna: gigitan lebih cepat
const CHARGE_TICK := 0.12        # detik antar bunyi naik selama charge
const CHARGE_PITCH_RANGE := 9.0  # semitone

@export var idle_state: State

var _spot: FishingSpot
var _rod: RodData
var _stamina_cost := 0
var _meter: CastMeter
var _power := 0.0
var _power_dir := 1.0
var _charge_tick := 0.0
var _perfect := false
var _splashed := false
var _hooked: FishData
var _minigame: FishingMinigame
var _phase := Phase.CAST
var _timer := 0.0
var _wait_target := 0.0
var _anim_done := false
var _bobber_pos := Vector2.ZERO
var _nibble_timer := 0.0
## Umpan yang terpasang di lemparan ini (GDD 7: serangga dan cacing). null = tanpa umpan.
var _bait: ItemData

func _init() -> void:
	animation_name = ANIM_CAST

func initialize(_player: Player, _animation_controller: AnimationController) -> void:
	super.initialize(_player, _animation_controller)
	animation_controller.animated_finished.connect(_on_anim_finished)
					
## rod = data tier pancing, stamina_cost dipotong saat kail jatuh di air.
func start(rod: RodData, stamina_cost: int) -> void:
	# Perk Fisher (GDD 13) bekerja pada salinan data pancing.
	_rod = SkillSystem.apply_rod(player.data if player != null else null, rod if rod != null else RodData.new())
	_stamina_cost = stamina_cost

func enter() -> void:
	super.enter()
	player.velocity = Vector2.ZERO
	if _rod == null:
		_rod = RodData.new()
	_hooked = null
	_spot = null
	_bait = null
	_power = 0.0
	_power_dir = 1.0
	_charge_tick = 0.0
	_perfect = false
	_splashed = false
	_nibble_timer = randf_range(NIBBLE_MIN, NIBBLE_MAX)
	_set_phase(Phase.CHARGE, ANIM_CAST)
	# Tahan pose awal lemparan selama charge.
	animation_controller.sprite.pause()
	animation_controller.sprite.set_frame_and_progress(0, 0.0)

	_meter = CastMeter.new()
	_meter.follow_target = player
	_meter.perfect_window = _rod.perfect_window
	player.world_root().add_child(_meter)
	_update_landing()

func exit() -> void:
	if is_instance_valid(_minigame):
		_minigame.queue_free()
	_minigame = null
	_free_meter()
	_hooked = null
	_spot = null
	_rod = null

func physics_update(_delta: float) -> void:
	player.velocity = Vector2.ZERO
	_timer += _delta
	
	match _phase:
		Phase.CHARGE:
			_update_charge(_delta)

		Phase.CAST:
			if not _splashed and _timer >= FLIGHT_TIME:
				_splashed = true
				_free_meter()
				Juice.play(&"cast", _bobber_pos)
				Juice.play_tool_tier(_rod)
			if _splashed and (_anim_done or _timer >= CAST_MAX_TIME):
				_set_phase(Phase.WAIT, ANIM_WAIT)
				Juice.play(&"bobber", _bobber_pos)
		
		Phase.WAIT:
			_nibble_timer -= _delta
			if _nibble_timer <= 0.0 and _wait_target - _timer > 0.4:
				# Gigitan palsu: riak kecil untuk membangun antisipasi.
				Juice.play(&"nibble", _bobber_pos)
				_nibble_timer = randf_range(NIBBLE_MIN, NIBBLE_MAX)
			if player.input.just_pressed(&"use_tool"):
				_end(false, "Terlalu cepat.. ikan kabur.")
			elif _timer >= _wait_target:
				# Umpan langka (serangga Rare ke atas) juga menaikkan peluang ikan langka.
				var bait_rare := 1.0 + (_bait.bait_bonus if _bait != null and int(_bait.rarity) >= ItemData.Rarity.RARE else 0.0)
				_hooked = FishingManager.roll_catch(_spot.location_id, _rod.rare_weight_mult * bait_rare, _rod.legendary_weight_mult)
				if _hooked == null:
					_end(false, "Tidak ada ikan yang menggigit saat ini.")
					return
				_set_phase(Phase.BITE, ANIM_HOOKED)
				Juice.play(&"bite", _bobber_pos)
				Juice.float_text("!", player.global_position + Vector2(0, -18), Color(1.0, 0.9, 0.3), 0.4)
				Notify.say("! Ikan menggigit! Klik sekarang!")
				
		Phase.BITE:
			if player.input.just_pressed(&"use_tool"):
				_start_minigame()
			elif _timer >= _bite_window():
				_end(false, "Ikan kabur...")
				
		Phase.REEL:
			pass
			
		Phase.END:
			if _anim_done or _timer >= END_MAX_TIME:
				transitioned.emit(idle_state)

# ── Charge lemparan: power memantul 0 -> 1 -> 0 selama klik ditahan ──
func _update_charge(delta: float) -> void:
	_power += _power_dir * delta / maxf(_rod.charge_time, 0.05)
	if _power >= 1.0:
		_power = 1.0
		_power_dir = -1.0
	elif _power <= 0.0:
		_power = 0.0
		_power_dir = 1.0
	_meter.power = _power
	_update_landing()
	# Ganti arah hadap (mouse) bisa melanjutkan animasi; tahan lagi di pose awal.
	if animation_controller.sprite.is_playing():
		animation_controller.sprite.pause()
		animation_controller.sprite.set_frame_and_progress(0, 0.0)

	_charge_tick -= delta
	if _charge_tick <= 0.0:
		_charge_tick = CHARGE_TICK
		Juice.play_sound(&"reel", _power * CHARGE_PITCH_RANGE)

	if not player.input.pressed(&"use_tool"):
		_release_cast()

func _landing_position(power: float) -> Vector2:
	var tiles := lerpf(_rod.min_cast_tiles, _rod.max_cast_tiles, clampf(power, 0.0, 1.0))
	var feet := player.global_position + Player.FEET_OFFSET
	var pos := feet + player.facing_direction * tiles * TILE
	if player.base_layer_ground == null:
		return pos
	var ground := player.base_layer_ground
	return ground.to_global(ground.map_to_local(player.world_to_cell(pos)))

func _update_landing() -> void:
	_bobber_pos = _landing_position(_power)
	_meter.landing = _bobber_pos
	var spot := FishingManager.find_spot_at(player, _bobber_pos)
	_meter.landing_on_water = spot != null and not _frozen(spot)

func _release_cast() -> void:
	_perfect = _meter.is_perfect()
	_update_landing()
	_spot = FishingManager.find_spot_at(player, _bobber_pos)
	if _spot == null:
		_free_meter()
		Notify.say("Kail jatuh di darat.")
		transitioned.emit(idle_state)
		return
	if _frozen(_spot):
		_free_meter()
		_spot = null
		Notify.say("Air membeku di musim dingin. Cari tempat memancing yang tidak beku.")
		transitioned.emit(idle_state)
		return
	if not GameState.spend_stamina(_stamina_cost):
		_free_meter()
		Notify.say("Terlalu lelah! Istirahatlah.")
		transitioned.emit(idle_state)
		return

	Juice.play(&"swish", player.global_position)
	if _perfect:
		Juice.float_text("Sempurna!", player.global_position + Vector2(0, -22), Color(0.49, 0.77, 0.2), 0.5)
	_meter.launch(player.global_position + Vector2(0, -10))

	#DEBUG FISHING
	_wait_target = 0.1 if OS.has_feature("editor") and FishingManager.debug_instant_bite else randf_range(WAIT_MIN, WAIT_MAX)
	#_wait_target = randf_range(WAIT_MIN, WAIT_MAX) <--- code asli
	_wait_target *= _rod.bite_time_mult * (PERFECT_BITE_MULT if _perfect else 1.0)
	_bait = _use_bait()
	if _bait != null:
		_wait_target *= 1.0 - _bait.bait_bonus

	_set_phase(Phase.CAST, ANIM_CAST)
	animation_controller.restart()

## Icebreaker Fisherman (Fisher Lv10 B) bisa memancing di air beku.
func _frozen(spot: FishingSpot) -> bool:
	return spot.is_frozen() and not SkillSystem.has(player.data, &"ice_fishing")

## Pakai satu umpan termurah dari tas (item umpan hasil crafting, bait_bonus > 0).
## Serangga dan cacing mentah bukan umpan; keduanya bahan resep umpan (GDD 7.2).
func _use_bait() -> ItemData:
	var best: ItemData = null
	for i in player.data.bag_size:
		var slot = player.data.inventory[i]
		if slot == null:
			continue
		var item: ItemData = slot["item"]
		if item.bait_bonus <= 0.0:
			continue
		if best == null or item.sell_price < best.sell_price:
			best = item
	if best == null or not player.data.remove_item(best.item_id, 1):
		return null
	Juice.float_text("Umpan: %s" % best.display_name, player.global_position + Vector2(0, -30), Color(0.85, 0.95, 0.6), 0.8)
	return best

func _free_meter() -> void:
	if is_instance_valid(_meter):
		_meter.queue_free()
	_meter = null

func _set_phase(phase: Phase, anim: StringName) -> void:
	_phase = phase
	_timer = 0.0
	_anim_done = false
	animation_controller.play(anim)

func _bite_window() -> float:
	return lerpf(1.4, 0.7, _hooked.get_difficulty())
	
func _on_anim_finished() -> void:
	_anim_done = true

func _start_minigame() -> void:
	_set_phase(Phase.REEL, ANIM_REEL)
	_minigame = FishingMinigame.new()
	_minigame.setup(_hooked.get_difficulty(), 0.0, int(_hooked.item.rarity) >= LEGENDARY_TIER)
	_minigame.apply_rod(_rod)
	_minigame.follow_target = player
	_minigame.finished.connect(_on_minigame_finished)
	# Ikut berhenti saat game di-pause (co-op: layar pemain tidak ikut pause).
	_minigame.process_mode = Node.PROCESS_MODE_PAUSABLE
	Coop.ui_parent(player).add_child(_minigame)

func _on_minigame_finished(success: bool) -> void:
	_minigame = null
	player.bind_context()
	
	if success and FishingManager.register_catch(_hooked):
		var tier_name: String = FishTiers.get_tier(int(_hooked.item.rarity))["name"]
		Notify.say("Dapat %s! (%s)" % [_hooked.item.display_name, tier_name])
		_catch_feedback()
		var fish_exp := SkillSystem.RULES.fish_exp
		SkillSystem.gain(player.data, &"fisher", fish_exp[clampi(int(_hooked.item.rarity), 0, fish_exp.size() - 1)])
		_try_double_catch()
		_end(true)
	else:
		_end(false, "" if success else "Ikan lolos...")
		
func _catch_feedback() -> void:
	Juice.play(&"catch", _bobber_pos)
	var item_id: String = _hooked.item.item_id
	Juice.fly_to_hotbar(_hooked.item.icon, _bobber_pos, item_id)
	if int(_hooked.item.rarity) >= RARE_TIER:
		Juice.play(&"sparkle", _bobber_pos + Vector2(0, -12))
	if FishingManager._last_catch_new:
		Juice.float_text("BARU!", player.global_position + Vector2(0, -20), Color(1.0, 0.85, 0.3), 1.0)


func _try_double_catch() -> void:
	if randf() >= _rod.double_catch_chance:
		return
	if FishingManager.register_catch(_hooked):
		Juice.fly_to_hotbar(_hooked.item.icon, _bobber_pos + Vector2(4, 0), _hooked.item.item_id)
		Juice.float_text("x2!", player.global_position + Vector2(0, -30), Color(1.0, 0.85, 0.3), 0.8)
		Notify.say("Beruntung! Dapat 2 %s." % _hooked.item.display_name)

func _end(success: bool, message: String = "") -> void:
	if not success:
		Juice.play(&"escape", _bobber_pos)
	if message != "":
		Notify.say(message)
	_set_phase(Phase.END, ANIM_CATCH if success else ANIM_MISS)
