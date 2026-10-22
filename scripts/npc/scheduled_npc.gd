extends VillageNPC

var definition: Dictionary = {}
var _service_menu: CanvasLayer
var waypoint_radius := 2.0
var _offscreen := false

func _exit_tree() -> void:
	if is_instance_valid(_service_menu):
		_service_menu.queue_free()
	if is_instance_valid(_dialog_ui):
		_dialog_ui.queue_free()

func _service_available() -> bool:
	var service := str(definition.get("service", ""))
	if service not in ["carpenter", "shipping", "livestock"]:
		return false
	var rules: Dictionary = definition.get("service_rules", {})
	var activities: Array = rules.get("available_activities", [])
	if not activities.is_empty() and _current_activity not in activities:
		return false

	var days := ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]
	var weekday: String = days[posmod(DayCycle.current_day - 1,7 )]
	for closed_day in rules.get("closed_days", []):
		if str(closed_day).to_lower() == weekday:
			return false
	return true

func _open_resident_dialog(player: Player) -> void:
	if _current_activity == "at_home" and player.data.household.get("npc", "") == npc_id and bool(player.data.household.get("celebrated", false)):
		var greeting := "Sarapan sudah kusiapkan. Cek kotak surat sebelum berangkat, ya." if DayCycle.hour < 9 else "Selamat pulang. Senang bisa berbagi rumah dan cerita denganmu."
		_show_packet(NPCDialogueResolver.packet([greeting], player.data), player)
		return
	var world := get_parent().get_parent()
	var presenter := world.get_node_or_null("NPCMapPresenter")
	var map_id: String = str(presenter.map_id) if presenter != null else ""
	var points := world.get_node_or_null("NPCPoints")
	var event: Dictionary = NPCEventService.find_event(player.data, npc_id, map_id, points, player.global_position, global_position)
	var packet: Dictionary
	if event.is_empty():
		packet = NPCDialogueResolver.resolve(player.data, npc_id, _current_activity)
	else:
		packet = NPCDialogueResolver.packet(event.get("lines", []), player.data)
	_show_packet(packet, player, event)

func _show_packet(packet: Dictionary, player: Player, event: Dictionary = {}) -> void:
	if packet.lines.is_empty():
		return
	var ui := load("res://scenes/ui/npc_dialog_ui.tscn").instantiate() as NPCDialogUI
	_dialog_ui = ui
	ui.player = player
	ui.npc_name = npc_name
	ui.social_npc_id = npc_id
	ui.role_title = role_title
	ui.portrait_texture = portrait
	ui.portrait_expressions = portrait_expressions
	ui.lines = packet.lines
	ui.line_expressions = packet.expressions
	ui.allow_gifts = event.is_empty()
	ui.award_friendship = event.is_empty()
	ui.finished.connect(func():
		if ui.completed and not event.is_empty():
			if event.has("relationship_status"):
				NPCSocialService.commit_relationship(player.data, npc_id, event.relationship_status)
			elif event.has("ceremony"):
				NPCHousehold.celebrate(player.data, npc_id)
			elif event.has("roommate"):
				if not NPCHousehold.prepare(player.data, npc_id, "roommate"):
					Notify.say("Undangan belum dapat diterima.")
			elif event.has("letter_id"):
				Notify.say(NPCHousehold.claim_letter(player.data, event.letter_id).message)
			else:
				NPCEventService.complete(player.data, event)
		_on_dialog_finished()
	)
	Coop.ui_parent(player).add_child(ui)

func _ready() -> void:
	definition = NPCDatabase.residents.get(npc_id, {})
	if not definition.is_empty():
		npc_name = definition.name
		role_title = definition.role
		walk_speed = float(definition.move_speed)
		waypoint_radius = float(definition.get("waypoint_radius", 2.0))
		var initial := NPCDialogueResolver.packet(definition.get("dialogue", {}).get("default", []), null)
		dialog_lines = initial.lines
		$AnimatedSprite2D.sprite_frames = load(definition.visual.sprite_frames)
		if not str(definition.visual.portrait).is_empty():
			portrait = load(definition.visual.portrait)
		var cell_size := int(definition.visual.get("portrait_cell_size", 64))
		var regions: Dictionary = definition.visual.get("expressions", {})
		for expression: String in regions:
			var cell: Array = regions[expression]
			if portrait == null or cell.size() != 2 or cell_size <= 0:
				continue
			var region := Rect2(float(cell[0]) * cell_size, float(cell[1]) * cell_size, cell_size, cell_size)
			if not Rect2(Vector2.ZERO, portrait.get_size()).encloses(region):
				push_warning("Portrait expression outside sheet: " + npc_id + "/" + expression)
				continue
			var texture := AtlasTexture.new()
			texture.atlas = portrait
			texture.region = region
			portrait_expressions[expression] = texture
		activity_expressions = definition.get("dialogue_expressions", {})
	set_meta("player_interaction", true)
	super._ready()
	# Authored roads may cross; residents must not block each other at gateways.
	collision_layer = 0

func _update_presence() -> void:
	var hidden_activities: Array = definition.get("offscreen_activities", [])
	var hidden := _active_path.is_empty() and not _is_walking and _current_activity in hidden_activities
	if hidden == _offscreen:
		return
	_offscreen = hidden
	visible = not hidden
	collision_mask = 0 if hidden else 1
	interaction_area.set_deferred("monitoring", not hidden)
	if hidden:
		_players.clear()

