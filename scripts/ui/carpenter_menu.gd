extends CanvasLayer

const ServiceTheme = preload("res://scripts/ui/farm_service_theme.gd")

signal finished
var player: Player
var _content: VBoxContainer
var _closed := false

func _ready() -> void:
	layer = ServiceTheme.LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	var background := ColorRect.new()
	background.color = Color(0, 0, 0, 0.55)
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 240)
	var style := ServiceTheme.frame()
	panel.add_theme_stylebox_override("panel", style)
	var theme := ServiceTheme.make_theme()
	panel.theme = theme
	center.add_child(panel)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 10)
	panel.add_child(_content)
	var title := Label.new()
	title.text = "PERTUKANGAN — PAK DAMAR"
	title.add_theme_font_size_override("font_size", 24)
	_content.add_child(title)
	var money := Label.new()
	money.text = "Uang bersama: %d G · Bahan dari tas P%d" % [GameState.money, player.player_index + 1]
	_content.add_child(money)
	for id in StructureManager.CONSTRUCTION:
		var item := GameState._resolve_item(id)
		var quote: Dictionary = StructureManager.CONSTRUCTION[id]
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", ServiceTheme.dialogue())
		_content.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		card.add_child(row)
		var picture := TextureRect.new()
		picture.texture = item.icon
		picture.custom_minimum_size = Vector2(64, 64)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(picture)
		var detail := VBoxContainer.new()
		detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(detail)
		var name_label := Label.new()
		name_label.text = "%s · %dx%d petak" % [item.display_name, item.placement_size.x, item.placement_size.y]
		name_label.add_theme_font_size_override("font_size", 22)
		detail.add_child(name_label)
		var materials := Label.new()
		materials.text = "%d G · Kayu %d/%d · Batu %d/%d" % [int(quote.money), player.data.get_item_count("wood"), int(quote.materials.wood), player.data.get_item_count("stone"), int(quote.materials.stone)]
		detail.add_child(materials)
		var capacity := Label.new()
		capacity.text = item.description
		capacity.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		capacity.add_theme_font_size_override("font_size", 14)
		detail.add_child(capacity)
		var button := Button.new()
		button.text = "Pilih lokasi"
		button.disabled = GameState.money < int(quote.money) or not player.data.has_item("wood", int(quote.materials.wood)) or not player.data.has_item("stone", int(quote.materials.stone))
		button.tooltip_text = "Siapkan uang, kayu dan batu yang tertera." if button.disabled else "Pilih lokasi; biaya dibayar setelah konfirmasi."
		button.pressed.connect(_choose.bind(str(id)))
		row.add_child(button)
	var hint := Label.new()
	hint.text = "Biaya dan bahan diambil setelah kamu mengonfirmasi lokasi.\nBatal memilih lokasi tidak dikenakan biaya."
	_content.add_child(hint)
	var close := Button.new()
	close.text = "Tutup (Esc)"
	close.pressed.connect(_close)
	_content.add_child(close)
	ServiceTheme.mount(self, panel, Vector2(680, 380))
	Coop.set_menu_open(player, true)

func _choose(id: String) -> void:
	_close()
	BuildingPlacement.begin(player, id)

func _input(event: InputEvent) -> void:
	if player.input.is_event(event, &"ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()

func _close() -> void:
	if _closed:
		return
	_closed = true
	hide()
	Coop.set_menu_open(player, false)
	finished.emit()
	queue_free()
