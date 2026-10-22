class_name Television
extends StaticBody2D

## Objek Televisi di rumah pemain.
## Menampilkan siaran ramalan cuaca (BMKG), tips pedesaan (Living off the Land),
## dan resep masakan harian (Dapur Nusantara).

@onready var interaction_area: Area2D = get_node_or_null("InteractionArea")

var _players: Array[Player] = []
var _ui: Node = null

func _ready() -> void:
	add_to_group("televisions")
	set_meta("player_interaction", true)
	if interaction_area != null:
		interaction_area.body_entered.connect(_on_body_entered)
		interaction_area.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body is Player and not _players.has(body):
		_players.append(body)

func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		_players.erase(body)

func _unhandled_input(event: InputEvent) -> void:
	var player := PlayerInput.find_presser(event, _players)
	if player != null:
		get_viewport().set_input_as_handled()
		interact(player)

## Dipanggil langsung dari Player._try_interact saat pemain menekan tombol interaksi di depan TV.
func interact(player: Player = null) -> void:
	if is_instance_valid(_ui):
		return
	if player == null:
		player = Coop.current_player()
	var ui_script = load("res://scripts/ui/television_ui.gd")
	if ui_script == null:
		return
	_ui = ui_script.new()
	_ui.set("player", player)
	_ui.tree_exiting.connect(func(): _ui = null)
	Coop.ui_parent(player).add_child(_ui)
