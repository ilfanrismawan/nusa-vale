extends Node
var failures := 0
func check(ok: bool, label: String) -> void:
	if ok: print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func _ready() -> void:
	if OS.get_environment("NUSA_SAVE_AUDIT") != "1":
		get_tree().quit(2)
		return
	await get_tree().process_frame
	GameState.new_game()
	DayCycle.is_running = false
	var count := 0
	for filename in DirAccess.get_files_at("res://resources/crop_data"):
		if not filename.ends_with(".tres"): continue
		var crop := load("res://resources/crop_data/" + filename) as CropData
		var seed := GameState._resolve_item("seed_" + crop.crop_id)
		var item := GameState._resolve_item(crop.harvest_item_id)
		var days := (crop.get_total_stages() - 1) * crop.days_per_stage
		if crop.is_fruit_tree():
			# Pohon permanen: bibit mahal, berbuah tiap 3 hari, balik modal ±1 musim berbuah.
			var per_day := float(item.sell_price * crop.harvest_count) / crop.regrow_days
			var payback := seed.buy_price / per_day
			check(crop.regrow_days == 3 and per_day <= 60.0 and payback >= 30.0 and payback <= 40.0, "%s tree %.1f G/day, payback %.1f fruiting days" % [crop.crop_id, per_day, payback])
			check(seed.sell_price * 10 == seed.buy_price * 4, "%s sapling resells at 40%%" % crop.crop_id)
			count += 1
			continue
		var profit := item.sell_price * crop.harvest_count - seed.buy_price
		var daily := float(profit) / days
		check(daily >= 6.5 and daily <= 10.5, "%s net profit %.1f G/tile/day over %d days" % [crop.crop_id, daily, days])
		count += 1
	check(count == 39, "all 39 crop economies covered")
	var starter_gross := 5 * GameState._resolve_item("strawberry").sell_price * 2 + 3 * GameState._resolve_item("carrot").sell_price
	var replant := 5 * GameState._resolve_item("seed_strawberry").buy_price + 3 * GameState._resolve_item("seed_carrot").buy_price
	var copper_cost := int(ToolUpgradeManager.get_upgrade_data("pickaxe_wood").cost)
	check(starter_gross == 510 and starter_gross + GameState.money - copper_cost - replant >= 35, "first harvest funds copper plus all replacement seeds and a cash reserve")
	check(DayCycle.real_seconds_per_10_game_minutes * 120 == 720, "06:00 to 02:00 lasts twelve active minutes")
	var hoe := GameState._resolve_item("hoe_wood").action_data.tool_data
	var water := GameState._resolve_item("watering_can_wood").action_data.tool_data
	check(8 * (hoe.stamina_cost + water.stamina_cost) <= 40, "preparing and watering eight starter plots leaves sixty stamina")
	for animal in RanchHusbandry.SPECIES:
		var info: Dictionary = RanchHusbandry.SPECIES[animal]
		# Kapibara dan kuda (interval 0) tidak menghasilkan komoditas harian.
		if int(info.interval) <= 0:
			continue
		var item := GameState._resolve_item(info.product)
		var feed := GameState._resolve_item("hay").buy_price
		var net := float(item.sell_price) / int(info.interval) - feed
		check(net >= 35 and net <= 100, "%s daily net %.1f G after purchased feed" % [animal, net])
	for folder in ["preserves_jar", "dehydrator"]:
		for filename in DirAccess.get_files_at("res://resources/" + folder):
			if not filename.ends_with(".tres"): continue
			var recipe: Resource = load("res://resources/%s/%s" % [folder, filename])
			var input_value: int = GameState._resolve_item(recipe.input_item_id).sell_price * recipe.input_amount
			var output_value: int = GameState._resolve_item(recipe.output_item_id).sell_price * recipe.output_amount
			check(output_value > input_value and output_value <= input_value * 2, "processing adds bounded value: " + str(recipe.output_item_id))
	for tool in ToolUpgradeManager.TOOL_TYPES:
		for tier in range(1, ToolUpgradeManager.TIERS.size()):
			var previous_id: String = tool + "_" + ToolUpgradeManager.TIERS[tier - 1]
			var next_id: String = tool + "_" + ToolUpgradeManager.TIERS[tier]
			var quote: Dictionary = ToolUpgradeManager.get_upgrade_data(previous_id)
			var fallback: Dictionary = ToolUpgradeManager._get_fallback_upgrade_data(tool, ToolUpgradeManager.TIERS[tier], next_id)
			check(quote.cost == fallback.cost, "resource and fallback upgrade quote agree: " + next_id)
	# Keg/Fish Smoker: harga hasil relatif bahan (GDD 4.11, audit 26 Oktober 2026).
	var keg_mult := {"wine": 2.25, "juice": 2.0, "beer": 3.0, "mead": 3.0}
	for input in StructureManager.ARTISANS.keg:
		var output: String = StructureManager.ARTISANS.keg[input]
		var ratio := float(GameState._resolve_item(output).sell_price) / GameState._resolve_item(input).sell_price
		var expected := 0.0
		for kind in keg_mult:
			if output.ends_with(kind): expected = keg_mult[kind]
		check(absf(ratio - expected) < 0.05 and StructureManager.keg_days(output) in [2, 3, 4], "keg %s -> %s x%.2f in %d days" % [input, output, ratio, StructureManager.keg_days(output)])
	var smoked_count := 0
	for filename in DirAccess.get_files_at("res://resources/item_data"):
		if not filename.begins_with("fish_") or not filename.ends_with(".tres"): continue
		var fish := GameState._resolve_item(filename.trim_suffix(".tres"))
		if fish.category != ItemData.Category.FISH: continue
		var smoked := GameState._resolve_item(StructureManager.artisan_output("fish_smoker", fish.item_id))
		check(smoked != null and smoked.sell_price == fish.sell_price * 2, "smoked %s is worth 2x" % fish.item_id)
		smoked_count += 1
	check(smoked_count == 65, "all 65 fish have smoked goods")
	var bars := {"copper": 40, "iron": 80, "gold": 160, "platinum": 260, "crimson": 400, "frost": 580, "shadow": 800, "fairy": 1100, "obsidian": 1500}
	for metal in bars:
		check(GameState._resolve_item(metal + "_bar").sell_price == bars[metal], "%s bar sells for %d G (GDD 4.6)" % [metal, bars[metal]])
	# Barang toko tidak boleh bisa diolah mesin lalu dijual untung: diskon beli maks 15%,
	# bonus jual maks 35% (Economist 4x5%, sayap Niaga 5%, Shared Prosperity 10%).
	for shop_file in DirAccess.get_files_at("res://resources/shop"):
		if not shop_file.ends_with(".tres"): continue
		var shop := load("res://resources/shop/" + shop_file) as ShopData
		for stock_item in shop.stock:
			if stock_item == null or stock_item.buy_price <= 0: continue
			for machine in StructureManager.ARTISANS:
				var output := StructureManager.artisan_output(machine, stock_item.item_id)
				if output.is_empty(): continue
				var resale := GameState._resolve_item(output).sell_price * 1.35
				check(resale < stock_item.buy_price * 0.85, "%s from %s cannot be processed by %s for profit" % [stock_item.item_id, shop.shop_id, machine])
	print("ECONOMY BALANCE COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
