extends Node

signal tool_upgraded(old_tool_id: String, new_tool_id: String)

const TOOL_UPGRADES := {
	"axe": {
		"next": "axe_copper",
		"cost": 500,
		"materials": {
			"copper_bar": 5,
			"wood": 10
		}
	},

	"axe_copper": {
		"next": "axe_iron",
		"cost": 1000,
		"materials": {
			"iron_bar": 5,
			"wood": 15
		}
	},

	"pickaxe": {
		"next": "pickaxe_copper",
		"cost": 500,
		"materials": {
			"copper_bar": 5,
			"wood": 10
		}
	},

	"pickaxe_copper": {
		"next": "pickaxe_iron",
		"cost": 1000,
		"materials": {
			"iron_bar": 5,
			"wood": 15
		}
	}
}

func can_upgrade(tool_id: String) -> bool:
	return TOOL_UPGRADES.has(tool_id)

func get_upgrade_data(tool_id: String) -> Dictionary:
	return TOOL_UPGRADES.get(tool_id, {})

func upgrade_tool(tool_id: String) -> bool:
	if not can_upgrade(tool_id):
		Notify.say("Alat ini sudah level maksimal.")
		return false
	
	var data: Dictionary = TOOL_UPGRADES[tool_id]
	
	var money_cost: int = data["cost"]
	
	if GameState.money < money_cost:
		Notify.say("Uang tidak cukup.")
		return false
	
	var materials: Dictionary = data["materials"]
	
	for item_id in materials:
		var required: int = materials[item_id]
		
		if not GameState.has_item(item_id, required):
			Notify.say("Material tidak cukup.")
			return false
	
	GameState.spend_money(money_cost)
	
	for item_id in materials:
		GameState.remove_item(
			item_id,
			int(materials[item_id])
		)
	
	var new_tool_id: String = str(data["next"])
	
	var replaced := GameState.replace_tool(
		tool_id,
		new_tool_id
	)
	
	if not replaced:
		Notify.say("Tool tidak ditemukan.")
		return false
		
	tool_upgraded.emit(
		tool_id,
		str(data["next"])
	)
	
	Notify.say(
		"Berhasil mendapatkan %s!"
		% new_tool_id
		)
	
	return true
