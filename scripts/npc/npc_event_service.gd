class_name NPCEventService
extends RefCounted

static func _minutes(value: String) -> int:
	var parts := value.split(":")
	return int(parts[0]) * 60 + int(parts[1]) if parts.size() == 2 else 0

static func _merged(raw: Dictionary, npc_id: String) -> Dictionary:
	var event := raw.duplicate(true)
	var story: Dictionary = NPCDatabase.family_story
	var required: Array = event.get("requires_flags", []).duplicate()
	var flags: Array = event.get("sets_flags", []).duplicate()
	for reveal: Dictionary in story.get("reveals", []):
		if reveal.get("id") != event.get("id") or reveal.get("npc") != npc_id:
			continue
		event.hearts = maxi(int(event.get("hearts", 0)), int(reveal.get("hearts", 0)))
		for flag in reveal.get("requires_flags", []):
			if flag not in required:
				required.append(flag)
		for flag in reveal.get("sets_flags", []):
			if flag not in flags:
				flags.append(flag)
	event.requires_flags = required
	event.sets_flags = flags
	return event

static func find_event(data: PlayerData, npc_id: String, map_id: String, points_root: Node, player_position: Vector2, actor_position: Vector2) -> Dictionary:
	var definition: Dictionary = NPCDatabase.residents.get(npc_id, {})
	var hearts := int(float(NPCSocialService.points(data, npc_id)) / NPCSocialService.POINTS_PER_HEART)
	var now := DayCycle.hour * 60 + DayCycle.minute
	for raw: Dictionary in definition.get("heart_events", []):
		var event := _merged(raw, npc_id)
		var id := str(event.get("id", ""))
		if id.is_empty() or bool(data.completed_events.get(id, false)):
			continue
		if hearts < int(event.get("hearts", 0)) or not data.has_story_flags(event.requires_flags):
			continue
		if str(event.get("map", map_id)) != map_id:
			continue
		var weather := str(event.get("weather", "any"))
		if weather == "clear":
			weather = "sunny"
		elif weather == "rainy":
			weather = "rain"
		if weather != "any" and weather != GameState.weather.current:
			continue
		var window: Array = event.get("time_range", [])
		if window.size() == 2:
			var start := _minutes(str(window[0]))
			var end := _minutes(str(window[1]))
			var inside := (now >= start and now < end) if start <= end else (now >= start or now < end)
			if not inside:
				continue
		if event.has("point"):
			if points_root == null:
				continue
			var marker := points_root.get_node_or_null(NodePath(str(event.point))) as Node2D
			if marker == null:
				continue
			var radius := float(event.get("radius", 48.0))
			if player_position.distance_to(marker.global_position) > radius or actor_position.distance_to(marker.global_position) > radius:
				continue
		var packet := NPCDialogueResolver.packet(event.get("lines", []), data)
		if packet.lines.is_empty():
			continue
		return event
	return {}

static func complete(data: PlayerData, event: Dictionary) -> void:
	var id := str(event.get("id", ""))
	if id.is_empty() or bool(data.completed_events.get(id, false)):
		return
	data.completed_events[id] = true
	for flag in event.get("sets_flags", []):
		data.story_flags[str(flag)] = true
	var completion: Dictionary = NPCDatabase.family_story.get("completion", {})
	if not completion.is_empty() and data.has_story_flags(completion.get("requires_flags", [])):
		for flag in completion.get("sets_flags", []):
			data.story_flags[str(flag)] = true
		var delivery: Dictionary = completion.get("event", {})
		var letter_id := str(delivery.get("id", ""))
		if delivery.get("type") == "mail" and not letter_id.is_empty() and not data.story_mail.has(letter_id):
			data.story_mail[letter_id] = {
				"subject": str(delivery.get("subject", "Surat")),
				"body": str(delivery.get("body", "")),
				"npc": str(delivery.get("npc", "")),
				"arrival_day": DayCycle.current_day + maxi(0, int(delivery.get("delay_days", 0))),
				"read": false,
				"sets_flags": delivery.get("read_flags", []).duplicate()
			}

static func pending_letter(data: PlayerData, npc_id: String) -> Dictionary:
	for id: String in data.story_mail:
		var letter: Dictionary = data.story_mail[id]
		if letter.npc == npc_id and not letter.read and int(letter.arrival_day) <= DayCycle.current_day:
			var result := letter.duplicate(true)
			result.id = id
			return result
	return {}
