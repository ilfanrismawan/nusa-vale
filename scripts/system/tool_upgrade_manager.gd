extends Node

signal tool_upgraded(old_tool_id: String, new_tool_id: String)

const TOOL_TYPES: Array[String] = [
	"axe",
	"pickaxe",
	"hoe",
	"shovel",
	"sickle",
	"watering_can",
	"fishing_rod"
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
		"iron": 1200,
		"gold": 2500,
		"platinum": 4500,
		"crimson": 7000,
		"frost": 10000,
		"shadow": 14000,
		"fairy": 20000,
		"obsidian": 28000
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

## Two day boundaries must pass. Orders belong to PlayerData, including P2-P4.
const WORK_DAYS := 2

func upgrade_tool(tool_id: String) -> bool:
	var owner := GameState.current
	if not owner.tool_order.is_empty():
		Notify.say("Masih ada pesanan di bengkel. Ambil alatmu dahulu.")
		return false
	var upgrade := get_upgrade_data(tool_id)
	if upgrade.is_empty():
		return false
	var actual_id := tool_id
	if not owner.has_item(actual_id):
		actual_id = _normalize_tool_id(tool_id)
		if not owner.has_item(actual_id) and tool_id.ends_with("_wood"):
			actual_id = tool_id.trim_suffix("_wood")
	if not owner.has_item(actual_id):
		Notify.say("Alat tidak ditemukan di tas.")
		return false
	var cost := int(upgrade.get("cost", 0))
	var materials: Dictionary = upgrade.get("materials", {})
	if GameState.money < cost:
		Notify.say("Uang tidak cukup.")
		return false
	for id in materials:
		if not owner.has_item(id, int(materials[id])):
			Notify.say("Bahan tempa belum lengkap.")
			return false
	owner.tool_order = {"old": actual_id, "next": str(upgrade["next"]), "ready_day": DayCycle.current_day + WORK_DAYS}
	owner.remove_item(actual_id, 1)
	GameState.spend_money(cost)
	for id in materials:
		owner.remove_item(id, int(materials[id]))
	Notify.say("Alat dititipkan ke Empu Bima. Kembali setelah %d hari." % WORK_DAYS)
	return true

func days_remaining(owner: PlayerData) -> int:
	return maxi(0, int(owner.tool_order.get("ready_day", DayCycle.current_day)) - DayCycle.current_day)

func collect_tool(owner: PlayerData) -> bool:
	if owner.tool_order.is_empty() or days_remaining(owner) > 0:
		return false
	var order := owner.tool_order.duplicate()
	var id := str(order["next"])
	if owner.add_item(id, 1) != 0:
		Notify.say("Tas penuh. Kosongkan satu slot untuk mengambil alat.")
		return false
	owner.tool_order.clear()
	tool_upgraded.emit(str(order["old"]), id)
	var tool := GameState._resolve_item(id).action_data.tool_data
	Juice.play_upgrade_reward(tool.tier)
	Notify.say("%s selesai ditempa!" % tool.display_name)
	return true

func load_order(owner: PlayerData, value: Variant) -> void:
	owner.load_tool_order(value)
