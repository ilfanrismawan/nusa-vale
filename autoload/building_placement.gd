extends Node

const FARM := "res://scenes/world/farm.tscn"
var session: Dictionary = {}
var _opening := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func begin(player: Player, item_id: String, from_inventory: bool = false) -> bool:
	if not session.is_empty() or not is_instance_valid(player) or not StructureManager.CONSTRUCTION.has(item_id):
		Notify.say("Selesaikan penempatan bangunan yang sedang aktif dahulu.")
		return false
	var world := player.world_root()
	var source := FARM if world.get_meta("structure_area", "") == "farm" else world.scene_file_path
	session = {"index": player.player_index, "item": item_id, "inventory": from_inventory, "source": source, "position": player.global_position}
	if world.get_meta("structure_area", "") == "farm":
		_open(player)
	else:
		Transition.scene_transition(FARM, player)
	return true

func _process(_delta: float) -> void:
	if session.is_empty() or _opening or Transition.on_transition:
		return
	var player: Player = null
	if Coop.has_root():
		var index := int(session.index)
		if Coop.root._busy[index]:
			return
		player = Coop.root.body_of(index)
	else:
		var world := get_tree().current_scene
		if world != null:
			for candidate in world.find_children("*", "CharacterBody2D", true, false):
				if candidate is Player:
					player = candidate
					break
	if is_instance_valid(player) and player.world_root().get_meta("structure_area", "") == "farm":
		_open(player)

func _open(player: Player) -> void:
	_opening = true
	var menu = load("res://scripts/ui/building_placement_ui.gd").new()
	menu.player = player
	menu.item_id = str(session.item)
	menu.from_inventory = bool(session.inventory)
	Coop.ui_parent(player).add_child(menu)

func finish(player: Player) -> void:
	var previous := session.duplicate()
	session.clear()
	_opening = false
	if previous.is_empty() or previous.source.is_empty() or previous.source == FARM:
		return
	if Coop.has_root():
		Coop.root.move_player(player, str(previous.source), previous.position)
	else:
		GameState.next_spawn_position = previous.position
		GameState.has_spawn_point = true
		Transition.scene_transition(str(previous.source), player)
