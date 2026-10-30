extends Node2D
var failures := 0

func check(ok: bool, label: String) -> void:
	if ok: print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func record(uid: int, item: String) -> Dictionary:
	return {"uid": uid, "item": item, "cell": [uid * 4, 0], "storage": [], "open": false, "job": {}, "ready": {}}

func _ready() -> void:
	if OS.get_environment("NUSA_SAVE_AUDIT") != "1":
		get_tree().quit(2)
		return
	await get_tree().process_frame
	GameState.new_game()
	var data := GameState.p1()
	data.bag_level = 2
	data.inventory.fill(null)
	DayCycle.is_running = true
	for recipe in StructureManager.furnace_recipes():
		StructureManager.records.assign([record(1, "furnace")])
		data.add_item_silent(recipe.input_item_id, recipe.input_amount)
		check(StructureManager.smelt(data, 1, recipe).ok, "furnace accepts " + recipe.recipe_id)
		var machine := StructureManager.record_for(1)
		StructureManager._process(recipe.process_time - 0.01)
		check(not machine.job.is_empty() and machine.ready.is_empty(), "furnace does not finish early: " + recipe.recipe_id)
		StructureManager._process(0.02)
		check(machine.job.is_empty() and machine.ready.get("id") == recipe.output_item_id, "furnace duration %.1fs: %s" % [recipe.process_time, recipe.recipe_id])
		var before := data.get_item_count(recipe.output_item_id)
		StructureManager.collect(data, 1)
		check(data.get_item_count(recipe.output_item_id) == before + recipe.output_amount and not StructureManager.collect(data, 1).ok, "furnace output collected exactly once")
	for machine_id in ["preserves_jar", "dehydrator"]:
		var recipes: Array = StructureManager.preserves_jar_recipes() if machine_id == "preserves_jar" else StructureManager.dehydrator_recipes()
		for recipe in recipes:
			StructureManager.records.assign([record(1, machine_id)])
			data.add_item_silent(recipe.input_item_id, recipe.input_amount)
			var result: Dictionary = StructureManager.preserve(data, 1, recipe) if machine_id == "preserves_jar" else StructureManager.dehydrate(data, 1, recipe)
			check(result.ok, "processing starts: " + recipe.recipe_id)
			StructureManager._process(recipe.process_time)
			check(StructureManager.record_for(1).ready.get("id") == recipe.output_item_id, "processing duration %.1fs: %s" % [recipe.process_time, recipe.recipe_id])
	for machine_id in StructureManager.ARTISANS:
		StructureManager.records.assign([record(1, machine_id)])
		# Fish Smoker menerima ikan apa pun; kunci tabelnya adalah hasil, bukan bahan.
		var input: String = "fish_carp" if machine_id == "fish_smoker" else StructureManager.ARTISANS[machine_id].keys()[0]
		data.add_item_silent(input, 1)
		data.add_item_silent("wood", StructureManager.SMOKER_WOOD)
		check(StructureManager.process_animal_product(data, 1, input).ok, "artisan begins: " + machine_id)
		var machine := StructureManager.record_for(1)
		StructureManager._process(5)
		DayCycle.is_running = false
		StructureManager._process(100)
		if machine_id in StructureManager.DAY_MACHINES:
			check(int(machine.job.get("day", 0)) > DayCycle.current_day and not machine.job.has("seconds"), "%s works by game day, not active seconds" % machine_id)
		else:
			check(is_equal_approx(float(machine.job.seconds), 15), "stopped day cycle cannot advance artisan")
		DayCycle.is_running = true
		var holder := Node2D.new()
		holder.set_meta("world", weakref(self))
		add_child(holder)
		var visual = load("res://scenes/objects/placed_structure.tscn").instantiate()
		visual.uid = 1
		holder.add_child(visual)
		visual.set_process(false)
		visual._process(0.1)
		check(visual._particles.emitting and visual._audio_loop.playing and visual._audio_loop.stream.loop_end > 0, "running particles and looping SFX: " + machine_id)
		DayCycle.is_running = false
		visual._process(0.1)
		check(not visual._particles.emitting and not visual._audio_loop.playing, "pause stops machine feedback: " + machine_id)
		DayCycle.is_running = true
		visual._process(0.1)
		check(visual._audio_loop.playing and visual._particles.emitting, "resume restores machine feedback: " + machine_id)
		StructureManager._process(15)
		if machine_id in StructureManager.DAY_MACHINES:
			var keg_saved := StructureManager.to_save()
			StructureManager.load_save(keg_saved)
			machine = StructureManager.record_for(1)
			visual.uid = 1
			check(int(machine.job.get("day", 0)) > DayCycle.current_day, "%s job day survives save/load" % machine_id)
			StructureManager._advance_day_jobs(int(machine.job.day))
		visual._process(0.1)
		check(not visual._particles.emitting and not visual._audio_loop.playing and not machine.ready.is_empty(), "completion stops running feedback: " + machine_id)
		holder.queue_free()
	StructureManager.records.assign([record(8, "furnace")])
	var copper := StructureManager.furnace_recipes()[0]
	data.add_item_silent(copper.input_item_id, copper.input_amount)
	StructureManager.smelt(data, 8, copper)
	StructureManager._process(1)
	var remaining: float = StructureManager.record_for(8).job.seconds
	check(SaveManager.save_game() and SaveManager.load_game() and is_equal_approx(float(StructureManager.record_for(8).job.seconds), remaining), "remaining machine duration survives disk save/load")
	var saved := StructureManager.to_save()
	saved[0].ready = {"id": copper.output_item_id, "count": copper.output_amount}
	StructureManager.load_save(saved)
	check(StructureManager.record_for(8).job.is_empty() and not StructureManager.record_for(8).ready.is_empty(), "ready product wins over stale simultaneous job")
	var placement := Juice.get_feedback(&"building_place")
	check(placement.particle_count > 0 and placement.sound != null, "placement effect has dust/glints and construction SFX")
	StructureManager.reset()
	DayCycle.is_running = false
	await get_tree().create_timer(1, true).timeout
	for voice in Juice._voices:
		voice.stop()
		voice.stream = null
	await get_tree().create_timer(1.0, true).timeout
	print("PRODUCTION AUDIT COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
