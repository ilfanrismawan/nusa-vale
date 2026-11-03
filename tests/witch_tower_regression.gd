extends Node2D

## Menara Penyihir (GDD "Menara Penyihir & Mini Game Sihir"): interior & NPC termuat, mini game
## Racik di Kuali / Gambar Rune / Urutan Mantra bisa diselesaikan, crafting kuali, pesona senjata
## (Enchanting + validasi save v28), kursus sihir baru, dan resource Hutan Dalam tidak muncul di
## tapak menara. Tidak menulis save ke disk.

const INTERIOR := "res://scenes/world/interior/witch_tower.tscn"
const DEEP_FOREST := "res://scenes/world/DeepForest.tscn"
const Enchanting = preload("res://scripts/system/enchanting.gd")
const BrewGame = preload("res://scripts/ui/magic/cauldron_brew_game.gd")
const RuneGame = preload("res://scripts/ui/magic/rune_trace_game.gd")
const SequenceGame = preload("res://scripts/ui/magic/spell_sequence_game.gd")
const CAULDRON: CraftingCatalog = preload("res://resources/witch/cauldron_catalog.tres")
const CHARMS: CraftingCatalog = preload("res://resources/witch/charm_catalog.tres")

const LOG := "res://tests/_snapshots/witch_tower_log.txt"
const SHOTS := "res://tests/_snapshots/"

var failures := 0
var player: Player
var _log: FileAccess


func check(value: bool, label: String) -> void:
	_write(("PASS: " if value else "FAIL: ") + label)
	if value:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)


func _write(line: String) -> void:
	if _log == null:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOTS))
		_log = FileAccess.open(LOG, FileAccess.WRITE)
	if _log != null:
		_log.store_line(line)
		_log.flush()


## Simpan tangkapan layar jendela game ke tests/_snapshots/<name>.png.
func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(SHOTS + name + ".png")
	_write("SHOT: " + name)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	GameState.new_game()
	_write("start")
	_test_data()
	await _test_deep_forest()
	var room := (load(INTERIOR) as PackedScene).instantiate()
	add_child(room)
	await _frames(3)
	player = room.get_node("Player/CharacterBody2D") as Player
	var npc := room.get_node("Perabot/NyaiKenanga")
	check(npc.get_node("AnimatedSprite2D").sprite_frames != null, "Nyai Kenanga punya sprite dari layer karakter")
	check(npc.shop_data != null and npc.shop_data.stock.size() == 12, "Toko Sihir berisi 10 tongkat + 2 bahan")
	for station_name in ["Kuali", "MejaJimat", "AltarEnchant"]:
		check(room.has_node("Perabot/" + station_name), "stasiun %s ada" % station_name)
	await _frames(10)
	await shot("witch_tower_interior")
	await _test_brew()
	await _test_rune()
	await _test_sequence()
	_test_crafting()
	room.queue_free()
	await _frames(2)
	await _test_university()
	print("WITCH TOWER REGRESSION COMPLETE: failures=%d" % failures)
	_write("COMPLETE failures=%d" % failures)
	# Jeda supaya log sempat dibaca alat debug sebelum proses keluar.
	await get_tree().create_timer(60.0).timeout
	get_tree().quit(1 if failures > 0 else 0)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _test_data() -> void:
	var data := GameState.p1()
	check(CAULDRON.recipes.size() == 5 and CHARMS.recipes.size() == 3, "katalog kuali 5 resep, jimat 3 resep")
	for catalog in [CAULDRON, CHARMS]:
		for recipe in catalog.recipes:
			check(GameState._resolve_item(recipe.output_item_id) != null, "hasil %s ada" % recipe.output_item_id)
			for id in recipe.ingredients:
				check(GameState._resolve_item(String(id)) != null, "bahan %s ada" % id)
	check(Enchanting.all().size() == 5, "5 pesona termuat")
	var sword := GameState._resolve_item("sword_wood")
	check(Enchanting.can_enchant(sword), "pedang kayu bisa dipesona")
	check(Enchanting.fx_for(data, sword).status == WeaponTierFx.for_item(sword).status, "tanpa pesona = status tier")
	Enchanting.set_enchant(data, "sword_wood", "ember")
	check(Enchanting.fx_for(data, sword).status == WeaponTierFx.Status.BURN, "pesona Ember = BURN")
	check(WeaponTierFx.for_item(sword).status == WeaponTierFx.Status.NONE, "fx tier asli tidak berubah")
	var saved := data.to_dict()
	check(saved.get("enchants", {}).get("sword_wood", "") == "ember", "to_dict menyimpan enchants")
	Enchanting.load_save(data, {})
	check(data.enchants.is_empty(), "save lama tanpa enchants = kosong")
	Enchanting.load_save(data, {"enchants": {"sword_wood": "frost", "bow_wood": "bukan_pesona"}})
	check(data.enchants.size() == 1 and data.enchants["sword_wood"] == "frost", "load_save menyaring id pesona")
	check(not Enchanting.valid_save({"x": 3}), "valid_save menolak nilai bukan String")
	check(SaveManager.SAVE_VERSION == 28, "SAVE_VERSION 28")
	# Kursus sihir berantai.
	data.abilities.clear()
	check(Abilities.next_course(data, Abilities.FACULTY_MAGIC).id == Abilities.MAGIC, "kursus sihir pertama = Dasar Sihir Tongkat")
	Abilities.learn(data, Abilities.MAGIC)
	check(Abilities.next_course(data, Abilities.FACULTY_MAGIC).id == Abilities.CHARGED_BOLT, "berikutnya Bola Sihir Terisi")
	check(Abilities.course(Abilities.LIGHT_SPELL).get("minigame", "") == "sequence", "Cahaya memakai Urutan Mantra")
	Abilities.grant_all(data)


