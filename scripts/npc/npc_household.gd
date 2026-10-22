class_name NPCHousehold
extends RefCounted

## Household and social reward transactions belong to each saved character.
static var _rules: Dictionary = {}

static func rules() -> Dictionary:
	if _rules.is_empty():
		_rules = JSON.parse_string(FileAccess.get_file_as_string("res://data/npc/social/household_rules.json"))
	return _rules

static func minimum_house_level() -> int:
	return int(rules().get("minimum_house_level", 2))

static func characters() -> Array[PlayerData]:
	var result: Array[PlayerData] = []
	for data in GameState.players + GameState.coop_roster:
		if data != null and data not in result:
			result.append(data)
	return result

static func can_reside(data: PlayerData, id: String) -> bool:
	if data == null or not data.household.is_empty():
		return false
	for other in characters():
		if other != data and str(other.household.get("npc", "")) == id:
			return false
	return true

static func roommate_available(data: PlayerData, id: String) -> bool:
	return can_reside(data, id) and id in rules().get("roommates", []) and data.household.is_empty() and data.romances.is_empty() \
		and GameState.house.level >= minimum_house_level() \
		and NPCSocialService.points(data, id) >= int(rules().get("roommate_hearts", 10)) * NPCSocialService.POINTS_PER_HEART

static func prepare(data: PlayerData, id: String, mode: String) -> bool:
	if data == null or not data.household.is_empty() or mode not in ["spouse", "roommate"]:
		return false
	if GameState.house.level < minimum_house_level() or not NPCDatabase.residents.has(id):
		return false
	if mode == "spouse":
		var definition: Dictionary = NPCDatabase.residents[id]
		var required := int(definition.get("romance", {}).get("marriage_hearts", 10))
		if not bool(definition.get("romanceable", false)) or data.romances.get(id, "") not in ["dating", "married"] or NPCSocialService.points(data, id) < required * NPCSocialService.POINTS_PER_HEART:
			return false
	if mode == "roommate" and not roommate_available(data, id):
		return false
	for other in characters():
		if other != data and str(other.household.get("npc", "")) == id:
			return false
	data.household = {"npc": id, "mode": mode, "ceremony_day": DayCycle.current_day + maxi(1, int(rules().get("ceremony_delay", 1))), "celebrated": false, "last_help_day": 0}
	return true

static func home_entry(id: String, hour: int) -> Dictionary:
	for data in characters():
		var home := data.household
		if str(home.get("npc", "")) != id or DayCycle.current_day < int(home.get("ceremony_day", 0)):
			continue
		# Keep work/social routines during the day; return home for breakfast/evening.
		if not bool(home.get("celebrated", false)) or hour < 9 or hour >= 18:
			return {"map": "player_home", "point": "household", "activity": "at_home"}
	return {}

static func ceremony_ready(data: PlayerData, id: String) -> bool:
	return str(data.household.get("npc", "")) == id and not bool(data.household.get("celebrated", false)) \
		and DayCycle.current_day >= int(data.household.get("ceremony_day", 0))

static func celebrate(data: PlayerData, id: String) -> bool:
	if not ceremony_ready(data, id):
		return false
	data.household.celebrated = true
	data.story_flags["household_" + id] = true
	advance(data, DayCycle.current_day)
	return true

static func advance_all(day: int) -> void:
	for data in characters():
		advance(data, day)

