extends Node2D

const PROJECT_ID := "greenhouse_restoration"
## Posisi node `spawn` di scenes/world/interior/greenhouse.tscn (depan pintu dalam).
const INTERIOR_SPAWN := Vector2(416, 364)

## Potongan Greenhouse.png: rangka kosong berpintu bata (terbengkalai) dan versi rimbun bertanaman.
@export var locked_region := Rect2(335, 103, 60, 81)
@export var restored_region := Rect2(95, 7, 60, 81)
@export var locked_modulate := Color(0.78, 0.76, 0.7)

func _ready() -> void:
	GameState.balai_nadi.state_changed.connect(_refresh)
	UnlockManager.unlock_changed.connect(func(id: String, _unlocked: bool):
		if id == "greenhouse":
			_refresh())
	_refresh()

func _refresh() -> void:
	var restored := UnlockManager.is_unlocked("greenhouse")
	$Sprite2D.region_rect = restored_region if restored else locked_region
	$Sprite2D.modulate = Color.WHITE if restored else locked_modulate
	$Sprite2D2.visible = restored
	$Damage.visible = not restored

func interact() -> void:
	if not UnlockManager.is_unlocked("greenhouse"):
		Notify.say("Greenhouse terkunci. Selesaikan permintaan Kebun Sepanjang Musim di Sayap Alam Balai Nadi.")
		return
	var player: Player = Coop.current_player()
	if player == null:
		for candidate in get_tree().get_nodes_in_group("player"):
			if candidate is Player and candidate.data == GameState.current:
				player = candidate
				break
	if player == null or player.is_input_locked() or Transition.on_transition:
		return
	GameState.next_spawn_position = INTERIOR_SPAWN
	GameState.has_spawn_point = true
	Transition.scene_transition.call_deferred("res://scenes/world/interior/greenhouse.tscn", player)
