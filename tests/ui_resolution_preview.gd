extends Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_environment("NUSA_SAVE_AUDIT") != "1":
		get_tree().quit(2)
		return
	await get_tree().process_frame
	GameState.new_game()
	var farm: Node = load("res://scenes/world/farm.tscn").instantiate()
	get_tree().root.add_child(farm)
	get_tree().current_scene = farm
	await get_tree().process_frame
	var inventory: Node = farm.find_child("UiInventory", true, false)
	if inventory == null:
		for node in farm.find_children("*", "CanvasLayer", true, false):
			if node.has_method("refresh_inventory"):
				inventory = node
				break
	if inventory == null:
		push_error("Inventory not found")
		get_tree().quit(1)
		return
	inventory.call("_open")
	for resolution in [Vector2i(960, 540), Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1920, 1080)]:
		get_window().size = resolution
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var shot := get_viewport().get_texture().get_image()
		var path := "res://scratch/ui-%dx%d.png" % [resolution.x, resolution.y]
		var result := shot.save_png(path)
		print("UI PREVIEW: %s actual=%s error=%d" % [path, shot.get_size(), result])
	inventory.call("_close")
	get_tree().current_scene = self
	farm.queue_free()
	await get_tree().process_frame
	get_tree().quit()
