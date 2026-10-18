extends CanvasLayer

signal selected(index: int)
var player: Player
var npc_name := "Warga Desa"
var role_title := ""
var portrait: Texture2D
var service := ""
@onready var panel: PanelContainer = $Panel

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = FarmServiceTheme.LAYER
	%Speaker.text = npc_name
	%Role.text = role_title
	%Portrait.texture = FarmServiceTheme.portrait(portrait)
	%Service.text = "Bangun / Upgrade" if service == "carpenter" else "Info Pengiriman"
	%Talk.pressed.connect(func(): selected.emit(0))
	%Service.pressed.connect(func(): selected.emit(1))
	%Close.pressed.connect(func(): selected.emit(2))
	get_viewport().size_changed.connect(_resize)
	panel.minimum_size_changed.connect(_resize)
	_resize()
	%Talk.grab_focus()
	Coop.set_menu_open(player, true)

func _resize() -> void:
	var view := get_viewport().get_visible_rect().size
	panel.size = Vector2(480, 360).max(panel.get_combined_minimum_size())
	var fit := minf(1.0, minf(maxf(1, view.x - 24) / panel.size.x, maxf(1, view.y - 24) / panel.size.y))
	panel.scale = Vector2.ONE * fit
	panel.position = ((view - panel.size * fit) * 0.5).floor()

func _input(event: InputEvent) -> void:
	if not Coop.accepts_event(player, event):
		return
	var input := player.input if is_instance_valid(player) else PlayerInput.solo()
	if input.is_event(event, &"ui_cancel"):
		get_viewport().set_input_as_handled()
		selected.emit(2)

func _exit_tree() -> void:
	Coop.set_menu_open(player, false)
