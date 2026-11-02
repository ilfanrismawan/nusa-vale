extends Node

## Sakit, Obat Ternak, kritis, kabur ke Rian (tebus), mati, dan save/load dengan celah id hewan.
var failures := 0

func check(ok: bool, message: String) -> void:
	if ok:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func record(uid: int, item: String, cell: Vector2i) -> Dictionary:
	return {"uid": uid, "item": item, "cell": [cell.x, cell.y], "storage": [], "open": false, "job": {}, "ready": {}}

## Lewati `days` hari tanpa memberi makan siapa pun.
func neglect(days: int) -> void:
	for i in days:
		DayCycle.current_day += 1
		StructureManager._advance_chickens(DayCycle.current_day)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_environment("NUSA_SAVE_AUDIT") != "1" or not OS.get_user_data_dir().replace("\\", "/").contains("nusa-save-audit-"):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	GameState.new_game()
	DayCycle.current_day = 1
	GameState.money = 100000
	StructureManager.records.assign([record(7, "barn", Vector2i(44, 18))])
	StructureManager._next_uid = 8
	StructureManager.buy_animal(7, "cow", "Sari")
	StructureManager.buy_animal(7, "goat", "Kiki")
	var state := StructureManager.coop_state(StructureManager.record_for(7))
	var sari := RanchHusbandry.animal_by_id(state, 1)
	var kiki := RanchHusbandry.animal_by_id(state, 2)
	sari.affection = 80
	kiki.affection = 0
	sari.fed_day = 0
	kiki.fed_day = 0
	var data := GameState.p1()

	neglect(2)
	check(sari.sick and kiki.sick, "two neglected days make animals sick")
	check(RanchHusbandry.status_needs(sari, DayCycle.current_day)[0].kind == "sick", "sick animals show the sick bubble first")
	check(not StructureManager.treat_animal(data, 7, 1).ok, "treatment needs Obat Ternak")
	data.add_item_silent(StructureManager.MEDICINE, 1)
	check(StructureManager.treat_animal(data, 7, 1).ok and data.get_item_count(StructureManager.MEDICINE) == 0, "medicine is consumed on a sick animal")
	check(not StructureManager.treat_animal(data, 7, 1).ok, "an animal is treated at most once a day")
	neglect(1)
	check(not sari.sick and int(sari.bad_days) == 0, "treated animal recovers the next morning")
	check(kiki.sick, "untreated animal stays sick")

	neglect(1)
	check(RanchHusbandry.is_critical(kiki) and RanchHusbandry.condition(state, kiki, DayCycle.current_day).begins_with("Kritis"), "four neglected days are critical")
	sari.affection = 80
	neglect(2)
	check(RanchHusbandry.animal_by_id(state, 2).is_empty() and state.away.is_empty(), "low-affection animal dies after six neglected days")
	check(not RanchHusbandry.animal_by_id(state, 1).is_empty(), "recently treated animal is still home")
	sari.affection = 80
	neglect(4)
	check(state.chickens.is_empty() and state.away.size() == 1, "bonded animal runs away to Rian instead of dying")
	check(RanchHusbandry.valid(state, "barn"), "save state with gaps and away animals stays valid")
	var away := StructureManager.away_animals()
	check(away.size() == 1 and away[0].cost == RanchHusbandry.ransom_cost(sari) and away[0].days_left == RanchHusbandry.RANSOM_DAYS - (DayCycle.current_day - int(away[0].since)), "Rian lists the runaway with ransom and deadline")
	check(SaveManager.save_game() and SaveManager.load_game(), "save/load accepts away animals and id gaps")
	state = StructureManager.coop_state(StructureManager.record_for(7))
	check(state.away.size() == 1 and int(state.next_id) == 3, "away animal survives disk reload")
	GameState.money = 10
	check(not StructureManager.redeem_animal(7, 1).ok, "ransom needs enough money")
	GameState.money = 100000
	var before := GameState.money
	check(StructureManager.redeem_animal(7, 1).ok and state.away.is_empty() and state.chickens.size() == 1 and not state.chickens[0].sick, "redeeming returns the animal healthy")
	check(before - GameState.money == RanchHusbandry.ransom_cost(state.chickens[0]), "ransom charges the listed price")
	check(StructureManager.buy_animal(7, "sheep", "Bulu").ok and int(RanchHusbandry.animal_by_id(state, 3).get("id", 0)) == 3, "new purchases keep unique ids after losses")

	state.chickens[0].affection = 80
	neglect(RanchHusbandry.LOSS_DAYS)
	var runaway: int = state.away.size()
	neglect(RanchHusbandry.RANSOM_DAYS + 1)
	check(runaway > 0 and state.away.is_empty(), "unredeemed runaways are rehomed after the deadline")
	print("RANCH NEGLECT REGRESSION COMPLETE: failures=%d" % failures)
	get_tree().quit(failures)