func _physics_process(delta: float) -> void:
	_update_presence()
	if _offscreen:
		velocity = Vector2.ZERO
		return
	if is_instance_valid(_service_menu) or is_instance_valid(_dialog_ui):
		velocity = Vector2.ZERO
		return
	# Follow authored roads without VillageNPC's five-second teleport fallback.
	if _active_path.is_empty():
		_is_walking = false
		velocity = Vector2.ZERO
		_play_facing_idle(_desired_facing)
		return
	var offset := _active_path[0] - global_position
	if offset.length() <= waypoint_radius:
		_active_path.pop_front()
		_is_walking = not _active_path.is_empty()
		velocity = Vector2.ZERO
		return
	velocity = offset.normalized() * minf(walk_speed, offset.length() / maxf(delta, 0.001))
	move_and_slide()
	_update_walk_animation(offset.normalized())

func interact(player: Player = null) -> void:
	if not visible:
		return
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
	_service_menu.service = str(definition.get("service", "")) if _service_available() else ""
	_service_menu.romance_action = NPCSocialService.relationship_action(player.data, npc_id)
	if _current_activity == "at_home" and NPCHousehold.ceremony_ready(player.data, npc_id):
		_service_menu.household_action = "Rayakan Tinggal Bersama" if player.data.household.mode == "roommate" else "Mulai Upacara Pernikahan"
	elif NPCHousehold.roommate_available(player.data, npc_id):
		_service_menu.household_action = "Undang sebagai Teman Sekamar"
	_service_menu.letter_available = not NPCEventService.pending_letter(player.data, npc_id).is_empty()
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
	_service_menu.get_parent().remove_child(_service_menu)
	_service_menu.queue_free()
	_service_menu = null
	if player == null:
		return
	if index == 0:
		_open_resident_dialog(player)
	elif index == 3:
		var status := NPCSocialService.relationship_action(player.data, npc_id)
		var allowed := NPCSocialService.can_relationship(player.data, npc_id, status)
		var key := ("confession_accept" if status == "dating" else "marriage_accept") if allowed else "confession_too_early"
		var dialogue: Dictionary = definition.get("romance_dialogue", {})
		var fallback := ["Aku juga merasakan hal yang sama."] if allowed else ["Aku belum siap. Mari saling mengenal lebih dahulu."]
		var packet := NPCDialogueResolver.packet(dialogue.get(key, fallback), player.data)
		_show_packet(packet, player, {"relationship_status": status} if allowed else {"kind": "notice"})
	elif index == 5:
		if _current_activity == "at_home" and NPCHousehold.ceremony_ready(player.data, npc_id):
			var spouse: bool = player.data.household.mode == "spouse"
			var lines := ["Hari ini kita berkumpul untuk merayakan ikatan yang tumbuh di Nusa Vale.", "Di rumah ini kita akan saling menjaga, berbagi pekerjaan, dan menyambut hari baru bersama.", "Dengan disaksikan keluarga dan sahabat, kita memulai kehidupan bersama."] if spouse else ["Terima kasih sudah mengundangku. Kita tetap sahabat, dan sekarang berbagi rumah.", "Mari saling membantu dan menjaga rumah ini bersama."]
			_show_packet(NPCDialogueResolver.packet(lines, player.data), player, {"ceremony": true})
		elif NPCHousehold.roommate_available(player.data, npc_id):
			_show_packet(NPCDialogueResolver.packet(["Aku senang menjadi teman sekamarmu. Aku akan mampir besok untuk merayakannya."], player.data), player, {"roommate": true})
	elif index == 4:
		var letter := NPCEventService.pending_letter(player.data, npc_id)
		if not letter.is_empty():
			_show_packet(NPCDialogueResolver.packet([str(letter.subject), str(letter.body)], player.data), player, {"letter_id": letter.id})
	elif index == 1 and _service_available():
		var service := str(definition.get("service", ""))
		if service == "carpenter":
			_service_menu = load("res://scenes/ui/carpenter_menu.tscn").instantiate()
			_service_menu.player = player
			_service_menu.vendor_name = npc_name
			_service_menu.vendor_portrait = portrait
			_service_menu.social_npc_id = npc_id
			_service_menu.finished.connect(func(): _service_menu = null)
			Coop.ui_parent(player).add_child(_service_menu)
		elif service == "livestock":
			_service_menu = load("res://scenes/ui/livestock_shop_ui.tscn").instantiate()
			_service_menu.player = player
			_service_menu.portrait = portrait
			var rules: Dictionary = definition.get("service_rules", {})
			var presentation_path := str(rules.get("presentation", ""))
			if not presentation_path.is_empty():
				_service_menu.presentation = load(presentation_path)
			_service_menu.closed.connect(func(): _service_menu = null)
			Coop.ui_parent(player).add_child(_service_menu)
		elif service == "shipping":
			var packet := NPCDialogueResolver.packet(
			[
			"Aku mampir ke kotak pengiriman kebun pukul 17.00–17.30, termasuk saat hujan.",
			"Untuk saat ini, hasil jualan tetap diproses saat kamu tidur. Kunjunganku belum mengubah waktu penjualan."
			], player.data)
			_show_packet(packet, player)
