extends CanvasLayer
const ServiceTheme = preload("res://scripts/ui/farm_service_theme.gd")
signal closed
var player: Player
var portrait: Texture2D
var _content: VBoxContainer
var _status: Label
var _species := "chicken"
var _variant := "white"
var _animal_name := ""
var _target_uid := 0
var _closed := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = ServiceTheme.LAYER
	var panel := PanelContainer.new()
	add_child(panel)
	var layout := VBoxContainer.new()
	panel.add_child(layout)
	var header := HBoxContainer.new()
	layout.add_child(header)
	var picture := TextureRect.new()
	picture.texture = ServiceTheme.portrait(portrait)
	picture.custom_minimum_size = Vector2(48, 48)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header.add_child(picture)
	var heading := Label.new()
	heading.text = "TOKO TERNAK — RIAN\nPilih hewan dan kandang tujuan."
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	header.add_child(_button("Tutup", _close))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_content)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size.y = 32
	layout.add_child(_status)
	ServiceTheme.mount(self, panel, Vector2(620, 440))
	GameState.money_changed.connect(func(_money: int): _refresh())
	StructureManager.changed.connect(_refresh)
	Coop.set_menu_open(player, true)
	_refresh()

func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	button.custom_minimum_size.y = 28
	return button

func _label(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(label)

func _refresh() -> void:
	if _content == null:
		return
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	_label("Uang bersama: %d G" % GameState.money)
	for kind in RanchHusbandry.SPECIES:
		var info: Dictionary = RanchHusbandry.SPECIES[kind]
		var row := HBoxContainer.new()
		_content.add_child(row)
		var picture := Control.new()
		picture.custom_minimum_size = Vector2(40, 40)
		row.add_child(picture)
		var sprite := AnimatedSprite2D.new()
		sprite.sprite_frames = RanchVisual.frames(kind)
		sprite.position = Vector2(20, 20)
		sprite.scale = Vector2(1.5, 1.5)
		picture.add_child(sprite)
		sprite.play()
		var select := _button("%s · %d G%s" % [info.name, int(info.price), " · Dipilih" if kind == _species else ""], _select.bind(str(kind)))
		select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(select)
	var info: Dictionary = RanchHusbandry.SPECIES[_species]
	var homes := OptionButton.new()
	homes.name = "LivestockHousing"
	var targets: Array[int] = []
	for record in StructureManager.records:
		if record.item != info.home:
			continue
		var state := StructureManager.coop_state(record)
		targets.append(int(record.uid))
		homes.add_item("%s %d · %d/%d hewan" % ["Kandang Unggas" if record.item == "chicken_coop" else "Kandang Ternak", targets.size(), state.chickens.size(), RanchHusbandry.capacity(state)])
	if not _target_uid in targets:
		_target_uid = targets[0] if not targets.is_empty() else 0
	if not targets.is_empty():
		homes.select(targets.find(_target_uid))
		homes.item_selected.connect(func(index: int):
			_target_uid = targets[index]
			_refresh())
		_content.add_child(homes)
	else:
		_label("Belum ada kandang yang sesuai. Bangun melalui Pak Damar terlebih dahulu.")
	var form := HBoxContainer.new()
	_content.add_child(form)
	if _species == "chicken":
		var variant := OptionButton.new()
		variant.add_item("Putih")
		variant.add_item("Cokelat")
		variant.select(1 if _variant == "brown" else 0)
		variant.item_selected.connect(func(index: int): _variant = "brown" if index == 1 else "white")
		form.add_child(variant)
	var name_input := LineEdit.new()
	name_input.placeholder_text = "Nama hewan (opsional)"
	name_input.max_length = 16
	name_input.text = _animal_name
	name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_input.text_changed.connect(func(value: String): _animal_name = value)
	form.add_child(name_input)
	var purchase := _button("Beli %s · %d G" % [info.name, int(info.price)], _buy)
	purchase.name = "PurchaseLivestock"
	purchase.disabled = _target_uid == 0 or GameState.money < int(info.price)
	if _target_uid > 0:
		var state := StructureManager.coop_state(StructureManager.record_for(_target_uid))
		purchase.disabled = purchase.disabled or state.chickens.size() >= RanchHusbandry.capacity(state)
	_content.add_child(purchase)
	_status.text = "Hewan dewasa diantar langsung ke kandang pilihan. Pembelian dibatalkan tanpa biaya jika kandang penuh."

func _select(species: String) -> void:
	_species = species
	_refresh()

func _buy() -> void:
	var result := StructureManager.buy_animal(_target_uid, _species, _animal_name, _variant)
	if result.ok:
		_animal_name = ""
	_refresh()
	_status.text = result.message

func _input(event: InputEvent) -> void:
	if is_instance_valid(player) and player.input.is_event(event, &"ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()

func _close() -> void:
	if _closed:
		return
	_closed = true
	Coop.set_menu_open(player, false)
	closed.emit()
	queue_free()
