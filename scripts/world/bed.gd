class_name Bed
extends Area2D

## Kasur. Solo: tekan Enter untuk tidur, hari berganti.
## Co-op: setiap pemain berbaring di sini (tekan lagi untuk bangun); hari baru dimulai
## setelah semua pemain berbaring.

var _players: Array[Player] = []
var _sleeping := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body is Player and not _players.has(body):
		_players.append(body)

func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		_players.erase(body)
		
func _unhandled_input(event: InputEvent) -> void:
	if _sleeping:
		return
	if Coop.has_root():
		_coop_input(event)
		return
	if not _players.is_empty() and event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_sleep()

func _coop_input(event: InputEvent) -> void:
	for p in _players:
		if not is_instance_valid(p) or not p.input.is_event(event, &"ui_accept"):
			continue
		get_viewport().set_input_as_handled()
		var lying := not Coop.is_sleeping(p)
		var count := Coop.set_sleeping(p, lying)
		var total := Coop.player_count()
		if count >= total:
			Coop.clear_sleeping()
			_sleep()
		elif lying:
			Notify.say("P%d berbaring (%d/%d). Menunggu pemain lain di kasur..." % [p.player_index + 1, count, total])
		else:
			Notify.say("P%d bangun lagi (%d/%d)." % [p.player_index + 1, count, total])
		return

func _sleep() -> void:
	_sleeping = true
	var layer := CanvasLayer.new()
	layer.layer = 50
	var fade := ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	layer.add_child(fade)
	# Co-op: tirai menutupi semua layar sekaligus.
	var parent: Node = Coop.root if Coop.has_root() else get_tree().current_scene
	parent.add_child(layer)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.6)
	tw.tween_callback(_new_day)
	tw.tween_interval(0.5)
	tw.tween_property(fade, "color:a", 0.0, 0.6)
	tw.tween_callback(_end_sleep.bind(layer))

func _new_day() -> void:
	if Coop.has_root():
		for i in Coop.player_count():
			GameState.get_player(i).restore_stamina()
	else:
		GameState.restore_stamina()
	DayCycle.advance_day()
	SaveManager.save_game()
	Notify.say("Hari %d dimulai (Energi Pulih)" % DayCycle.current_day)
	
func _end_sleep(layer: CanvasLayer) -> void:
	layer.queue_free()
	_sleeping = false
