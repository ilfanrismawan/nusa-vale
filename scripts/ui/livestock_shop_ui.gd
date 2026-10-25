extends CanvasLayer

const Presentation = preload("res://scripts/resources/livestock_shop_presentation.gd")
const HorseActor = preload("res://scripts/world/horse_actor.gd")
signal closed

@export var presentation: Presentation = preload("res://resources/ui/livestock_shop_presentation.tres")
@export var card_scene: PackedScene = preload("res://scenes/ui/livestock_animal_card.tscn")
@export var swatch_scene: PackedScene = preload("res://scenes/ui/livestock_variant_swatch.tscn")
@export var design_size := Vector2(1280, 960)

var player: Player
var portrait: Texture2D
var _species := "chicken"
var _variant := "white"
var _animal_name := ""
var _target_uid := 0
var _closed := false
var _refresh_pending := false
var _species_order: PackedStringArray = []
var _targets: Array[int] = []
@onready var _status: Label = %Status
@onready var _content: GridContainer = %Cards

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = FarmServiceTheme.LAYER
	%ShopTitle.text = presentation.title
	%VendorName.text = presentation.vendor_name
	%Dialog.text = presentation.greeting
	%GamepadHint.visible = not player.input.uses_mouse()
	%Vendor.texture = presentation.vendor_art if presentation.vendor_art != null else FarmServiceTheme.portrait(portrait)
	%CloseButton.pressed.connect(_close)
	%PurchaseLivestock.pressed.connect(_buy)
	%LivestockHousing.item_selected.connect(_choose_home)
	%AnimalName.text_changed.connect(func(value: String): _animal_name = value)
	GameState.money_changed.connect(_money_changed)
	StructureManager.changed.connect(_queue_refresh)
	get_viewport().size_changed.connect(_resize)
	for kind in presentation.species_order:
		if RanchHusbandry.SPECIES.has(kind) and not _species_order.has(kind) and not presentation.excluded_species.has(kind):
			_species_order.append(kind)
	for kind in RanchHusbandry.SPECIES:
		if not _species_order.has(kind) and not presentation.excluded_species.has(kind):
			_species_order.append(kind)
	_build_cards()
	Coop.set_menu_open(player, true)
	_resize()
	_refresh()

func _resize() -> void:
	var view := get_viewport().get_visible_rect().size
	var fit := minf(view.x / design_size.x, view.y / design_size.y)
	$Design.scale = Vector2.ONE * fit
	$Design.position = (view - design_size * fit) * 0.5

func _build_cards() -> void:
	for kind in _species_order:
		var card := card_scene.instantiate() as Button
		_content.add_child(card)
		card.set_meta("species", kind)
		card.get_node("Price").text = "● %s" % _format_money(int(RanchHusbandry.SPECIES[kind].price))
		card.tooltip_text = str(RanchHusbandry.SPECIES[kind].name)
		card.pressed.connect(_select.bind(kind))
		card.focus_entered.connect(_select.bind(kind))
	for index in maxi(0, presentation.display_slots - _species_order.size()):
		var card := card_scene.instantiate() as Button
		_content.add_child(card)
		card.set_meta("species", "")
		card.disabled = true
		card.modulate.a = 0.55
		card.get_node("Icon").hide()
		card.get_node("Price").hide()
		card.get_node("Lock").show()
		card.tooltip_text = "Belum tersedia"

func _animal_icon(kind: String) -> Texture2D:
	var variant_key := kind + "_" + (_variant if kind == _species else "white")
	if presentation.icon_overrides.has(variant_key):
		return presentation.icon_overrides[variant_key]
	if presentation.icon_overrides.has(kind):
		return presentation.icon_overrides[kind]
	if kind == "horse":
		var coat := RanchHusbandry.horse_coat({"variant": _variant if kind == _species else "bay"})
		return HorseActor.horse_frames(coat).get_frame_texture(&"idle_right", 0)
	return RanchVisual.frames(kind, _variant if kind == _species else "white").get_frame_texture(&"default", 0)

func _queue_refresh() -> void:
	if _refresh_pending or _closed:
		return
	_refresh_pending = true
	_refresh.call_deferred()

func _money_changed(_amount: int) -> void:
	_queue_refresh()

func _refresh() -> void:
	_refresh_pending = false
	if _closed or not RanchHusbandry.SPECIES.has(_species):
		return
	var info: Dictionary = RanchHusbandry.SPECIES[_species]
	%Money.text = "● %s G" % _format_money(GameState.money)
	for card in _content.get_children():
		var kind: String = card.get_meta("species")
		if kind.is_empty():
			continue
		card.set_pressed_no_signal(kind == _species)
		card.get_node("Icon").texture = _animal_icon(kind)
	%Preview.texture = _animal_icon(_species)
	%AnimalTitle.text = str(info.name)
	%HomeType.text = presentation.home_labels.get(str(info.home), str(info.home))
	%Description.text = presentation.descriptions.get(_species, "Hewan dewasa diantar ke kandang pilihan dan membutuhkan perawatan harian.")
	%Production.text = "◷ Panen setiap %d hari" % int(info.interval) if int(info.interval) > 0 else "◷ Tidak menghasilkan barang harian"
	var product := GameState._resolve_item(str(info.product)) if not str(info.product).is_empty() else null
	%ProductIcon.texture = product.icon if product != null else null
	%ProductName.text = "Menghasilkan " + product.display_name if product != null else presentation.descriptions.get(_species + "_role", "Teman ladang")
	%ToolHint.text = "Kualitas hasil meningkat dengan perawatan." if product != null else "Tetap perlu pakan, elusan, dan sikat setiap hari."
	if not str(info.tool).is_empty():
		var tool := GameState._resolve_item(str(info.tool))
		%ToolHint.text = "Perlu " + (tool.display_name if tool != null else str(info.tool)) + " untuk panen."
	_refresh_homes(info)
	_refresh_variants()
	var reason := ""
	if _target_uid == 0:
		reason = "Bangun kandang yang sesuai melalui Pak Damar terlebih dahulu."
	else:
		var state := StructureManager.coop_state(StructureManager.record_for(_target_uid))
		if state.chickens.size() >= RanchHusbandry.capacity(state):
			reason = "Kandang penuh. Pilih kandang lain atau upgrade kapasitasnya."
	if reason.is_empty() and _species == "horse" and StructureManager.count_species("horse") >= RanchHusbandry.HORSE_LIMIT:
		reason = "Kamu sudah punya kuda."
	if reason.is_empty() and GameState.money < int(info.price):
		reason = "Uang bersama belum cukup."
	%Availability.text = reason
	%PurchaseLivestock.text = "%s  Beli · %s G" % ["Enter" if player.input.uses_mouse() else "A", _format_money(int(info.price))]
	%PurchaseLivestock.disabled = not reason.is_empty()

