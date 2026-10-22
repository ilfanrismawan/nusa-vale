class_name  NPCDialogueResolver
extends  RefCounted

static func packet(raw: Variant, player_data: PlayerData) -> Dictionary:
	var lines := PackedStringArray()
	var expressions := PackedStringArray()
	var entries: Array = []

	if raw is Array:
		entries = raw
	elif raw is PackedStringArray:
		entries = Array(raw)
	elif raw is String or raw is Dictionary:
		entries = [raw]
	for entry in entries:
		var text := ""
		var expression := "neutral"
		if entry is String:
			text = entry
		elif entry is Dictionary:
			var required: Variant = entry.get("requires_flags", [])
			if player_data == null:
				if not required is Array or not required.is_empty():
					continue
			elif not player_data.has_story_flags(required):
				continue
			text = str(entry.get("text", ""))
			expression = str(entry.get("expression", entry.get("expressions", "neutral")))
		if not text.is_empty():
			lines.append(text)
			expressions.append(expression)
	return {"lines": lines, "expressions": expressions}

static func resolve(player_data: PlayerData, npc_id: String, activity: String) -> Dictionary:
	var definition: Dictionary = NPCDatabase.residents.get(npc_id, {})
	var dialogue: Dictionary = definition.get("dialogue", {})
	var result := packet(dialogue.get(activity, []), player_data)
	if result.lines.is_empty():
		result = packet(dialogue.get("default", []), player_data)
	var hearts := int(float(NPCSocialService.points(player_data, npc_id)) / NPCSocialService.POINTS_PER_HEART)
	var tiers: Dictionary = definition.get("dialogue_by_hearts", {})
	var best := -1
	for key in tiers:
		if not str(key).is_valid_int():
			continue
		var threshold := int(key)
		if threshold > hearts or threshold <= best:
			continue
		var candidate := packet(tiers[key], player_data)
		if not candidate.lines.is_empty():
			result = candidate
			best = threshold
	return result
