extends Node

signal tool_upgraded(old_tool_id: String, new_tool_id: String)

const TOOL_TYPES: Array[String] = [
	"axe",
	"pickaxe",
	"hoe",
	"shovel",
	"sickle",
	"watering_can"
]

const TIERS: Array[String] = [
	"wood",
	"copper",
	"iron",
	"gold",
	"platinum",
	"crimson",
	"frost",
	"shadow",
	"fairy",
	"obsidian"
]

func _normalize_tool_id(tool_id: String) -> String:
	if tool_id in TOOL_TYPES:
		return tool_id + "_wood"
	return tool_id

func _parse_tool(tool_id: String) -> Dictionary:
	var norm: String = _normalize_tool_id(tool_id)
	for t in TOOL_TYPES:
		if norm == t:
			return {"type": t, "tier": "wood"}
		if norm.begins_with(t + "_"):
			var tier: String = norm.substr((t + "_").length())
			if tier in TIERS:
				return {"type": t, "tier": tier}
	return {}

func can_upgrade(tool_id: String) -> bool:
	var data: Dictionary = get_upgrade_data(tool_id)
	return not data.is_empty()

func get_upgrade_data(tool_id: String) -> Dictionary:
	var parsed: Dictionary = _parse_tool(tool_id)
	if parsed.is_empty():
		return {}

	var current_tier: String = parsed["tier"]
	var current_tier_idx: int = TIERS.find(current_tier)
	if current_tier_idx == -1 or current_tier_idx >= TIERS.size() - 1:
		return {}

	var next_tier: String = TIERS[current_tier_idx + 1]
	var next_tool_id: String = "%s_%s" % [parsed["type"], next_tier]

	var res_path: String = "res://resources/tool_data/%s.tres" % next_tool_id
	if ResourceLoader.exists(res_path):
		var tool_data: ToolData = load(res_path) as ToolData
		if tool_data != null:
			return {
				"next": next_tool_id,
				"cost": tool_data.upgrade_cost_money,
				"materials": tool_data.required_items,
				"display_name": tool_data.display_name
			}

	return _get_fallback_upgrade_data(parsed["type"], next_tier, next_tool_id)

func _get_fallback_upgrade_data(_tool_type: String, next_tier: String, next_tool_id: String) -> Dictionary:
	var costs := {
		"copper": 500,
		"iron": 1000,
		"gold": 2000,
		"platinum": 3500,
		"crimson": 5000,
		"frost": 7000,
		"shadow": 9000,
		"fairy": 12000,
		"obsidian": 18000
	}
	var materials := {
		"copper": {"copper_bar": 5, "wood": 10},
		"iron": {"iron_bar": 5, "wood": 15},
		"gold": {"gold_bar": 5},
		"platinum": {"platinum_bar": 5},
		"crimson": {"crimson_bar": 5},
		"frost": {"frost_bar": 5},
		"shadow": {"shadow_bar": 5},
		"fairy": {"fairy_bar": 5},
		"obsidian": {"obsidian_bar": 5}
	}

	return {
		"next": next_tool_id,
		"cost": costs.get(next_tier, 1000),
		"materials": materials.get(next_tier, {})
	}

func upgrade_tool(tool_id: String) -> bool:
	if not can_upgrade(tool_id):
		Notify.say("Alat ini sudah di tingkat maksimal.")
		return false

	var data: Dictionary = get_upgrade_data(tool_id)
	var money_cost: int = int(data.get("cost", 0))

	if GameState.money < money_cost:
		Notify.say("Uang tidak cukup (Butuh %d G)." % money_cost)
		return false

	var materials: Dictionary = data.get("materials", {})
	for item_id in materials:
		var required: int = int(materials[item_id])
		if not GameState.has_item(item_id, required):
			var mat_item := GameState._resolve_item(item_id)
			var mat_name: String = mat_item.display_name if mat_item != null else item_id
			Notify.say("Material tidak cukup (%s butuh %d)." % [mat_name, required])
			return false

	var new_tool_id: String = str(data["next"])

	var replaced: bool = GameState.replace_tool(tool_id, new_tool_id)
	if not replaced:
		var norm: String = _normalize_tool_id(tool_id)
		if norm != tool_id:
			replaced = GameState.replace_tool(norm, new_tool_id)
		elif tool_id.ends_with("_wood"):
			var base_id: String = tool_id.replace("_wood", "")
			replaced = GameState.replace_tool(base_id, new_tool_id)

	if not replaced:
		Notify.say("Alat tidak ditemukan di inventory.")
		return false

	if money_cost > 0:
		GameState.spend_money(money_cost)

	for item_id in materials:
		var required: int = int(materials[item_id])
		GameState.remove_item(item_id, required)

	tool_upgraded.emit(tool_id, new_tool_id)

	var new_res := GameState._resolve_item(new_tool_id)
	var display_name: String = new_res.display_name if new_res != null else new_tool_id
	Notify.say("Berhasil meningkatkan ke %s!" % display_name)

	return true
