class_name NPCSocialService
extends RefCounted

const POINTS_PER_HEART := 250
const MAX_POINTS := 2500
const WEEKLY_GIFTS := 2
## Usulan pacing: decay baru dimulai setelah dua minggu tanpa percakapan.
const DECAY_GRACE_DAYS := 14
const GIFT_POINTS := {"loved": 80, "liked": 45, "neutral": 20, "disliked": -20, "hated": -40}

static func open_dialog(player: Player, id: String, speaker: String, portrait: Texture2D = null) -> NPCDialogUI:
	var ui := load("res://scenes/ui/npc_dialog_ui.tscn").instantiate() as NPCDialogUI
	ui.player = player
	ui.social_npc_id = id
	ui.npc_name = speaker
	ui.portrait_texture = portrait
	ui.lines = PackedStringArray(["Senang bertemu denganmu. Ada yang ingin kamu bicarakan?"])
	Coop.ui_parent(player).add_child(ui)
	return ui

static func max_hearts(id: String) -> int:
	var definition: Dictionary = NPCDatabase.social_definition(id)
	var settings: Dictionary = definition.get("friendship", {})

	return maxi(1, int(settings.get("max_hearts", 10)))

static func max_points(id: String) -> int:
	return max_hearts(id) * POINTS_PER_HEART

static func known(id: String) -> bool:
	return not NPCDatabase.social_definition(id).is_empty() or NPCDatabase.get_definition(StringName(id)) != null

static func _entry(data: PlayerData, id: String) -> Dictionary:
	if not data.friendships.has(id):
		var definition: Dictionary = NPCDatabase.social_definition(id)
		var settings: Dictionary = definition.get("friendship", {})

		data.friendships[id] = {"points": clampi(int(settings.get("start", 0)), 0, max_points(id)), "talk_day": 0, "gift_day": 0, "week": -1, "gifts": 0, "birthday_year": -1, "decay_day": DayCycle.current_day}
	var entry: Dictionary = data.friendships[id]
	entry["locked"] = bool(entry.get("locked", false)) or int(entry.points) >= max_points(id)
	entry.points = max_points(id) if entry.locked else clampi(int(entry.points), 0, max_points(id))
	return entry

static func advance(data: PlayerData, day: int) -> void:
	for id: String in data.friendships:
		var entry: Dictionary = _entry(data, id)
		var start := maxi(int(entry.decay_day), int(entry.talk_day) + DECAY_GRACE_DAYS)

		if not entry.locked:
			entry.points = maxi(0, int(entry.points) - maxi(0, day - start) * 2)
		entry.decay_day = maxi(int(entry.decay_day), day)

static func summary(data: PlayerData, id: String) -> String:
	var value := points(data, id)
	var hearts := int(float(value) / POINTS_PER_HEART)
	return "Persahabatan %d/%d hati · %d/%d" % [hearts, max_hearts(id), value, max_points(id)]

static func points(data: PlayerData, id: String) -> int:
	if data == null or not known(id):
		return 0
	advance(data, DayCycle.current_day)
	return int(_entry(data, id).points)

static func talk(data: PlayerData, id: String) -> void:
	if data == null or not known(id):
		return
	advance(data, DayCycle.current_day)
	var entry := _entry(data, id)
	if int(entry.talk_day) == DayCycle.current_day:
		return
	entry.talk_day = DayCycle.current_day
	entry.points = mini(max_points(id), int(entry.points) + 20)
	_entry(data, id)

static func _preference(id: String, key: String) -> Variant:
	var definition: Dictionary = NPCDatabase.social_definition(id)
	if not definition.is_empty():
		if definition.has(key + "_items"):
			return definition.get(key + "_items", [])
		var aliases := {"loved": "love", "liked": "like", "disliked": "dislike", "hated": "hate"}
		var tastes: Dictionary = definition.get("gift_tastes", {})
		return tastes.get(key, tastes.get(aliases.get(key, key), []))
	var legacy: NPCDefinition = NPCDatabase.get_definition(StringName(id))
	return legacy.get(key + "_items") if legacy != null else []

static func taste(id: String, item_id: String) -> String:
	for key in ["hated", "loved", "disliked", "liked", "neutral"]:
		if item_id in _preference(id, key):
			return key
	return "neutral"

static func relationship_action(data: PlayerData, id: String) -> String:
	var definition: Dictionary = NPCDatabase.social_definition(id)
	if data == null or (not data.household.is_empty() and data.household.get("mode") == "roommate") or not bool(definition.get("romanceable", false)):
		return ""
	var status := str(data.romances.get(id, ""))
	return "dating" if status.is_empty() else ("married" if status == "dating" else "")

static func can_relationship(data: PlayerData, id: String, status: String) -> bool:
	if relationship_action(data, id) != status or status.is_empty():
		return false
	for other: String in data.romances:
		if other != id and data.romances[other] in ["dating", "married"]:
			return false
	var definition: Dictionary = NPCDatabase.residents[id]
	var rules: Dictionary = definition.get("romance", {})
	var required := int(rules.get("dating_hearts" if status == "dating" else "marriage_hearts", 8 if status == "dating" else 10))
	if status == "married" and (GameState.house.level < NPCHousehold.minimum_house_level() or not NPCHousehold.can_reside(data, id)):
		return false
	return points(data, id) >= required * POINTS_PER_HEART

