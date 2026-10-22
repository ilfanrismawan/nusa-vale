extends Resource

## Existing dialogue/social data remains in JSON; editable fields below override it.
@export_file("*.json") var source_json: String
@export var npc_id: String
@export var display_name: String
@export var role_title: String
@export_range(1, 200, 1) var move_speed := 38.0
@export_range(0.1, 8, 0.1) var waypoint_radius := 2.0
@export var sprite_frames: SpriteFrames
@export var portrait: Texture2D
@export_enum("Inspector", "JSON") var schedule_source: int = 0
@export var default_schedule: Array[NPCScheduleEntry] = []
@export var rainy_schedule: Array[NPCScheduleEntry] = []

func definition() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(source_json))
	if not parsed is Dictionary:
		push_error("Invalid resident source: " + source_json)
		return {}
	var data: Dictionary = parsed.duplicate(true)
	data.id = npc_id
	data.name = display_name
	data.role = role_title
	data.move_speed = move_speed
	data.waypoint_radius = waypoint_radius
	if sprite_frames != null:
		data.visual.sprite_frames = sprite_frames.resource_path
	if portrait != null:
		data.visual.portrait = portrait.resource_path
	if schedule_source == 0:
		data.schedules = {"default": _entries(default_schedule)}
		if not rainy_schedule.is_empty():
			data.schedules.rainy = _entries(rainy_schedule)

	_normalize_data(data)
	return data

func _entries(schedule: Array[NPCScheduleEntry]) -> Array:
	var sorted: Array[NPCScheduleEntry] = []
	for entry in schedule:
		if entry != null:
			sorted.append(entry)
	sorted.sort_custom(func(a: NPCScheduleEntry, b: NPCScheduleEntry): return a.total_minutes() < b.total_minutes())
	var result: Array = []
	for entry in sorted:
		if entry != null:
			result.append({"time": "%02d:%02d" % [entry.hour, entry.minute], "map": str(entry.map_id), "point": str(entry.point_id), "activity": str(entry.activity)})
	return result

func _normalize_data(data: Dictionary) -> void:
	_normalize_service(data)
	_normalize_birthday(data)
	_normalize_gifts(data)
	_normalize_friendship(data)
	_normalize_expressions(data)

func _normalize_service(data: Dictionary) -> void:
	var raw: Variant = data.get("service")

	if raw is Dictionary:
		data["service_rules"] = raw.duplicate(true)
		data["service"] = str(raw.get("type", ""))
	elif raw is String:
		data["service_rules"] = {}
		data["service"] = raw
	else:
		data["service_rules"] = {}
		data["service"] = ""

func _normalize_birthday(data: Dictionary) -> void:
	var birthday: Variant = data.get("birthday")

	if birthday is Dictionary:
		data["birthday_season"] = str(birthday.get("season", ""))
		data["birthday_day"] = int(birthday.get("day", 0))

	if data.get("birthday_season", "") == "autumn":
		data["birthday_season"] = "fall"

func _normalize_gifts(data: Dictionary) -> void:
	var tastes: Variant = data.get("gift_tastes", {})

	if not tastes is Dictionary:
		return

	var aliases := {
		"loved": "love",
		"liked": "like",
		"neutral": "neutral",
		"disliked": "dislike",
		"hated": "hate"
	}

	for category: String in aliases:
		var short_name: String = aliases[category]
		var target := category + "_items"

		var items: Variant = tastes.get(category, tastes.get(short_name, data.get(target, [])))

		if items is Array or items is PackedStringArray:
			data[target] = items
		else:
			push_warning("Daftar hadiah harus berupa array: " + target)
			data[target] = []

func _normalize_friendship(data: Dictionary) -> void:
	var raw: Variant= data.get("friendship", {})
	var friendship: Dictionary = {}

	if raw is Dictionary:
		friendship = raw.duplicate(true)

	friendship["max_hearts"] = maxi(1, int(friendship.get("max_hearts", 10)))

	friendship["start"] = clampi(
		int(friendship.get("start", 0)),
		0,
		int(friendship["max_hearts"]) * NPCSocialService.POINTS_PER_HEART
	)

	data["friendship"] = friendship

func _normalize_expressions(data: Dictionary) -> void:
	var visual: Variant = data.get("visual", {})

	if not visual is Dictionary:
		return

	var columns := maxi(1, int(visual.get("portrait_columns", 5)))

	var raw: Variant = visual.get("expressions", visual.get("expression", {}))

	if not raw is Dictionary:
		return

	var converted: Dictionary = {}

	for expression_name in raw:
		var value: Variant = raw[expression_name]

		if value is Array:
			if value.size() == 2:
				converted[expression_name] = [
					int(value[0]),
					int(value[1])
				]
		elif value is int or value is float:
			var index := int(value)

			if index < 0 or float(value) != float(index):
				push_warning("Index ekspresi harus bilangan bulat positif: " + str(expression_name))
				continue

			converted[expression_name] = [
				index % columns, floori(float(index) / float(columns))
			]

	visual["expressions"] = converted
	data["visual"] = visual
