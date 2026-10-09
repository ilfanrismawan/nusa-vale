class_name FishingState
extends State

enum Phase {CAST, WAIT, BITE, REEL, END}

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

@export var idle_state: State

var _spot: FishingSpot
var _hooked: FishData
var _minigame: FishingMinigame
var _phase := Phase.CAST
var _timer := 0.0
var _wait_target := 0.0
var _anim_done := false

func _init() -> void:
	animation_name = ANIM_CAST

func initialize(_player: Player, _animation_controller: AnimationController) -> void:
	super.initialize(_player, _animation_controller)
	animation_controller.animated_finished.connect(_on_anim_finished)
					
func start(spot: FishingSpot) -> void:
	_spot = spot

func enter() -> void:
	super.enter()
	player.velocity = Vector2.ZERO
	_phase = Phase.CAST
	_timer = 0.0
	_anim_done = false
	_hooked = null
	
	#DEBUG FISHING	
	_wait_target = 0.1 if FishingManager.debug_instant_bite else randf_range(WAIT_MIN, WAIT_MAX)
	#_wait_target = randf_range(WAIT_MIN, WAIT_MAX) <--- code asli

func exit() -> void:
	if is_instance_valid(_minigame):
		_minigame.queue_free()
	_minigame = null
	_hooked = null
	_spot = null

func physics_update(_delta: float) -> void:
	player.velocity = Vector2.ZERO
	_timer += _delta
	
	match _phase:
		Phase.CAST:
				if _anim_done or _timer >= CAST_MAX_TIME:
					_set_phase(Phase.WAIT, ANIM_WAIT)
		
		Phase.WAIT:
			if Input.is_action_just_pressed("use_tool"):
				_end(false, "Terlalu cepat.. ikan kabur.")
			elif _timer >= _wait_target:
				_hooked = FishingManager.roll_catch(_spot.location_id)
				if _hooked == null:
					_end(false, "Tidak ada ikan yang menggigit saat ini.")
					return
				_set_phase(Phase.BITE, ANIM_HOOKED)
				Notify.say("! Ikan menggigit! Klik sekarang!")
				
		Phase.BITE:
			if Input.is_action_just_pressed("use_tool"):
				_start_minigame()
			elif _timer >= BITE_WINDOW:
				_end(false, "Ikan kabur...")
				
		Phase.REEL:
			pass
			
		Phase.END:
			if _anim_done or _timer >= END_MAX_TIME:
				transitioned.emit(idle_state)

func _set_phase(phase: Phase, anim: StringName) -> void:
	_phase = phase
	_timer = 0.0
	_anim_done = false
	animation_controller.play(anim)

func _on_anim_finished() -> void:
	_anim_done = true

func _start_minigame() -> void:
	_set_phase(Phase.REEL, ANIM_REEL)
	_minigame = FishingMinigame.new()
	_minigame.setup(_hooked.difficulty)
	_minigame.finished.connect(_on_minigame_finished)
	get_tree().current_scene.add_child(_minigame)

func _on_minigame_finished(success: bool) -> void:
	_minigame = null
	if success and FishingManager.register_catch(_hooked):
		Notify.say("Dapat %s!" % _hooked.item.display_name)
		_end(true)
	else:
		_end(false, "" if success else "Ikan lolos...")
		
func _end(success: bool, message: String = "") -> void:
	if message != "":
		Notify.say(message)
	_set_phase(Phase.END, ANIM_CATCH if success else ANIM_MISS)
