extends VillageNPC

var definition: Dictionary = {}
var _service_menu: CanvasLayer

func _exit_tree() -> void:
	if is_instance_valid(_service_menu):
		_service_menu.queue_free()
	if is_instance_valid(_dialog_ui):
		_dialog_ui.queue_free()

func _ready() -> void:
	definition = NPCDatabase.residents.get(npc_id, {})
	if not definition.is_empty():
		npc_name = definition.name
		role_title = definition.role
		walk_speed = float(definition.move_speed)
		dialog_lines = PackedStringArray(definition.dialogue.default)
		$AnimatedSprite2D.sprite_frames = load(definition.visual.sprite_frames)
		if not str(definition.visual.portrait).is_empty():
			portrait = load(definition.visual.portrait)
	set_meta("player_interaction", true)
	super._ready()

func _physics_process(delta: float) -> void:
	if is_instance_valid(_service_menu):
		velocity = Vector2.ZERO
		return
	super._physics_process(delta)

func interact(player: Player = null) -> void:
	if is_instance_valid(_dialog_ui) or is_instance_valid(_service_menu):
		return
	if player == null:
		player = RoomDoor.player()
	if player == null:
		return
	_face_player(player)
	_service_menu = preload("res://scenes/ui/resident_service_menu.tscn").instantiate()
	_service_menu.player = player
	_service_menu.npc_name = npc_name
	_service_menu.role_title = role_title
	_service_menu.portrait = portrait
	_service_menu.service = str(definition.get("service", ""))
	_service_menu.selected.connect(_choose_service.bind(player))
	Coop.ui_parent(player).add_child(_service_menu)

func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(_service_menu):
		if event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			_choose_service(2, RoomDoor.player())
		return
	super._unhandled_input(event)

func _choose_service(index: int, player: Player) -> void:
	# Detach now to release the pause before the next UI takes ownership.
	# Queue deletion so Escape/button callbacks can finish safely.
	_service_menu.get_parent().remove_child(_service_menu)
	_service_menu.queue_free()
	_service_menu = null
	if index == 0:
		super.interact(player)
	elif index == 1 and definition.get("service") == "carpenter":
		_service_menu = load("res://scenes/ui/carpenter_menu.tscn").instantiate()
		_service_menu.player = player
		_service_menu.vendor_name = npc_name
		_service_menu.vendor_portrait = portrait
		_service_menu.finished.connect(func(): _service_menu = null)
		Coop.ui_parent(player).add_child(_service_menu)
	elif index == 1:
		var saved := _schedule_dialog_lines
		_schedule_dialog_lines = PackedStringArray(["Aku mampir ke kotak pengiriman kebun pukul 17.00–17.30, termasuk saat hujan.", "Untuk saat ini, hasil jualan tetap diproses saat kamu tidur. Kunjunganku belum mengubah waktu penjualan."])
		super.interact(player)
		_schedule_dialog_lines = saved
