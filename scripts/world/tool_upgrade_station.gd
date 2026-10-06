class_name ToolUpgradeStation
extends StaticBody2D

@onready var interaction_area: Area2D = get_node_or_null("InteractionArea")

var _player_in_range := false
var _player: Player = null

func _ready() -> void:
	if interaction_area != null:
		interaction_area.body_entered.connect(_on_body_entered)
		interaction_area.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		_player_in_range = true
		_player = body

func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		_player_in_range = false
		_player = null

func _unhandled_input(event: InputEvent) -> void:
	if _player_in_range and (event.is_action_pressed("interact") or event.is_action_pressed("ui_accept")):
		get_viewport().set_input_as_handled()
		upgrade_current_tool(_player)

func upgrade_current_tool(player: Player) -> void:
	if player == null:
		return

	var tool_controller := player.tool_controller
	if tool_controller == null:
		return

	var item := tool_controller.current_item

	if item == null:
		Notify.say("Pilih alat di hotbar terlebih dahulu.")
		return

	if not item.is_tool():
		Notify.say("Item yang dipilih bukan alat.")
		return

	var success: bool = ToolUpgradeManager.upgrade_tool(item.item_id)
	if success:
		tool_controller.select_tool(tool_controller.current_index)
