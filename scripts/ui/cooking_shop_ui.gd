extends CanvasLayer

@export var offer_row: PackedScene = preload("res://scenes/ui/cooking_shop_offer_row.tscn")
@export var panel_size := Vector2(800, 570)
var player: Player
var store: CookingShopData
var _selected: CookingShopOffer
var _closed := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = FarmServiceTheme.LAYER
	%Title.text = store.display_name
	%Greeting.text = store.greeting
	%Close.pressed.connect(_close)
	%Purchase.pressed.connect(_purchase)
	GameState.money_changed.connect(_money_changed)
	GameState.inventory_changed.connect(_refresh)
	WorldState.flag_changed.connect(_flags_changed)
	Coop.set_menu_open(player, true)
	for offer in store.offers:
		if offer == null:
			continue
		var row := offer_row.instantiate() as Button
		%Offers.add_child(row)
		row.icon = offer.display_icon()
		row.text = offer.display_name
		row.tooltip_text = offer.description
		row.pressed.connect(_select.bind(offer))
	get_viewport().size_changed.connect(_resize)
	_resize.call_deferred()
	if not store.offers.is_empty():
		_select(store.offers[0])
	_refresh()

func _resize() -> void:
	var panel: Control = $Panel
	panel.size = panel_size.max(panel.get_combined_minimum_size())
	var viewport_size := get_viewport().get_visible_rect().size
	var fit := minf(1.0, minf((viewport_size.x - 24.0) / panel.size.x, (viewport_size.y - 24.0) / panel.size.y))
	panel.scale = Vector2.ONE * fit
	panel.position = ((viewport_size - panel.size * fit) * 0.5).floor()

func _select(offer: CookingShopOffer) -> void:
	_selected = offer
	%Preview.texture = offer.display_icon()
	%Details.text = offer.description
	_refresh()

func _refresh() -> void:
	%Money.text = "%d G" % GameState.money
	if _selected == null:
		%Purchase.disabled = true
		return
	var reason := CookingShopService.status(_selected, player.data)
	var materials: PackedStringArray = []
	for item_id in _selected.materials:
		materials.append("%s %d/%d" % [GameState._resolve_item(item_id).display_name, player.data.get_item_count(item_id), _selected.materials[item_id]])
	%Requirements.text = "\n".join(materials) + ("\n" if not materials.is_empty() else "") + reason
	var owned := WorldState.has_flag(_selected.owned_flag)
	%Purchase.text = "Pasang" if owned and not _selected.selection_group.is_empty() else "Beli · %d G" % _selected.price
	%Purchase.disabled = not CookingShopService.can_purchase(_selected, player.data)

func _purchase() -> void:
	var result := CookingShopService.purchase(store, _selected, player.data)
	%Status.text = result.message
	_refresh()

func _money_changed(_money: int) -> void:
	_refresh()

func _flags_changed(_flag: String, _value: bool) -> void:
	_refresh()

func _input(event: InputEvent) -> void:
	if player.input.is_event(event, &"ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()

func _close() -> void:
	if _closed:
		return
	_closed = true
	Coop.set_menu_open(player, false)
	queue_free()

func _exit_tree() -> void:
	if not _closed and is_instance_valid(player):
		Coop.set_menu_open(player, false)
