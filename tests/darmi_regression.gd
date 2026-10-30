extends Node
## Mbah Darmi (sesepuh desa): muncul di kota, berkenalan, lalu menceritakan hantu dan
## penangkalnya bertahap mengikuti hati.

const ID := "darmi"
## Event cerita per hati dan kata kunci yang harus disebut.
const LORE := {
	"darmi_intro": [0, ["Mbah Darmi", "api", "lampu"]],
	"darmi_ghost_kuntilanak": [1, ["Kuntilanak", "Pocong", "tatap"]],
	"darmi_ghost_genderuwo": [2, ["Genderuwo", "diam", "Banaspati", "Kemenyan"]],
	"darmi_ghost_tuyul": [3, ["Tuyul", "Sesajen Penangkal Tuyul"]],
	"darmi_ghost_sundel": [4, ["Sundel Bolong", "Leak", "api unggun"]],
	"darmi_ghost_bekal": [5, ["Wedang Kantil", "Jimat Penolak", "Keris Pusaka"]],
	"darmi_ghost_penunggu": [6, ["altar", "Kemenyan", "Tugu Pagar Gaib"]],
	"darmi_ghost_kliwon": [7, ["Jumat Kliwon", "ketukan"]],
	"darmi_ghost_catatan": [8, ["Catatan Gaib", "Mustika Pemberani"]],
}

var failures := 0

func check(ok: bool, message: String) -> void:
	if ok:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func capture(filename: String) -> void:
	if OS.get_cmdline_user_args().has("--capture-darmi"):
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://scratch")
		get_viewport().get_texture().get_image().save_png("res://scratch/" + filename)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_environment("NUSA_SAVE_AUDIT") != "1" or not OS.get_user_data_dir().replace("\\", "/").contains("nusa-save-audit-"):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	GameState.new_game()
	var definition: Dictionary = NPCDatabase.residents.get(ID, {})
	check(not definition.is_empty() and definition.name == "Mbah Darmi" and bool(definition.anchored), "Mbah Darmi is a registered, seated resident")
	var frames: SpriteFrames = load(definition.visual.sprite_frames)
	check(frames != null and frames.has_animation(&"idle_down") and not frames.get_frame_texture(&"idle_down", 0).get_image().is_invisible(), "Mbah Darmi has her own sprite frames")
	var portrait: Texture2D = load(definition.visual.portrait)
	check(portrait != null and portrait.get_width() == 192 and portrait.get_height() == 64, "portrait sheet has neutral, happy and worried faces")
	for id: String in LORE:
		var event: Dictionary = {}
		for raw: Dictionary in definition.heart_events:
			if raw.id == id:
				event = raw
		var text := " ".join(event.get("lines", []).map(func(line: Dictionary) -> String: return str(line.text)))
		var words: Array = LORE[id][1]
		check(int(event.get("hearts", -1)) == int(LORE[id][0]) and words.all(func(word: String) -> bool: return text.contains(word)), "%s at %d hearts explains %s" % [id, LORE[id][0], ", ".join(words)])

	DayCycle.current_day = 3
	DayCycle.hour = 10
	DayCycle.minute = 0
	DayCycle.is_running = false
	GameState.weather.current = "sunny"
	var town: Node2D = load("res://scenes/world/town.tscn").instantiate()
	get_tree().root.add_child(town)
	get_tree().current_scene = town
	await get_tree().physics_frame
	await get_tree().physics_frame
	var presenter := town.get_node("NPCMapPresenter")
	var mbah: VillageNPC = presenter.actors.get(ID)
	var marker := town.get_node_or_null("NPCPoints/darmi_porch") as Node2D
	check(mbah != null and marker != null and mbah.global_position.distance_to(marker.global_position) < 2.0, "Mbah Darmi sits at her porch in town")
	var player := town.find_child("CharacterBody2D", true, false) as Player
	if mbah == null or marker == null or player == null:
		check(false, "town scene has Mbah Darmi and a player")
		_finish(town)
		return
	player.set_process(false)
	player.set_physics_process(false)
	player.global_position = mbah.global_position + Vector2(0, 16)
	await capture("darmi-town.png")
	var data := player.data
	var points := town.get_node("NPCPoints")
	# Perkenalan langsung di obrolan pertama, lalu satu cerita tiap tingkat hati.
	var order := LORE.keys()
	for index in order.size():
		var id: String = order[index]
		NPCSocialService.points(data, ID)
		data.friendships[ID].points = int(LORE[id][0]) * NPCSocialService.POINTS_PER_HEART
		var found := NPCEventService.find_event(data, ID, "town", points, player.global_position, mbah.global_position)
		check(found.get("id", "") == id, "%s is the next story at %d hearts" % [id, LORE[id][0]])
		if found.is_empty():
			continue
		if index == 0:
			mbah._show_packet(NPCDialogueResolver.packet(found.lines, data), player, found)
			var dialog: NPCDialogUI = mbah._dialog_ui
			for line in dialog.lines.size():
				dialog._advance_dialog()
			check(data.completed_events.has(id), "the introduction is told through Mbah Darmi's real dialogue")
		else:
			NPCEventService.complete(data, found)
		check(NPCEventService.find_event(data, ID, "town", points, player.global_position, mbah.global_position).is_empty(), "%s is not repeated before the next heart" % id)
	check(NPCSocialService.points(data, ID) >= 0 and str(definition.dialogue_by_hearts.get("2", [""])[0]).contains("Kemenyan"), "daily chat keeps reminding the ward for her heart level")
	var tier_text := str(load("res://resources/horror/profiles/tier_2.tres").notify_reached)
	check(tier_text.begins_with("Mbah Darmi berpesan"), "horror tier messages come from Mbah Darmi")
	_finish(town)

func _finish(town: Node) -> void:
	get_tree().current_scene = self
	town.queue_free()
	await get_tree().process_frame
	GameState.new_game()
	await get_tree().create_timer(0.5, true).timeout
	print("DARMI REGRESSION COMPLETE: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
