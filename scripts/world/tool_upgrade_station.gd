class_name ToolUpgradeStation
extends StaticBody2D

func upgrade_current_tool(player: Player) -> void:
	if player == null:
		return
		
	var tool_controller := player.tool_controller
	
	if tool_controller == null:
		return
	
	var item := tool_controller.current_item

	if item == null:
		Notify.say("Pilih alat terlebih dahulu.")
		return
	
	if not item.is_tool():
		Notify.say("Item ini bukan alat.")
		return
	
	var success := ToolUpgradeManager.upgrade_tool(
		item.item_id
	)
	
	if success:
		Notify.say("Upgrade berhasi!")
