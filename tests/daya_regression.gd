extends Node
var failures := 0
func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_environment("NUSA_SAVE_AUDIT") != "1" or not OS.get_user_data_dir().replace("\\", "/").contains("nusa-save-audit-"):
		push_error("Daya tests require isolated nusa-save-audit-* APPDATA and NUSA_SAVE_AUDIT=1.")
		get_tree().quit(2)
		return
	await get_tree().process_frame
	await run()
func run() -> void:
	GameState.new_game()
	var p := GameState.p1()
	var m := GameState.daya
	m._harvest(Vector2i.ZERO, "carrot", 1)
	m._harvest(Vector2i.ZERO, "carrot", 20)
	check(not m.obtained.has("harvest"), "different crops required")
	m._harvest(Vector2i.ZERO, "strawberry", 1)
	check(p.get_item_count("biji_daya_harvest") == 1, "early farming reward")
	m.unlock("harvest", p)
	check(p.get_item_count("biji_daya_harvest") == 1, "reward cannot repeat")
	var slot := -1
	for i in p.bag_size:
		if p.inventory[i] != null and p.inventory[i].item.item_id == "biji_daya_harvest":
			slot = i
	p.stamina = 40
	check(SaveManager.save_game(), "seed saved before failure test")
	DirAccess.make_dir_absolute(SaveManager.BACKUP_PATH + ".tmp")
	check(not m.consume(p, slot, "harvest"), "failed save rejects consumption")
	check(p.max_stamina == 100 and p.stamina == 40 and p.get_item_count("biji_daya_harvest") == 1 and not m.consumed.has("harvest"), "failed save restores seed, capacity and stamina")
	DirAccess.remove_absolute(SaveManager.BACKUP_PATH + ".tmp")
	check(m.consume(p, slot, "harvest"), "consume seed")
	check(p.max_stamina == 110 and p.stamina == 50, "permanent capacity and exactly ten recovery")
	check(not m.consume(p, slot, "harvest"), "cannot consume twice")
	check(SaveManager.save_game() and SaveManager.load_game(), "disk save roundtrip")
	var ui := load("res://scenes/ui/ui_inventory.tscn") as PackedScene
	var inventory_ui := ui.instantiate()
	add_child(inventory_ui)
	check(inventory_ui._consume_button != null, "inventory consumption UI builds")
	inventory_ui.queue_free()
	var shrine := Area2D.new()
	shrine.set_script(load("res://scripts/world/daya_shrine.gd"))
	add_child(shrine)
	check(shrine.collision_layer != 0, "shrine is discoverable by interaction query")
	shrine.queue_free()
	var snapshot := SaveManager._build_save_data()
	GameState.new_game()
	SaveManager._apply_save(snapshot)
	check(p.max_stamina == 110 and p.stamina == 50 and m.obtained.has("harvest"), "save roundtrip preserves IDs and stamina")
	p.restore_stamina()
	check(p.stamina == 110, "sleep fully restores upgraded capacity")
	p.bag_level = 0
	for i in p.bag_size:
		p.inventory[i] = {"item": GameState._resolve_item("wood"), "count": 99}
	m.unlock("forest", p)
	check(m.pending.has("forest") and not m.obtained.has("forest"), "full bag defers unique reward")
	p.inventory[0] = null
	m.deliver()
	check(p.get_item_count("biji_daya_forest") == 1 and not m.pending.has("forest"), "deferred reward delivered once")
	check(m.consume(p, 0, "forest"), "forest seed consumption")
	p.inventory[0] = null
	m._restored("balai_nadi_restoration")
	check(m.consume(p, 0, "balai"), "first facility seed consumption")
	check(p.max_stamina == 130, "MVP capacity cap")
	var p2 := GameState.ensure_player(1)
	p2.inventory[0] = {"item": GameState._resolve_item("biji_daya_forest"), "count": 1}
	check(not m.consume(p2, 0, "forest") and p2.max_stamina == 100, "world consumed ID rejects duplicated co-op item")
	var facility := GameState.balai_nadi
	GameState.new_game()
	p2 = GameState.ensure_player(1)
	for id in facility.definition("balai_nadi_restoration").requirements:
		if id == "money":
			GameState.money = 10000
		else:
			p2.add_item(id, facility.definition("balai_nadi_restoration").requirements[id])
	for id in facility.definition("balai_nadi_restoration").requirements:
		facility.contribute(p2, "balai_nadi_restoration", id)
	check(m.obtained.has("balai") or m.pending.has("balai"), "facility stages unique seed")
	check(SaveManager.load_game(), "facility completion reload")
	check(m.pending.get("balai", -1) == 1, "completion snapshot preserves co-op recipient")
	m.deliver()
	check(p2.get_item_count("biji_daya_balai") == 1 and p.get_item_count("biji_daya_balai") == 0, "facility seed belongs to actual donor after reload")
	# Verify actual forest placement, physics query and confirmation flow.
	GameState.new_game()
	for notice in Notify._box.get_children():
		notice.queue_free()
	await get_tree().process_frame
	var forest := load("res://scenes/world/Forest.tscn").instantiate() as Node2D
	add_child(forest)
	await get_tree().physics_frame
	var actor := forest.get_node("Player/CharacterBody2D") as Player
	actor.global_position = Vector2(672, 480) - actor.FEET_OFFSET - Vector2.UP * actor.INTERACTION_DISTANCE
	actor.facing_direction = Vector2.UP
	await get_tree().physics_frame
	var actual_shrine := actor._find_interactable()
	check(actual_shrine != null and actual_shrine.get_script() == load("res://scripts/world/daya_shrine.gd"), "forest physics query reaches placed shrine")
	WorldState.set_flag("bridge_repaired", false)
	if actual_shrine != null:
		actual_shrine.interact(actor)
	check(not m.obtained.has("forest"), "shrine remains gated before bridge repair")
	WorldState.set_flag("bridge_repaired", true)
	if actual_shrine != null:
		actual_shrine.interact(actor)
	check(p.get_item_count("biji_daya_forest") == 1, "exploration interaction awards seed")
	var bag = actor.ui_inventory
	bag._open()
	for i in p.bag_size:
		if p.inventory[i] != null and p.inventory[i].item.item_id == "biji_daya_forest":
			bag._select_slot(i)
	bag.refresh_inventory()
	check(bag._consume_button.visible and not bag._btn_drop.visible, "unique seed exposes consume instead of discard")
	bag._consume_button.pressed.emit()
	check(bag._consume_dialog.visible and p.max_stamina == 100, "confirmation does not consume early")
	await capture("daya-confirmation.png")
	bag._consume_dialog.hide()
	check(p.get_item_count("biji_daya_forest") == 1, "cancelling preserves seed")
	bag._consume_button.pressed.emit()
	bag._consume_dialog.confirmed.emit()
	check(p.max_stamina == 110 and not bag.visible and actor.is_input_locked(), "confirmed consumption closes inventory and locks during effect")
	await get_tree().create_timer(0.3).timeout
	await capture("daya-consumption.png")
	await get_tree().create_timer(0.9).timeout
	check(not actor.is_input_locked(), "consumption animation releases controls")
	check(actor.hud_ui.stamina_bar.max_value == 110 and actor.hud_ui.stamina_bar.scale.y > 3.0, "HUD shows permanent capacity increase")
	forest.queue_free()
	await get_tree().process_frame
	var legacy := snapshot.duplicate(true)
	legacy.player.erase("consumed_daya")
	legacy.erase("daya")
	SaveManager._apply_save(legacy)
	check(p.max_stamina == 100, "legacy save defaults to base capacity")
	print("DAYA REGRESSION COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)

func capture(filename: String) -> void:
	if OS.get_cmdline_user_args().has("--capture-daya"):
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://scratch/" + filename)