func _test_deep_forest() -> void:
	var forest := (load(DEEP_FOREST) as PackedScene).instantiate()
	add_child(forest)
	await _frames(2)
	var tower := forest.get_node_or_null("YSortEntities/WitchTower") as Node2D
	check(tower != null, "Menara Penyihir ada di Hutan Dalam")
	if tower != null:
		var block: Rect2 = tower.get_meta("resource_block")
		block.position += tower.position
		var ground := forest.get_node("BaseLayerGround") as TileMapLayer
		var inside := 0
		for cell: Vector2i in forest.resource_spawn_cells:
			if block.has_point(ground.to_global(ground.map_to_local(cell))):
				inside += 1
		check(inside == 0, "tidak ada sel resource di tapak menara (%d)" % inside)
		check(tower.get_node("Door").is_in_group("scene_door"), "pintu menara = scene_door")
		var walker := forest.get_node_or_null("Player/CharacterBody2D") as Node2D
		if walker != null:
			walker.global_position = tower.global_position + Vector2(0, 40)
			await _frames(20)
			await shot("witch_tower_exterior")
	forest.queue_free()
	await _frames(2)


func _test_brew() -> void:
	var recipe := CAULDRON.recipes[0]
	var game := BrewGame.new()
	game.player = player
	game.recipe = recipe
	game.title = "Racik di Kuali: %s" % GameState._resolve_item(recipe.output_item_id).display_name
	var result := [null]
	game.finished.connect(func(ok: bool) -> void: result[0] = ok)
	add_child(game)
	await _frames(1)
	check(game._tray.size() > game._order.size(), "nampan berisi bahan pengecoh")
	# Salah bahan dulu = kesalahan.
	for i in game._tray.size():
		if not recipe.ingredients.has(game._tray[i].item_id):
			game._drop(i)
			break
	check(game._mistakes == 1, "bahan pengecoh = 1 kesalahan")
	var first_round := true
	for item in game._order.duplicate():
		game._drop(game._tray.find(item))
		if first_round:
			first_round = false
			await _frames(3)
			await shot("minigame_kuali_1_bahan")
	check(game._phase == game.Phase.STIR, "semua bahan masuk -> fase aduk")
	var direction := 1.0 if recipe.stir_clockwise else -1.0
	for i in 14:
		game._add_stir(direction * TAU * recipe.stir_turns / 30.0)
	await _frames(3)
	await shot("minigame_kuali_2_aduk")
	for i in 26:
		game._add_stir(direction * TAU * recipe.stir_turns / 30.0)
	game._tick(0.016)
	check(game._phase == game.Phase.LIFT, "aduk cukup -> fase angkat")
	var mid := (game._zone.x + game._zone.y) * 0.5
	game._lift_t = acos(1.0 - 2.0 * mid) / PI
	game._lift_speed = 0.0
	await _frames(3)
	await shot("minigame_kuali_3_angkat")
	game._lift()
	check(result[0] == true, "Racik di Kuali berhasil")
	await get_tree().create_timer(1.5).timeout
	check(not is_instance_valid(game), "panel kuali tertutup")


