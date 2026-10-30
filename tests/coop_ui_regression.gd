extends Node

## Tes UI co-op: HUD, hotbar, dan tas tampil seukuran main sendiri (kanvas logis = ukuran
## layar), Skala UI per pemain (Setelan > Layar) hanya mengubah layar pemain itu tanpa
## mengubah besar dunia, dan P2-P4 hanya melihat setelan pribadi. Tidak menulis slot save.

var failures := 0

func check(value: bool, label: String) -> void:
	if value:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout

func _process(_delta: float) -> void:
	if PauseManager.background:
		PauseManager.set_background(false)

## Piksel layar per piksel dunia untuk kamera pemain `index`.
func _world_scale(index: int) -> float:
	var view: SubViewport = Coop.root.view_of(index)
	return Coop.root.camera_of(index).zoom.x * float(view.size.x) / float(view.size_2d_override.x)

func _inside(control: Control, index: int) -> bool:
	var rect := Rect2(Vector2.ZERO, Vector2(Coop.root.view_of(index).size_2d_override))
	var shown := Rect2(control.get_global_position(), control.size * control.get_global_transform().get_scale())
	if not rect.encloses(shown):
		print("LOG_RECT %s %s outside %s" % [control.name, shown, rect])
	return rect.encloses(shown)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_environment("NUSA_SAVE_AUDIT") != "1" or not OS.get_user_data_dir().replace("\\", "/").contains("nusa-save-audit-"):
		get_tree().quit(2)
		return
	Coop.save_on_leave = false
	get_tree().current_scene = null
	await get_tree().process_frame
	for i in 4:
		InputLayout.save_option("coop_ui_scale_p%d" % (i + 1), 1.0)
	for count in [2, 3, 4]:
		GameState.new_game()
		var devices: Array[int] = [PlayerInput.DEVICE_KEYBOARD, PlayerInput.DEVICE_NUMPAD]
		while devices.size() < count:
			devices.append(devices.size() + 10)
		Coop.start(devices)
		await _wait(1.0)
		# Sesi pertama memuat area dalam satu frame panjang (> 1 dtk): beri UI beberapa frame
		# biasa untuk menata ulang di layar pemain sebelum diukur.
		for frame in 3:
			await get_tree().process_frame
		check(Coop.has_root() and Coop.player_count() == count, "co-op %d starts" % count)
		if not Coop.has_root():
			continue
		var effective: float = Coop.root.EFFECTIVE_ZOOM[count]
		for i in count:
			var view: SubViewport = Coop.root.view_of(i)
			var body: Player = Coop.root.body_of(i)
			check(view.size_2d_override == view.size, "%dP P%d: UI canvas equals screen size (solo-sized UI)" % [count, i + 1])
			check(is_equal_approx(_world_scale(i), effective), "%dP P%d: world zoom unchanged (%.2f)" % [count, i + 1, effective])
			check(_inside(body.hotbar_ui.get_node("MarginContainer/HudBg"), i), "%dP P%d: hotbar inside own screen" % [count, i + 1])
			check(_inside(body.hud_ui.stamina_bar, i), "%dP P%d: stamina bar inside own screen" % [count, i + 1])

		# Skala UI P2 1.5x: hanya layar P2 yang berubah, besar dunia tetap.
		Coop.root.set_ui_scale(1, 1.5)
		await _wait(0.3)
		var p2_view: SubViewport = Coop.root.view_of(1)
		check(p2_view.size_2d_override == Vector2i((Vector2(p2_view.size) / 1.5).round()), "%dP: P2 UI scale 150%% shrinks logical canvas" % count)
		check(is_equal_approx(_world_scale(1), effective), "%dP: P2 world zoom unchanged after UI scale" % count)
		check(Coop.root.view_of(0).size_2d_override == Coop.root.view_of(0).size, "%dP: P1 screen unaffected by P2 UI scale" % count)
		check(_inside(Coop.root.body_of(1).hotbar_ui.get_node("MarginContainer/HudBg"), 1), "%dP: P2 hotbar still inside screen at 150%%" % count)
		check(is_equal_approx(_stored_scale(1), 1.5), "%dP: P2 UI scale stored per seat" % count)

		# Tas P2: halaman Setelan hanya menampilkan Skala UI.
		var p2_inv = Coop.root.body_of(1).ui_inventory
		p2_inv.toggle()
		await get_tree().process_frame
		p2_inv._on_gear_pressed()
		await get_tree().process_frame
		var page = p2_inv._settings_panel
		check(page.visible and page.get_node("%UiScale").is_visible_in_tree(), "%dP: P2 opens personal settings with UI scale" % count)
		check(not page.get_node("%Section").visible and not page.get_node("%WindowMode").visible and not page.get_node("%Audio").visible, "%dP: P2 cannot see shared settings" % count)
		check(page.get_node("%UiScale").get_item_text(page.get_node("%UiScale").selected) == "150%", "%dP: P2 option shows current scale" % count)
		var pad := InputEventJoypadButton.new()
		pad.device = Coop.get_input(1).device
		pad.button_index = JOY_BUTTON_A
		pad.pressed = true
		if Coop.get_input(1).is_event(pad, &"ui_accept"):
			check(page.capture_input(pad) and is_equal_approx(Coop.root.ui_scale_of(1), 0.75), "%dP: gamepad A cycles P2 UI scale" % count)
		page.get_node("%UiScale").select(1)
		page._ui_scale(1)
		await _wait(0.2)
		check(is_equal_approx(Coop.root.ui_scale_of(1), 1.0) and p2_view.size_2d_override == p2_view.size, "%dP: P2 UI scale back to 100%% from settings" % count)
		check(is_equal_approx(p2_inv.book_root.scale.x, 1.0) or count > 2, "%dP: inventory book uses whole 1x scale on half screen" % count)
		p2_inv.toggle()

		var p1_inv = Coop.root.body_of(0).ui_inventory
		p1_inv.toggle()
		await get_tree().process_frame
		p1_inv._on_gear_pressed()
		await get_tree().process_frame
		check(p1_inv._settings_panel.get_node("%Section").visible and p1_inv._settings_panel.get_node("%UiScale").visible, "%dP: P1 keeps shared settings plus own UI scale" % count)
		p1_inv.toggle()

		var old_root: Node = Coop.root
		Coop.stop()
		get_tree().current_scene = null
		old_root.queue_free()
		await get_tree().process_frame
	print("COOP UI REGRESSION COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)

func _stored_scale(index: int) -> float:
	return float(InputLayout.load_option("coop_ui_scale_p%d" % (index + 1), -1.0))