static func commit_relationship(data: PlayerData, id: String, status: String) -> bool:
	if not can_relationship(data, id, status):
		return false
	if status == "married" and not NPCHousehold.prepare(data, id, "spouse"):
		return false
	data.romances[id] = status
	data.story_flags[("dating_" if status == "dating" else "married_") + id] = true
	return true

static func _birthday(id: String) -> bool:
	var definition: Dictionary = NPCDatabase.social_definition(id)
	var birthday: Dictionary = definition.get("birthday", {})
	var season := str(definition.get("birthday_season", birthday.get("season", "")))
	var day := int(definition.get("birthday_day", birthday.get("day", 0)))
	var legacy: NPCDefinition = NPCDatabase.get_definition(StringName(id))
	if not definition.has("birthday") and not definition.has("birthday_season") and legacy != null:
		season = legacy.birthday_season
		day = legacy.birthday_day
	if season == "autumn":
		season = "fall"
	return season == DayCycle.SEASONS[DayCycle.get_season()] and day == (DayCycle.current_day - 1) % DayCycle.DAYS_PER_SEASON + 1

static func give(data: PlayerData, id: String, slot: int) -> Dictionary:
	if data == null or not known(id):
		return {"ok": false, "message": "Warga tidak tersedia."}
	if slot < 0 or slot >= data.bag_size or data.inventory[slot] == null:
		return {"ok": false, "message": "Pilih barang di hotbar untuk hadiah."}
	var item: ItemData = data.inventory[slot].item
	if item.item_id.begins_with("biji_daya"):
		return {"ok": false, "message": "Biji Daya tidak dapat diberikan sebagai hadiah."}
	if item.category in [ItemData.Category.TOOL, ItemData.Category.EQUIPMENT, ItemData.Category.BUILDING] or item.weapon_type != ItemData.WeaponType.NONE:
		return {"ok": false, "message": "Alat dan senjata tidak dapat diberikan."}
	advance(data, DayCycle.current_day)
	var entry := _entry(data, id)
	var day := DayCycle.current_day
	var week := int((day - 1) / 7)
	var year := int((day - 1) / (DayCycle.DAYS_PER_SEASON * DayCycle.SEASONS.size()))
	var birthday_bonus := _birthday(id) and int(entry.birthday_year) != year
	if int(entry.gift_day) == day:
		return {"ok": false, "message": "Sudah memberi hadiah hari ini."}
	var used := int(entry.gifts) if int(entry.week) == week else 0
	if used >= WEEKLY_GIFTS and not birthday_bonus:
		return {"ok": false, "message": "Batas dua hadiah minggu ini sudah tercapai."}
	if not data.remove_item_at(slot, 1):
		return {"ok": false, "message": "Hadiah tidak tersedia."}
	var reaction := taste(id, item.item_id)
	var delta := int(GIFT_POINTS[reaction]) * (8 if birthday_bonus else 1)
	var before := int(entry.points)
	entry.points = max_points(id) if entry.locked else clampi(before + delta, 0, max_points(id))
	_entry(data, id)
	delta = int(entry.points) - before
	entry.gift_day = day
	entry.week = week
	entry.gifts = used + (0 if birthday_bonus else 1)
	if birthday_bonus:
		entry.birthday_year = year
	var definition: Dictionary = NPCDatabase.social_definition(id)
	var aliases := {"loved": "love", "liked": "like", "disliked": "dislike", "hated": "hate", "neutral": "neutral"}
	var dialogues: Dictionary = definition.get("gift_dialogue", {})
	var raw: Variant = dialogues.get(reaction, dialogues.get(aliases[reaction], []))
	var gift := NPCDialogueResolver.packet(raw, data)
	var responses := {
		"loved": "Aku sangat menyukainya!",
		"liked": "Terima kasih, aku suka!",
		"neutral": "Terima kasih atas hadiahnya.",
		"disliked": "Maaf, ini kurang cocok untukku.",
		"hated": "Aku tidak menyukai barang ini."
	}
	var message: String = responses[reaction]
	var expression := "annoyed" if reaction in ["disliked", "hated"] else "happy"
	if not gift.lines.is_empty():
		message = gift.lines[0]
		expression = gift.expressions[0]
	return {"ok": true, "message": message, "taste": reaction, "points": delta, "expression": expression}

static func valid_save(value: Variant) -> bool:
	if not value is Dictionary or value.size() > 256:
		return false
	for id in value:
		if not id is String or id.is_empty() or not value[id] is Dictionary:
			return false
		var entry: Dictionary = value[id]
		for key in ["points", "talk_day", "gift_day", "week", "gifts", "birthday_year", "decay_day"]:
			var number: Variant = entry.get(key)
			if not (number is int or number is float) or not is_finite(float(number)) or float(number) != floorf(float(number)) or number < (-1 if key in ["week", "birthday_year"] else 0) or number > 1000000:
				return false
		if entry.has("locked") and not entry.locked is bool:
			return false
		if entry.gifts > WEEKLY_GIFTS:
			return false
	return true