func _test_rune() -> void:
	var game := RuneGame.new()
	game.player = player
	game.rune = "bolt"
	game.title = "Gambar Rune: Kantil Charm"
	var result := [null]
	game.finished.connect(func(ok: bool) -> void: result[0] = ok)
	add_child(game)
	await _frames(1)
	game._drawing = true
	game._move_cursor(game._points[0])
	for i in range(1, game._points.size()):
		var a: Vector2 = game._points[i - 1]
		var b: Vector2 = game._points[i]
		for s in 12:
			game._move_cursor(a.lerp(b, (s + 1) / 12.0))
		if i == 2:
			await _frames(3)
			await shot("minigame_rune_jimat")
	check(result[0] == true, "Gambar Rune berhasil bila garis diikuti")
	await get_tree().create_timer(0.4).timeout
	await shot("minigame_hasil_berhasil")
	var bad := RuneGame.new()
	bad.player = player
	bad.rune = "shield"
	var bad_result := [null]
	bad.finished.connect(func(ok: bool) -> void: bad_result[0] = ok)
	add_child(bad)
	await _frames(1)
	bad._drawing = true
	bad._move_cursor(bad._points[0])
	for i in 3:
		bad._stray_cooldown = 0.0
		bad._move_cursor(bad._points[0] + Vector2(0, 90))
	check(bad_result[0] == false, "Gambar Rune gagal setelah 3 kali meleset")
	await get_tree().create_timer(1.5).timeout


func _test_sequence() -> void:
	var game := SequenceGame.new()
	game.player = player
	game.length = 5
	game.title = "Urutan Mantra: Pesona Ember"
	var result := [null]
	game.finished.connect(func(ok: bool) -> void: result[0] = ok)
	add_child(game)
	await _frames(1)
	check(game._sequence.size() == 5, "urutan mantra 5 simbol")
	await get_tree().create_timer(1.3).timeout
	await shot("minigame_mantra_1_hafalkan")
	game._showing = false
	game._timer = game.answer_seconds
	var answers := game._sequence.duplicate()
	game._answer(answers[0])
	game._answer(answers[1])
	await _frames(3)
	await shot("minigame_mantra_2_ulangi")
	for symbol in answers.slice(2):
		game._answer(symbol)
	check(result[0] == true, "Urutan Mantra berhasil bila urutan benar")
	await get_tree().create_timer(1.5).timeout


func _test_crafting() -> void:
	var data := GameState.p1()
	var recipe := CAULDRON.recipes[1]
	for slot in data.inventory.size():
		data.inventory[slot] = null
	for id in recipe.ingredients:
		data.add_item(GameState._resolve_item(String(id)), int(recipe.ingredients[id]))
	var before := data.get_item_count(recipe.output_item_id)
	var craft := CraftingSystem.craft(data, recipe)
	check(craft["ok"] and data.get_item_count(recipe.output_item_id) == before + 1, "elixir kuali masuk tas (%s)" % craft["message"])


## Ujian praktik kursus sihir di Universitas (scene asli sebagai latar).
func _test_university() -> void:
	var uni := (load("res://scenes/world/interior/university.tscn") as PackedScene).instantiate()
	add_child(uni)
	await _frames(5)
	var student := uni.find_child("CharacterBody2D", true, false) as Player
	check(student != null, "Universitas termuat dengan pemain")
	if student == null:
		return
	var rune := RuneGame.new()
	rune.player = student
	rune.rune = "staff"
	rune.title = "Ujian Praktik: Dasar Sihir Tongkat"
	Coop.ui_parent(student).add_child(rune)
	await _frames(2)
	rune._drawing = true
	rune._move_cursor(rune._points[0])
	for s in 10:
		rune._move_cursor(rune._points[0].lerp(rune._points[1], (s + 1) / 10.0))
	await _frames(3)
	await shot("universitas_ujian_rune")
	rune.queue_free()
	await _frames(2)
	var seq := SequenceGame.new()
	seq.player = student
	seq.length = 5
	seq.title = "Ujian Praktik: Bola Sihir Terisi"
	Coop.ui_parent(student).add_child(seq)
	await get_tree().create_timer(1.3).timeout
	await shot("universitas_ujian_mantra")
	seq.queue_free()
	await _frames(2)
	check(true, "snapshot universitas selesai")
