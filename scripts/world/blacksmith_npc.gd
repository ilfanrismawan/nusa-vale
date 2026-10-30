class_name BlacksmithNPC
extends StaticBody2D
const GroundShadow := preload("res://scripts/effects/ground_shadow.gd")

## NPC Pandai Besi di kota (Town).
## Menghadapi pemain dan membuka UI upgrade alat saat diajak bicara.
## Bila pemain membawa geoda, layar pecah geoda muncul dulu (GDD 9).

const GeodeCrack = preload("res://scripts/ui/geode_crack_dialog.gd")

@export var npc_name: String = "Empu Bima"
@export var npc_id: String = "bima"
@export var default_lines: PackedStringArray = [
	"Halo! Selamat datang di bengkel tempa Nusa Vale.",
	"Alat berkebun yang tajam dan kokoh membuat pekerjaanmu jauh lebih ringan.",
	"Jika kamu punya cukup batangan logam dan koin, serahkan padaku untuk kutempa!"
]

@onready var sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")
@onready var interaction_area: Area2D = get_node_or_null("InteractionArea")

var _players: Array[Player] = []
var _ui: ToolUpgradeUI
var _geode_ui: AcceptDialog
var _line_index: int = 0

func _ready() -> void:
	GroundShadow.attach(self)
	if interaction_area != null:
		interaction_area.body_entered.connect(_on_body_entered)
		interaction_area.body_exited.connect(_on_body_exited)
	if sprite != null and sprite.sprite_frames != null and sprite.sprite_frames.has_animation("idle_down"):
		sprite.play("idle_down")

func _on_body_entered(body: Node2D) -> void:
	if body is Player and not _players.has(body):
		_players.append(body)

func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		_players.erase(body)

func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(_ui) or is_instance_valid(_geode_ui):
		return
	var player := PlayerInput.find_presser(event, _players)
	if player != null:
		get_viewport().set_input_as_handled()
		interact(player)

## Dipanggil langsung atau via Player._try_interact()
func interact(player: Player = null) -> void:
	if is_instance_valid(_ui) or is_instance_valid(_geode_ui):
		return
	if player == null:
		player = Coop.current_player() if Coop.active else get_tree().get_first_node_in_group("player")

	_face_player(player)

	if GeodeCrack.has_geodes(player):
		_geode_ui = GeodeCrack.open(player, npc_name)
		_geode_ui.connect("upgrade_requested", _open_upgrade.bind(player))
		return
	_open_upgrade(player)

func _open_upgrade(player: Player) -> void:
	if is_instance_valid(_ui):
		return
	# Buka antarmuka upgrade alat
	_ui = load("res://scenes/ui/tool_upgrade_ui.tscn").instantiate() as ToolUpgradeUI
	_ui.player = player
	_ui.social_npc_id = npc_id
	_ui.finished.connect(func():
		Notify.say("%s: Terima kasih sudah mampir!" % npc_name)
	)
	Coop.ui_parent(player).add_child(_ui)

func _face_player(player: Player) -> void:
	if sprite == null:
		return
	if not (player is CharacterBody2D):
		return
	var dir: Vector2 = player.global_position - global_position
	if abs(dir.x) > abs(dir.y):
		if sprite.sprite_frames != null and sprite.sprite_frames.has_animation("idle_side"):
			sprite.play("idle_side")
		sprite.flip_h = dir.x < 0
	else:
		sprite.flip_h = false
		if sprite.sprite_frames != null:
			if dir.y > 0 and sprite.sprite_frames.has_animation("idle_down"):
				sprite.play("idle_down")
			elif dir.y <= 0 and sprite.sprite_frames.has_animation("idle_up"):
				sprite.play("idle_up")
