extends Node
## Regresi peternakan lanjutan (GDD 4.10.9-4.10.11): kerbau, kapibara, kuda, pembiakan, inkubator, bulu bebek, validasi save.
var failures := 0

func _ready() -> void:
	_run()
	print("ranch_expansion_regression failures=%d" % failures)
	await get_tree().create_timer(5.0).timeout
	get_tree().quit(failures)

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		push_error("GAGAL: " + label)

func _animal(state: Dictionary, kind: String, affection: int = 0) -> Dictionary:
	var animal: Dictionary = RanchHusbandry.ANIMAL_DEFAULTS.duplicate()
	animal.merge({"id": int(state.next_id), "name": kind, "variant": "white", "species": kind, "fed_day": 0, "pet_day": 0, "affection": affection}, true)
	state.chickens.append(animal)
	state.next_id = int(state.next_id) + 1
	return animal

func _feed_all(state: Dictionary, day: int) -> void:
	for animal in state.chickens:
		animal.fed_day = day
	state.dirt = 0

func _run() -> void:
	# Kerbau: susu tiap 2 hari terawat, tervalidasi sebagai Barn.
	var barn := RanchHusbandry.migrate(ChickenHusbandry.empty(1))
	var buffalo := _animal(barn, "buffalo")
	for day in [1, 2]:
		_feed_all(barn, day)
		RanchHusbandry.advance(barn, day + 1)
	_check(str(buffalo.ready) == "buffalo_milk", "kerbau menghasilkan susu setelah 2 hari: %s" % buffalo.ready)
	_check(RanchHusbandry.valid(barn, "barn"), "barn dengan kerbau valid")
	_check(GameState._resolve_item("buffalo_milk_large_gold") != null, "item susu kerbau besar emas ada")
	_check(StructureManager.artisan_output("cheese_press", "buffalo_milk_silver") == "buffalo_cheese_silver", "mesin keju menerima susu kerbau")
	# Kapibara: tanpa produk, memberi +1 kasih sayang hewan lain.
	var herd := RanchHusbandry.migrate(ChickenHusbandry.empty(1))
	var cow := _animal(herd, "cow")
	var capy := _animal(herd, "capybara")
	_feed_all(herd, 1)
	RanchHusbandry.advance(herd, 2)
	_check(int(cow.affection) == 3, "sapi +3 dengan kapibara: %d" % int(cow.affection))
	_check(int(capy.affection) == 2 and str(capy.ready).is_empty() and int(capy.progress) == 0, "kapibara tidak berproduksi")
	# Pembiakan: perlu 4 hati, kelahiran setelah BREED_DAYS hari terawat, anak dewasa setelah 5 hari.
	cow.affection = 90
	_check(RanchHusbandry.can_breed(herd, capy) != "" or capy.affection < 80, "kapibara 2 poin belum bisa dibiakkan")
	_check(RanchHusbandry.can_breed(herd, cow).is_empty(), "sapi 4 hati bisa dibiakkan")
	cow.pregnant = RanchHusbandry.BREED_DAYS.cow
	_check(not RanchHusbandry.can_breed(herd, capy).is_empty(), "hanya satu kehamilan per kandang")
	for day in range(2, 2 + int(RanchHusbandry.BREED_DAYS.cow)):
		_feed_all(herd, day)
		RanchHusbandry.advance(herd, day + 1)
	_check(herd.chickens.size() == 3, "anak sapi lahir: %d hewan" % herd.chickens.size())
	var calf: Dictionary = herd.chickens[2]
	_check(RanchHusbandry.species(calf) == "cow" and int(calf.baby_days) == 5, "anak sapi berumur 5 hari menuju dewasa")
	_check(RanchHusbandry.valid(herd, "barn"), "barn dengan anak valid")
	var start := int(herd.last_day)
	for day in range(start, start + 5):
		_feed_all(herd, day)
		RanchHusbandry.advance(herd, day + 1)
	_check(RanchHusbandry.is_adult(calf) and str(calf.ready).is_empty(), "anak dewasa tanpa produk saat masih kecil")
	# Inkubator dan bulu bebek.
	var coop := RanchHusbandry.migrate(ChickenHusbandry.empty(1))
	_animal(coop, "duck", 70)
	coop.incubator = {"installed": true, "egg": "chicken_egg_gold", "days": 3}
	_check(RanchHusbandry.valid(coop, "chicken_coop"), "coop dengan inkubator valid")
	for day in range(1, 5):
		_feed_all(coop, day)
		RanchHusbandry.advance(coop, day + 1)
	_check(coop.chickens.size() == 2 and RanchHusbandry.species(coop.chickens[1]) == "chicken", "telur menetas menjadi ayam")
	_check(str(coop.incubator.egg).is_empty(), "inkubator kosong setelah menetas")
	_check(int(coop.products.get("duck_feather", 0)) == 1, "bulu bebek setelah 4 hari: %s" % str(coop.products))
	_check(RanchHusbandry.valid(coop, "chicken_coop"), "coop dengan bulu bebek valid")
	var bad := coop.duplicate(true)
	bad.incubator = {"installed": true, "egg": "wool", "days": 1}
	_check(not RanchHusbandry.valid(bad, "chicken_coop"), "isi inkubator selain telur ditolak")
	var barn_incubator := barn.duplicate(true)
	barn_incubator.incubator = {"installed": true, "egg": "", "days": 0}
	_check(not RanchHusbandry.valid(barn_incubator, "barn"), "inkubator di Barn ditolak")
	# Save lama tanpa key baru tetap valid dan dimigrasi sebagai dewasa.
	var legacy := {"chickens": [{"id": 1, "name": "Lama", "variant": "white", "species": "cow", "fed_day": 0, "pet_day": 0, "affection": 10}], "eggs": 0, "next_id": 2, "last_day": 1}
	_check(RanchHusbandry.valid(legacy, "barn"), "save lama valid")
	RanchHusbandry.migrate(legacy)
	_check(RanchHusbandry.is_adult(legacy.chickens[0]) and int(legacy.chickens[0].pregnant) == 0 and not legacy.incubator.installed, "migrasi save lama")
	_check(SaveManager.SAVE_VERSION >= 26, "SAVE_VERSION naik")
	# Batas satu kuda dan kuda tidak berproduksi.
	var stable := RanchHusbandry.migrate(ChickenHusbandry.empty(1))
	var horse := _animal(stable, "horse")
	_feed_all(stable, 1)
	RanchHusbandry.advance(stable, 2)
	_check(str(horse.ready).is_empty() and RanchHusbandry.valid(stable, "barn"), "kuda valid tanpa produk")
	_check(not RanchHusbandry.can_breed(stable, horse).is_empty(), "kuda tidak dibiakkan")
	var record := {"uid": 990001, "item": "barn", "cell": [-4000, -4000], "storage": [], "open": false, "job": {}, "ready": {}, "livestock": stable}
	StructureManager.records.append(record)
	var money := GameState.money
	GameState.money = 100000
	var second := StructureManager.buy_animal(990001, "horse", "Dua")
	_check(not second.ok, "kuda kedua ditolak")
	# Warna kuda (dijual Eep): disimpan di variant, kuda lama "white" tetap valid.
	horse.variant = "chestnut"
	_check(RanchHusbandry.valid(stable, "barn") and RanchHusbandry.horse_coat(horse) == "4", "warna kuda valid")
	horse.variant = "white"
	_check(RanchHusbandry.horse_coat(horse) == "1", "kuda save lama memakai warna 1")
	var cow := _animal(stable, "cow")
	cow.variant = "pearl"
	_check(not RanchHusbandry.valid(stable, "barn"), "warna kuda ditolak untuk sapi")
	stable.chickens.erase(cow)
	var bad := StructureManager.buy_animal(990001, "cow", "Salah", "pearl")
	_check(not bad.ok, "varian tidak sah ditolak toko")
	var eep := load("res://resources/ui/eep_livestock_shop_presentation.tres")
	var rian := load("res://resources/ui/livestock_shop_presentation.tres")
	_check(eep.variants.get("horse", PackedStringArray()).size() == 5 and not eep.excluded_species.has("horse"), "kuda dan 5 warnanya dijual Eep")
	_check(rian.excluded_species.has("horse"), "toko ternak lain tidak menjual kuda")
	GameState.money = money
	StructureManager.records.erase(record)
	# Skrip kuda dunia/tunggangan dimuat lewat load(); pastikan bebas parse error.
	for path in ["res://scripts/world/horse_actor.gd", "res://scripts/world/horse_mount.gd"]:
		var script := load(path) as GDScript
		_check(script != null and script.can_instantiate(), "skrip bisa dimuat: " + path)
	_check(StructureManager.has_method("debug_spawn_horse"), "cheat kuda tersedia")
	# Animasi kuda memakai aset PNG/14.x Horse: kuda diam di dunia dan penunggang berlayer.
	var horse_frames: SpriteFrames = load("res://scripts/world/horse_actor.gd").horse_frames("4")
	_check(horse_frames.has_animation(&"idle_left") and horse_frames.get_frame_count(&"walk_down") == 4 and horse_frames.get_frame_count(&"run_left") == 6, "sprite kuda dari aset Horse")
	var catalog := load("res://resources/character/character_catalog.tres") as CharacterCatalog
	var built := CharacterSpriteBuilder.build(catalog, CharacterAppearance.new(), {}, PackedStringArray(["horse_idle_down", "horse_walk_right", "horse_run_left"]))
	var rider: SpriteFrames = built.frames
	_check(rider.has_animation(&"horse_walk_right") and rider.get_frame_count(&"horse_run_left") == 6, "animasi menunggang berlayer")
