extends VBoxContainer

const Config = preload("res://scripts/resources/cooking_debug_config.gd")
const Actions = preload("res://scripts/system/cooking_debug_actions.gd")

@export_file("*.tres") var config_path := "res://resources/cooking/debug/cooking_debug_config.tres"

var config: Config

@onready var _recipes: OptionButton = %DebugRecipe
@onready var _batches: SpinBox = %DebugBatches
@onready var _stamina: SpinBox = %DebugStamina
@onready var _status: Label = %DebugStatus

var _menu: CanvasLayer
var _original_equipment: Array[CookingEquipmentData] = []

func _ready() -> void:
	if not OS.is_debug_build():
		hide()
		return
	config = load(config_path) as Config
	if not Actions.enabled(config):
		hide()
		return
	_batches.value = config.default_batches
	_stamina.value = config.default_stamina_percent
	if config.catalog.recipes != null:
		for recipe in config.catalog.recipes.recipes:
			if recipe != null:
				_recipes.add_item(recipe.display_name)
				_recipes.set_item_metadata(_recipes.item_count - 1, recipe.id)
	%DebugPrepare.pressed.connect(_prepare)
	%DebugUnlock.pressed.connect(_unlock)
	%DebugUnlockAll.pressed.connect(_unlock_all)
	%DebugGiveOutput.pressed.connect(_give_output)
	%DebugCook.pressed.connect(_cook)
	%DebugEat.pressed.connect(_eat)
	%DebugAllEquipment.pressed.connect(_equipment.bind(&"all"))
	%DebugRequiredEquipment.pressed.connect(_equipment.bind(&"required"))
	%DebugNoEquipment.pressed.connect(_equipment.bind(&"none"))
	%DebugRestoreEquipment.pressed.connect(_equipment.bind(&"restore"))
	%DebugSetStamina.pressed.connect(_set_stamina)
	%DebugClearEffects.pressed.connect(_clear_effects)
	%DebugExpandBag.pressed.connect(_expand_bag)
	%DebugGold.pressed.connect(_gold)

func bind(menu: CanvasLayer) -> void:
	_menu = menu
	_original_equipment.assign(menu.available_equipment)

func is_enabled() -> bool:
	return Actions.enabled(config)

func _can_act() -> bool:
	return is_enabled() and is_instance_valid(_menu) and is_instance_valid(_menu.player)

func _recipe() -> RecipeData:
	if _recipes.selected < 0:
		return null
	return CookingManager.get_recipe(str(_recipes.get_item_metadata(_recipes.selected)))

func _report(result: Dictionary) -> void:
	_status.text = result.message
	if is_instance_valid(_menu):
		_menu._queue_refresh()

func _prepare() -> void:
	if _can_act():
		_report(Actions.prepare_ingredients(_menu.player.data, _recipe(), int(_batches.value), config))

func _unlock() -> void:
	if _can_act():
		_report(Actions.unlock_recipe(_menu.player.data, _recipe(), config))

func _unlock_all() -> void:
	if _can_act():
		_report(Actions.unlock_all(_menu.player.data, config))

func _give_output() -> void:
	if _can_act():
		_report(Actions.give_output(_menu.player.data, _recipe(), config))

func _cook() -> void:
	if not _can_act() or _recipe() == null:
		return
	_menu._act(_recipe().id, false)
	_status.text = _menu._status.text

func _eat() -> void:
	if not _can_act() or _recipe() == null:
		return
	var data: PlayerData = _menu.player.data
	var item := _recipe().result_item()
	for slot in data.bag_size:
		if data.inventory[slot] != null and data.inventory[slot].item.item_id == item.item_id:
			_report(CookingManager.eat(_menu.player, slot))
			return
	_status.text = "Masak atau tambahkan hasil resep terlebih dahulu."

func _equipment(mode: StringName) -> void:
	if not _can_act():
		return
	if mode == &"required" and _recipe() == null:
		return
	_menu.available_equipment.clear()
	match mode:
		&"all": _menu.available_equipment.assign(config.catalog.equipment)
		&"required": _menu.available_equipment.assign(_recipe().required_equipment)
		&"restore": _menu.available_equipment.assign(_original_equipment)
	_report({"ok": true, "message": "Alat sesi dapur: %d. Konfigurasi scene tidak berubah." % _menu.available_equipment.size()})

func _set_stamina() -> void:
	if _can_act():
		_report(Actions.set_stamina(_menu.player.data, _stamina.value, config))

func _clear_effects() -> void:
	if _can_act():
		_report(Actions.clear_effects(_menu.player, config))

func _expand_bag() -> void:
	if _can_act():
		_report(Actions.expand_bag(_menu.player.data, config))

func _gold() -> void:
	if _can_act():
		_report(Actions.grant_gold(config))
