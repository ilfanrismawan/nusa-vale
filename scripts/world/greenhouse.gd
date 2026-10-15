extends Node2D

const PROJECT_ID := "greenhouse_restoration"

func _ready() -> void:
	GameState.balai_nadi.state_changed.connect(_refresh)
	_refresh()

func _refresh() -> void:
	var restored := UnlockManager.is_unlocked("greenhouse")
	$Sprite2D.region_rect = Rect2(95, 103, 60, 81) if restored else Rect2(16, 7, 60, 81)
	#$Sprite2D.modulate = Color.WHITE if restored else Color(0.7, 0.7, 0.63)
	$Sprite2D2.visible = restored

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
	GameState.next_spawn_position = Vector2(427, 312)
	GameState.has_spawn_point = true
	Transition.scene_transition.call_deferred("res://scenes/world/interior/greenhouse.tscn", player)