func _refresh_homes(info: Dictionary) -> void:
	var homes: OptionButton = %LivestockHousing
	homes.clear()
	_targets.clear()
	for record in StructureManager.records:
		if record.item != info.home:
			continue
		var state := StructureManager.coop_state(record)
		_targets.append(int(record.uid))
		homes.add_item("%s %d · %d/%d" % [presentation.home_labels.get(str(info.home), "Kandang"), _targets.size(), state.chickens.size(), RanchHusbandry.capacity(state)])
	if not _target_uid in _targets:
		_target_uid = _targets[0] if not _targets.is_empty() else 0
	homes.disabled = _targets.is_empty()
	if _targets.is_empty():
		homes.add_item("Belum ada kandang")
	else:
		homes.select(_targets.find(_target_uid))

func _refresh_variants() -> void:
	for child in %Swatches.get_children():
		%Swatches.remove_child(child)
		child.queue_free()
	var choices: PackedStringArray = presentation.variants.get(_species, PackedStringArray())
	%ColorLabel.text = "Warna" if not choices.is_empty() else "Varian standar"
	for variant in choices:
		var swatch := swatch_scene.instantiate() as Button
		%Swatches.add_child(swatch)
		swatch.get_node("Color").color = presentation.variant_colors.get(variant, Color.WHITE)
		swatch.tooltip_text = presentation.variant_labels.get(variant, variant)
		swatch.set_pressed_no_signal(variant == _variant)
		swatch.pressed.connect(_choose_variant.bind(variant))

func _choose_variant(variant: String) -> void:
	_variant = variant
	_refresh()

func _choose_home(index: int) -> void:
	if index >= 0 and index < _targets.size():
		_target_uid = _targets[index]
	_refresh()

func _select(species: String) -> void:
	if not RanchHusbandry.SPECIES.has(species):
		return
	_species = species
	var choices: PackedStringArray = presentation.variants.get(_species, PackedStringArray())
	if not choices.has(_variant):
		_variant = choices[0] if not choices.is_empty() else "white"
	_refresh()

func _buy() -> void:
	var result := StructureManager.buy_animal(_target_uid, _species, _animal_name, _variant)
	if result.ok:
		_animal_name = ""
		%AnimalName.text = ""
	_refresh()
	_status.text = result.message

func _format_money(amount: int) -> String:
	var digits := str(amount)
	var result := ""
	while digits.length() > 3:
		result = "," + digits.right(3) + result
		digits = digits.left(digits.length() - 3)
	return digits + result

func _input(event: InputEvent) -> void:
	if not is_instance_valid(player):
		return
	if player.input.is_event(event, &"ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()
	elif player.input.uses_mouse() and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_ENTER, KEY_KP_ENTER]:
		if not %AnimalName.has_focus() and not %PurchaseLivestock.disabled:
			_buy()
			get_viewport().set_input_as_handled()
	elif not player.input.uses_mouse():
		if player.input.is_event(event, &"ui_accept"):
			if not %PurchaseLivestock.disabled:
				_buy()
		elif player.input.is_event(event, &"tool_next") or player.input.is_event(event, &"tool_prev"):
			if not _targets.is_empty():
				var direction := 1 if player.input.is_event(event, &"tool_next") else -1
				_choose_home(posmod(_targets.find(_target_uid) + direction, _targets.size()))
		elif player.input.is_event(event, &"inventory"):
			var choices: PackedStringArray = presentation.variants.get(_species, PackedStringArray())
			if not choices.is_empty():
				_choose_variant(choices[posmod(choices.find(_variant) + 1, choices.size())])
		elif not player.input.is_event(event, &"move_up") and not player.input.is_event(event, &"move_down") and not player.input.is_event(event, &"move_left") and not player.input.is_event(event, &"move_right"):
			return
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if not is_instance_valid(player) or player.input.uses_mouse() or _species_order.is_empty():
		return
	var direction := 0
	if player.input.just_pressed(&"move_right"):
		direction = 1
	elif player.input.just_pressed(&"move_left"):
		direction = -1
	elif player.input.just_pressed(&"move_down"):
		direction = _content.columns
	elif player.input.just_pressed(&"move_up"):
		direction = -_content.columns
	if direction != 0:
		_select(_species_order[posmod(_species_order.find(_species) + direction, _species_order.size())])

func _close() -> void:
	if _closed:
		return
	_closed = true
	Coop.set_menu_open(player, false)
	closed.emit()
	queue_free()

func _exit_tree() -> void:
	if not _closed and is_instance_valid(player):
		Coop.set_menu_open(player, false)
