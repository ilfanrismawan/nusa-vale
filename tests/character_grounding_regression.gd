extends Node

## Tes karakter menapak tanah: titik badan pemain = kaki (sprite ber-offset seperti NPC),
## collision di kaki, bayangan tetap di bawah pemain (lompat mengangkat sprite, bayangan
## tetap di tanah), dan bayangan di NPC, peliharaan, satwa liar, serta hewan ternak yang
## kakinya tepat di titik badan. Tidak menulis slot save.

const GroundShadow := preload("res://scripts/effects/ground_shadow.gd")

var failures := 0

func check(value: bool, label: String) -> void:
	if value:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func _shadow_of(node: Node) -> Node2D:
	return node.get_node_or_null("GroundShadow") as Node2D

## Baris terbawah sprite (koordinat lokal pemiliknya), dengan sprite terpusat.
func _sprite_bottom(sprite: AnimatedSprite2D) -> float:
	var texture := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	return sprite.position.y + (sprite.offset.y + texture.get_height() * 0.5) * sprite.scale.y

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_environment("NUSA_SAVE_AUDIT") != "1" or not OS.get_user_data_dir().replace("\\", "/").contains("nusa-save-audit-"):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	GameState.new_game()
	# Kemampuan fakultas Universitas: tes ini menguji gerak/tempur, bukan kursusnya.
	Abilities.grant_all(GameState.p1())
	DayCycle.current_day = 3
	DayCycle.hour = 10
	DayCycle.is_running = false
	FarmManager.farm_data.clear()
	var farm: Node2D = load("res://scenes/world/farm.tscn").instantiate()
	get_tree().root.add_child(farm)
	get_tree().current_scene = farm
	await get_tree().physics_frame
	await get_tree().create_timer(0.5, true).timeout

	# Pemain: kaki di titik badan, collision di sana, bayangan di bawah sprite.
	var player := farm.find_child("CharacterBody2D", true, false) as Player
	check(player != null, "farm player available")
	if player != null:
		var sprite := player.animation_controller.sprite
		check(player.FEET_OFFSET == Vector2.ZERO and sprite.offset == Player.SPRITE_OFFSET, "player body origin is at the feet (sprite offset like NPCs)")
		var shape := player.get_node("CollisionShape2D") as CollisionShape2D
		check(shape.position == Vector2.ZERO, "player collision sits at the feet")
		# Kaki di baris 25 dari sel 32: dasar kaki 0-1 px dari titik badan.
		var feet_row := sprite.position.y + sprite.offset.y - 16.0 + 26.0
		check(absf(feet_row) <= 1.0, "player sprite feet meet the body origin (%.1f px)" % feet_row)
		var shadow := player.ground_shadow
		check(is_instance_valid(shadow) and shadow.get_index() == 0 and shadow.visible and shadow.position == Vector2.ZERO, "player has a ground shadow drawn under the sprite at the feet")
		var home := sprite.position
		check(player.try_jump(), "player can jump")
		var peak_lift := 0.0
		var max_rise := 0.0
		for frame in 20:
			await get_tree().physics_frame
			peak_lift = maxf(peak_lift, shadow.lift)
			max_rise = maxf(max_rise, home.y - sprite.position.y)
		check(peak_lift > 3.0 and max_rise > 3.0 and shadow.position == Vector2.ZERO, "jump lifts the sprite while the shadow stays on the ground")
		await get_tree().create_timer(0.6, true).timeout
		check(shadow.visible and is_zero_approx(shadow.lift) and sprite.position == home, "after landing the shadow stays visible and the sprite is back on its feet")
		check(farm.find_children("JumpShadow", "", true, false).is_empty() and player.find_children("GroundShadow", "", false, false).size() == 1, "jumping reuses the single player shadow")

	# NPC: semua scene NPC aktif memakai offset kaki dan mendapat bayangan dari VillageNPC/Blacksmith.
	for path in ["res://scenes/npc/ScheduledNPC.tscn", "res://scenes/npc/BaharNPC.tscn", "res://scenes/npc/BlacksmithNPC.tscn", "res://scenes/npc/RianNPC.tscn"]:
		var npc: Node2D = load(path).instantiate()
		farm.add_child(npc)
		await get_tree().process_frame
		var npc_sprite := npc.get_node("AnimatedSprite2D") as AnimatedSprite2D
		var npc_shadow := _shadow_of(npc)
		check(npc_sprite.offset == Vector2(0, -10) and npc_shadow != null and npc_shadow.get_index() == 0, "%s has feet at its origin and a ground shadow" % path.get_file())
		npc.queue_free()

	# Hewan.
	var world := Node2D.new()
	farm.add_child(world)
	GameState.p1().load_pet({"pet_id": "dog_brown", "pet_name": "Belang"})
	var pet := PetActor.new()
	pet.home = Vector2(40, 40)
	pet.position = pet.home
	world.add_child(pet)
	check(_shadow_of(pet) != null and _shadow_of(pet).get_index() == 0, "pet has a ground shadow")
	var fox := WildAnimal.new()
	fox.setup(load("res://resources/wildlife/fox_red.tres"))
	world.add_child(fox)
	fox.place(Vector2(80, 40))
	check(_shadow_of(fox) != null and _shadow_of(fox).radius >= 6.0, "large wildlife has a wider ground shadow")
	var frog := WildAnimal.new()
	frog.setup(load("res://resources/wildlife/frog.tres"))
	world.add_child(frog)
	frog.place(Vector2(120, 40))
	check(_shadow_of(frog) != null and _shadow_of(frog).radius < _shadow_of(fox).radius, "small wildlife has a smaller ground shadow")

	StructureManager.records.assign([{"uid": 1, "item": "barn", "cell": [50, 50], "storage": [], "open": false, "job": {}, "ready": {}}, {"uid": 2, "item": "chicken_coop", "cell": [60, 50], "storage": [], "open": false, "job": {}, "ready": {}}])
	GameState.money = 100000
	check(StructureManager.buy_animal(1, "cow", "Sari").ok and StructureManager.buy_animal(2, "chicken", "Kiki").ok, "cow and chicken purchased")
	for uid in [1, 2]:
		var state := StructureManager.coop_state(StructureManager.record_for(uid))
		state.door = false
		var actor: CharacterBody2D = load("res://scripts/world/ranch_animal.gd").new()
		actor.uid = uid
		actor.animal_id = int(state.chickens[0].id)
		actor.indoors = true
		actor.home = Vector2(160 + uid * 40, 40)
		actor.roam_rect = Rect2(actor.home, Vector2.ONE)
		world.add_child(actor)
		var animal_sprite: AnimatedSprite2D = actor._sprite
		var species := "cow" if uid == 1 else "chicken"
		check(absf(_sprite_bottom(animal_sprite)) <= 0.5, "%s sprite feet meet its body origin (%.1f px)" % [species, _sprite_bottom(animal_sprite)])
		check(_shadow_of(actor) != null and _shadow_of(actor).get_index() == 0, "%s has a ground shadow" % species)
		actor.lift_with(player)
		check(not _shadow_of(actor).visible, "%s shadow hides while carried" % species)
		actor.place_from_player(player)
		check(_shadow_of(actor).visible, "%s shadow returns when put down" % species)

	print("CHARACTER GROUNDING REGRESSION COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
