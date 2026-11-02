extends CanvasLayer

signal selected(index: int)
## Id aksi yang dikirim `selected`. Nilainya dipakai tes dan ScheduledNPC; jangan diubah urutannya.
const TALK := 0
const SERVICE := 1
const CLOSE := 2
const ROMANCE := 3
const LETTER := 4
const HOUSEHOLD := 5
const SUPPLIES := 6
## Tombol tebus hewan (layanan "vet"): REDEEM_BASE + indeks di `redeem_options`.
const REDEEM_BASE := 100
var player: Player
var npc_name := "Warga Desa"
var role_title := ""
var portrait: Texture2D
var service := ""
var romance_action := ""
var letter_available := false
var household_action := ""
var supplies_available := false
## [{"label": String}] satu tombol per hewan yang kabur dan dirawat di sini.
var redeem_options: Array = []
@onready var panel: PanelContainer = $Panel

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = FarmServiceTheme.LAYER
	%Speaker.text = npc_name
	%Role.text = role_title
	%Portrait.texture = FarmServiceTheme.portrait(portrait)
	%Service.text = {"carpenter": "Bangun / Upgrade", "shipping": "Info Pengiriman", "livestock": "Beli Hewan Ternak", "blacksmith": "Tempa / Pecah Geoda", "shop": "Beli Makanan / Minuman", "vet": "Beli Obat Ternak"}.get(service, "Layanan")
	%Service.visible = service in ["carpenter", "shipping", "livestock", "blacksmith", "shop", "vet"]
	%Talk.pressed.connect(func(): selected.emit(TALK))
	%Service.pressed.connect(func(): selected.emit(SERVICE))
	%Close.pressed.connect(func(): selected.emit(CLOSE))
	var box := %Talk.get_parent()
	if supplies_available:
		var button := Button.new()
		button.text = "Beli Pakan / Peralatan"
		button.custom_minimum_size.y = 52
		button.pressed.connect(func(): selected.emit(SUPPLIES))
		box.add_child(button)
		box.move_child(button, %Close.get_index())
	for index in redeem_options.size():
		var button := Button.new()
		button.text = str(redeem_options[index].label)
		button.custom_minimum_size.y = 52
		button.pressed.connect(func(): selected.emit(REDEEM_BASE + index))
		box.add_child(button)
		box.move_child(button, %Close.get_index())
	if not romance_action.is_empty():
		var button := Button.new()
		button.text = "Nyatakan Perasaan" if romance_action == "dating" else "Melamar"
		button.custom_minimum_size.y = 52
		button.pressed.connect(func(): selected.emit(ROMANCE))
		box.add_child(button)
		box.move_child(button, %Close.get_index())
	if not household_action.is_empty():
		var button := Button.new()
		button.text = household_action
		button.custom_minimum_size.y = 52
		button.pressed.connect(func(): selected.emit(HOUSEHOLD))
		box.add_child(button)
		box.move_child(button, %Close.get_index())
	if letter_available:
		var button := Button.new()
		button.text = "Baca Surat"
		button.custom_minimum_size.y = 52
		button.pressed.connect(func(): selected.emit(LETTER))
		box.add_child(button)
		box.move_child(button, %Close.get_index())
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
		selected.emit(CLOSE)

func _exit_tree() -> void:
	Coop.set_menu_open(player, false)
