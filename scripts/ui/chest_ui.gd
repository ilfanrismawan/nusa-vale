extends CanvasLayer

@export var design_size := Vector2(1280, 720)
@export var slot_scene: PackedScene = preload("res://scenes/ui/chest_item_slot.tscn")
var player: Player
var uid := 0
var _opened := false
var _refresh_pending := false
@onready var _panel: Control = $Design
@onready var _status: Label = %Status

func _ready() -> void:
	layer = FarmServiceTheme.LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	%Close.pressed.connect(_close)
	%Pack.pressed.connect(_pack)
	%Upgrade.pressed.connect(_upgrade)
	StructureManager.changed.connect(_queue_refresh)
	GameState.inventory_changed.connect(_queue_refresh)
	get_viewport().size_changed.connect(_resize)
	_opened = true
	Coop.set_menu_open(player, true)
	_resize()
	_refresh()

func _resize() -> void:
	var view := get_viewport().get_visible_rect().size
	var fit := minf(view.x / design_size.x, view.y / design_size.y)
	$Design.scale = Vector2.ONE * fit
	$Design.position = (view - design_size * fit) * 0.5

func _queue_refresh() -> void:
	if _refresh_pending or not _opened:
		return
	_refresh_pending = true
	_refresh.call_deferred()

func _refresh() -> void:
	_refresh_pending = false
	if not _opened:
		return
	var record := StructureManager.record_for(uid)
	if record.is_empty() or not record.item in StructureManager.CHESTS:
		_close()
		return
	var item := GameState._resolve_item(record.item)
	var chest := StructureManager.storage(record)
	%Title.text = item.display_name
	%ChestIcon.texture = item.icon
	%BagTitle.text = "Tas P%d · %d slot" % [player.data.index + 1, player.data.bag_size]
	%ChestTitle.text = "Peti Bersama · Tier %d · %d slot" % [item.chest_tier + 1, chest.bag_size]
	_fill_grid(%BagSlots, player.data, true)
	_fill_grid(%ChestSlots, chest, false)
	var recipe := StructureManager.next_chest_recipe(uid)
	%Upgrade.disabled = recipe == null
	if recipe == null:
		%Upgrade.text = "Tier tertinggi"
		%UpgradeCost.text = "Kapasitas maksimal · %d slot" % chest.bag_size
	else:
		var target := GameState._resolve_item(recipe.output_item_id)
		%Upgrade.text = "Upgrade → %s" % target.display_name
		var costs := PackedStringArray()
		for id in recipe.ingredients:
			var required := int(recipe.ingredients[id])
			var count := player.data.get_item_count(id)
			var material := GameState._resolve_item(id)
			costs.append("%s %d/%d" % [material.display_name, count, required])
			%Upgrade.disabled = %Upgrade.disabled or count < required
		%UpgradeCost.text = "Bahan dari tas P%d: %s" % [player.data.index + 1, " · ".join(costs)]

func _fill_grid(grid: GridContainer, source: PlayerData, deposit: bool) -> void:
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	for index in source.bag_size:
		var button := slot_scene.instantiate() as Button
		grid.add_child(button)
		var entry: Variant = source.inventory[index]
		button.disabled = entry == null
		button.set_meta("slot", index)
		button.set_meta("deposit", deposit)
		if entry == null:
			button.tooltip_text = "Slot kosong"
			continue
		var item: ItemData = entry.item
		button.get_node("Icon").texture = item.icon
		button.get_node("Count").text = str(entry.count)
		button.tooltip_text = "%s ×%d\n%s" % [item.display_name, entry.count, item.description]
		button.pressed.connect(_transfer.bind(index, deposit))
		button.mouse_entered.connect(_show_item.bind(item))
		button.focus_entered.connect(_show_item.bind(item))

func _show_item(item: ItemData) -> void:
	%ItemDetail.text = "%s · %s" % [item.display_name, item.description]

func _transfer(slot: int, deposit: bool) -> void:
	if not _opened:
		return
	var result := StructureManager.transfer(player.data, uid, slot, deposit)
	_queue_refresh()
	_status.text = result.message

func _upgrade() -> void:
	var result := StructureManager.upgrade_chest(player.data, uid)
	_queue_refresh()
	_status.text = result.message

func _pack() -> void:
	var result := StructureManager.pack(player.data, uid)
	if result.ok:
		_close()
	else:
		_status.text = result.message

func _input(event: InputEvent) -> void:
	if not _opened:
		return
	if player.input.is_event(event, &"ui_cancel") or player.input.is_event(event, &"inventory"):
		get_viewport().set_input_as_handled()
		_close()

func _close() -> void:
	if not _opened:
		return
	_opened = false
	hide()
	Coop.set_menu_open(player, false)
	queue_free()

func _exit_tree() -> void:
	if _opened and is_instance_valid(player):
		Coop.set_menu_open(player, false)
	_opened = false
