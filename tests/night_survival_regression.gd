extends Node

var failures := 0
func check(value: bool, label: String) -> void:
	if value:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func dismiss_shipping_report() -> void:
	for dialog in GameState.shipping.get_children():
		if dialog is AcceptDialog:
			dialog.confirmed.emit()

func _ready() -> void:
	if OS.get_environment("NUSA_SAVE_AUDIT") != "1" or not OS.get_user_data_dir().replace("\\", "/").contains("nusa-save-audit-"):
		get_tree().quit(2)
		return
	get_tree().current_scene = null
	await get_tree().process_frame
	GameState.new_game()
	DayCycle.is_running = false
	DayCycle.hour = 23
	DayCycle.minute = 50
	var day := DayCycle.current_day
	DayCycle.advance_minute(10)
	check(DayCycle.hour == 0 and DayCycle.minute == 0 and DayCycle.current_day == day, "midnight keeps the same farming day")
	DayCycle.hour = 1
	DayCycle.minute = 50
	DayCycle.advance_minute(10)
	check(DayCycle.hour == 2 and not DayCycle._is_passing_out, "02.00 no longer ends exploration")
	DayCycle.hour = 4
	DayCycle.minute = 50
	DayCycle.advance_minute(10)
	check(DayCycle.hour == 5 and not DayCycle._is_passing_out, "05.00 is still safe")
	DayCycle.is_sleep_transition = true
	DayCycle.advance_minute(60)
	check(DayCycle.hour == 5 and DayCycle.minute == 0, "sleep fade stops time at deadline")
	DayCycle.is_sleep_transition = false
	var devices: Array[int] = [PlayerInput.DEVICE_KEYBOARD, PlayerInput.DEVICE_NUMPAD]
	Coop.start(devices)
	await get_tree().create_timer(1.0).timeout
	DayCycle.is_running = false
	DayCycle.hour = 0
	DayCycle.minute = 0
	var p1: Player = Coop.root.body_of(0)
	var p2: Player = Coop.root.body_of(1)
	var night1 = p1.hud_ui.get_node("NightHorror")
	var night2 = p2.hud_ui.get_node("NightHorror")
	check(night1.outdoor_intensity() >= 0.7, "midnight outdoor atmosphere active")
	Coop.root.move_player(p2, "res://scenes/world/interior/interior_house.tscn", Vector2(317, 151))
	await get_tree().create_timer(0.8).timeout
	check(night2.outdoor_intensity() == 0.0 and night1.outdoor_intensity() >= 0.7, "interior safety is independent per co-op viewport")
	Coop.set_sleeping(p2, true)
	DayCycle.hour = 4
	DayCycle.minute = 50
	DayCycle.advance_minute(120)
	check(DayCycle.hour == 5 and DayCycle.minute == 10 and DayCycle._is_passing_out, "large time skip stops at 05.10")
	check(p1.is_input_locked(), "pass-out locks player input")
	var wait_until := Time.get_ticks_msec() + 15000
	while DayCycle._is_passing_out and Time.get_ticks_msec() < wait_until:
		dismiss_shipping_report()
		await get_tree().process_frame
	check(DayCycle.current_day == day + 1 and DayCycle.hour == 8, "pass-out advances exactly one day and wakes at 08.00")
	check(p1.data.stamina == int(p1.data.max_stamina * 0.5), "awake player receives 50 percent energy")
	check(p2.data.stamina == p2.data.max_stamina, "already sleeping teammate receives full energy")
	check(not DayCycle._is_passing_out and not p1.is_input_locked(), "fade finishes and restores input")
	check(p1.world_root() == p2.world_root() and "/interior/" in p1.world_root().scene_file_path, "both players return home")
	DayCycle.hour = 12
	check(DayCycle.night_intensity() == 0.0, "daytime removes horror")
	var old_root: Node = Coop.root
	Coop.stop()
	old_root.queue_free()
	await get_tree().process_frame
	# Check the solo scene replacement as well as normal bedtime.
	get_tree().change_scene_to_file("res://scenes/world/interior/interior_house.tscn")
	await get_tree().process_frame
	await get_tree().process_frame
	DayCycle.is_running = false
	DayCycle.hour = 5
	DayCycle.minute = 0
	var solo_day := DayCycle.current_day
	var house := get_tree().current_scene
	var bed := house.get_node("Kasur") as Bed
	dismiss_shipping_report()
	bed._sleep()
	check(DayCycle.is_sleep_transition, "normal bedtime locks the clock immediately")
	wait_until = Time.get_ticks_msec() + 15000
	while DayCycle.is_sleep_transition and Time.get_ticks_msec() < wait_until:
		dismiss_shipping_report()
		await get_tree().process_frame
	check(DayCycle.current_day == solo_day + 1 and DayCycle.hour == 6 and GameState.p1().stamina == GameState.p1().max_stamina, "solo sleep at 05.00 wakes at 06.00 with full energy")
	DayCycle.hour = 5
	DayCycle.minute = 0
	DayCycle.advance_minute(10)
	wait_until = Time.get_ticks_msec() + 15000
	while DayCycle._is_passing_out and Time.get_ticks_msec() < wait_until:
		dismiss_shipping_report()
		await get_tree().process_frame
	var solo_player := get_tree().current_scene.get_node("Player/CharacterBody2D") as Player
	check(DayCycle.hour == 8 and GameState.p1().stamina == int(GameState.p1().max_stamina * 0.5), "solo pass-out retains the energy penalty across scene replacement")
	check(not solo_player.is_input_locked(), "solo replacement player can move after fade")
	print("NIGHT SURVIVAL REGRESSION COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
