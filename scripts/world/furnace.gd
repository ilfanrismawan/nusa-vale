class_name Furnace
extends Node2D

@export var recipes: Array[FurnaceRecipe] = []
@export var recipe: FurnaceRecipe

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var area_2d: Area2D = get_node_or_null("Area2D")
@onready var point_light: PointLight2D = get_node_or_null("PointLight2D")
@onready var particles: GPUParticles2D = get_node_or_null("GPUParticles2D")
@onready var audio_stream: AudioStreamPlayer2D = get_node_or_null("AudioStreamPlayer2D")

var is_processing := false
var current_recipe: FurnaceRecipe = null
var timer := 0.0

var _player_in_range := false
var _player: Player = null

func _ready() -> void:
	if area_2d != null:
		area_2d.body_entered.connect(_on_body_entered)
		area_2d.body_exited.connect(_on_body_exited)

	_load_recipes()
	_update_visuals()

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		_player_in_range = true
		_player = body

func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		_player_in_range = false
		_player = null

func _unhandled_input(event: InputEvent) -> void:
	if _player_in_range and not is_processing and (event.is_action_pressed("interact") or event.is_action_pressed("ui_accept")):
		get_viewport().set_input_as_handled()
		interact()

func _load_recipes() -> void:
	if recipe != null and not recipes.has(recipe):
		recipes.append(recipe)

	if recipes.is_empty():
		var furnace_dir := "res://resources/furnace/"
		var dir := DirAccess.open(furnace_dir)
		if dir != null:
			dir.list_dir_begin()
			var file_name := dir.get_next()
			while file_name != "":
				if not dir.current_is_dir() and (file_name.ends_with(".tres") or file_name.ends_with(".res")):
					var res := load(furnace_dir + file_name)
					if res is FurnaceRecipe and not recipes.has(res):
						recipes.append(res)
				file_name = dir.get_next()

func interact() -> void:
	if is_processing:
		return

	start_furnace()

func start_furnace() -> void:
	if recipes.is_empty():
		_load_recipes()

	if recipes.is_empty():
		push_warning("Furnace recipe belum dikonfigurasi.")
		Notify.say("Resep Furnace tidak ditemukan.")
		return

	var selected_recipe: FurnaceRecipe = null

	# 1. Cek apakah pemain sedang memegang ore di hotbar
	if _player != null and _player.tool_controller != null:
		var held_item: ItemData = _player.tool_controller.current_item
		if held_item != null:
			for r in recipes:
				if r.input_item_id == held_item.item_id:
					selected_recipe = r
					break

	# 2. Jika tidak memegang ore yang cocok, cari ore apa pun di inventory yang cukup jumlahnya
	if selected_recipe == null:
		for r in recipes:
			if GameState.has_item(r.input_item_id, r.input_amount):
				selected_recipe = r
				break

	# 3. Jika belum ketemu, cek apakah ada ore tapi jumlahnya belum cukup
	if selected_recipe == null:
		for r in recipes:
			var count: int = GameState.get_item_count(r.input_item_id)
			if count > 0:
				var in_item := GameState._resolve_item(r.input_item_id)
				var in_name: String = in_item.display_name if in_item != null else r.input_item_id
				Notify.say("Butuh %d %s untuk melebur (punya %d)." % [r.input_amount, in_name, count])
				return

		Notify.say("Pilih atau bawa bijih tambang (ore) untuk dilebur.")
		return

	# 4. Validasi jumlah item
	if not GameState.has_item(selected_recipe.input_item_id, selected_recipe.input_amount):
		var in_item := GameState._resolve_item(selected_recipe.input_item_id)
		var in_name: String = in_item.display_name if in_item != null else selected_recipe.input_item_id
		Notify.say("Butuh %d %s untuk melebur." % [selected_recipe.input_amount, in_name])
		return

	# 5. Kurangi item dan mulai proses pembakaran
	GameState.remove_item(selected_recipe.input_item_id, selected_recipe.input_amount)
	current_recipe = selected_recipe
	is_processing = true
	timer = selected_recipe.process_time

	var item_data := GameState._resolve_item(selected_recipe.input_item_id)
	var display_name: String = item_data.display_name if item_data != null else selected_recipe.input_item_id
	Notify.say("Mulai melebur %s..." % display_name)
	_update_visuals()

func _process(delta: float) -> void:
	if not is_processing:
		return

	timer -= delta
	if timer <= 0.0:
		finish_furnace()

func finish_furnace() -> void:
	is_processing = false
	_update_visuals()

	if current_recipe == null:
		return

	var out_item := GameState._resolve_item(current_recipe.output_item_id)
	var out_name: String = out_item.display_name if out_item != null else current_recipe.output_item_id

	# Selalu drop item ke sekitar kaki furnace
	var parent := get_parent() if get_parent() != null else get_tree().current_scene
	var origin := global_position + Vector2(0, 16) # Drop di sekitar kaki (bawah) furnace
	for i in current_recipe.output_amount:
		var angle := randf() * TAU
		var radius := randf_range(4.0, 16.0)
		var offset := Vector2(cos(angle), sin(angle)) * radius
		ItemPickup.spawn(parent, origin + offset, current_recipe.output_item_id, 1)

	Notify.say("Peleburan selesai! %s x%d siap diambil." % [out_name, current_recipe.output_amount])

	current_recipe = null

func _update_visuals() -> void:
	if animated_sprite == null:
		return

	if is_processing:
		animated_sprite.play("working")
		if point_light != null:
			point_light.enabled = true
		if particles != null:
			particles.emitting = true
	else:
		animated_sprite.play("idle")
		if point_light != null:
			point_light.enabled = false
		if particles != null:
			particles.emitting = false