static func advance(data: PlayerData, day: int) -> void:
	# Legacy married characters receive a ceremony instead of losing their partner.
	if data.household.is_empty() and GameState.house.level >= minimum_house_level():
		for partner: String in data.romances:
			if data.romances[partner] == "married":
				prepare(data, partner, "spouse")
				break
	# Rewards queue once at the heart threshold, even while the owner is offline.
	var rewards: Dictionary = rules().get("recipe_rewards", {})
	for id: String in rewards:
		for reward: Dictionary in rewards[id]:
			var key := "friendship_recipe_%s_%s" % [id, str(reward.recipe)]
			if data.story_mail.has(key) or NPCSocialService.points(data, id) < int(reward.hearts) * NPCSocialService.POINTS_PER_HEART:
				continue
			data.story_mail[key] = {"subject": "Resep dari " + str(NPCDatabase.residents.get(id, {}).get("name", id)), "body": "Terima kasih sudah menjadi sahabatku. Kutitipkan resep dan bahan untuk dapurmu.", "npc": id, "arrival_day": day + 1, "read": false, "sets_flags": [], "recipes": [str(reward.recipe)], "items": reward.get("items", {}).duplicate()}
	var home := data.household
	if home.is_empty() or not bool(home.get("celebrated", false)) or int(home.get("last_help_day", 0)) >= day:
		return
	home.last_help_day = day
	var id := str(home.npc)
	# A ready breakfast waits in the mailbox if the bag is full or owner is absent.
	var key := "household_breakfast_" + id
	if data.story_mail.has(key) and not bool(data.story_mail[key].get("read", false)):
		key = ""
	if not key.is_empty():
		data.story_mail[key] = {"subject": "Sarapan di rumah", "body": "Aku menyiapkan sarapan untukmu. Selamat beraktivitas!", "npc": id, "arrival_day": day, "read": false, "sets_flags": [], "items": {"omelet": 1}}
	# Rotate chores deterministically. Feeding consumes the owner's actual supplies.
	if day % 2 == 0:
		for cell in FarmManager.farm_data:
			var plot: Dictionary = FarmManager.farm_data[cell]
			if str(plot.get("area", "farm")) == "farm" and plot.get("crop") != null:
				plot.watered = true
		FarmManager._restore_tiles()
	else:
		for record in StructureManager.records:
			if record.get("item") in StructureManager.RANCHES:
				StructureManager.feed_chickens(data, int(record.uid))
	# Limit claimed breakfast history; never discard an unclaimed letter.
	for letter_id: String in data.story_mail.keys():
		var letter: Dictionary = data.story_mail[letter_id]
		if letter_id.begins_with("household_breakfast_") and bool(letter.get("read", false)) and int(letter.arrival_day) < day - 7:
			data.story_mail.erase(letter_id)

static func claim_letter(data: PlayerData, id: String) -> Dictionary:
	var letter: Dictionary = data.story_mail.get(id, {})
	if letter.is_empty() or bool(letter.get("read", false)) or int(letter.arrival_day) > DayCycle.current_day:
		return {"ok": false, "message": "Surat belum tersedia."}
	if not valid_rewards(letter):
		return {"ok": false, "message": "Isi surat tidak valid."}
	var staged := PlayerData.new(-1)
	staged.bag_level = data.bag_level
	staged.load_inventory(data.serialize_inventory())
	var items: Dictionary = letter.get("items", {})
	for item_id: String in items:
		var item := GameState._resolve_item(item_id)
		if item == null or staged._store(item, int(items[item_id])) > 0:
			return {"ok": false, "message": "Sediakan ruang tas untuk bingkisan surat."}
	for recipe_id: String in letter.get("recipes", []):
		if CookingManager.get_recipe(recipe_id) == null:
			return {"ok": false, "message": "Resep surat tidak tersedia."}
	data.load_inventory(staged.serialize_inventory())
	for recipe_id: String in letter.get("recipes", []):
		if not recipe_id in data.learned_recipes:
			data.learned_recipes.append(recipe_id)
	for flag in letter.get("sets_flags", []):
		data.story_flags[str(flag)] = true
	letter.read = true
	# Notify observers only after all reward state has committed.
	data._changed()
	return {"ok": true, "message": "Surat dibaca; resep dan bingkisan diterima."}

static func valid_rewards(letter: Dictionary) -> bool:
	var recipes: Variant = letter.get("recipes", [])
	var items: Variant = letter.get("items", {})
	if not recipes is Array or recipes.size() > 32 or not items is Dictionary or items.size() > 32:
		return false
	for recipe in recipes:
		if not recipe is String or recipe.is_empty():
			return false
	for id in items:
		var count: Variant = items[id]
		if not id is String or not PlayerSkills._is_count(count) or float(count) != floorf(float(count)) or count < 1 or count > 999:
			return false
	return true

static func valid_home(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	if value.is_empty():
		return true
	if not value.get("npc") is String or str(value.npc).is_empty() or value.get("mode") not in ["spouse", "roommate"] or not value.get("celebrated") is bool:
		return false
	for key in ["ceremony_day", "last_help_day"]:
		var number: Variant = value.get(key)
		if not PlayerSkills._is_count(number) or float(number) != floorf(float(number)) or number > 1000000:
			return false
	return int(value.ceremony_day) >= 1
