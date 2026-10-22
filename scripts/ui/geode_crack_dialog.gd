extends AcceptDialog

## Pecah geoda di Pandai Besi (GDD 9): daftar geoda di tas, tombol pecah berbayar, dan
## isi geoda terakhir. Tombol "Upgrade Alat" membuka layar upgrade biasa.
## Pakai GeodeCrack.open(...) lewat preload; game dijeda (solo) atau pemain dikunci (co-op).

const GeodeDataScript = preload("res://scripts/data/geode_data.gd")
const CaveConfirm = preload("res://scripts/ui/cave_confirm_dialog.gd")

signal upgrade_requested

var _player: Player
var _rng := RandomNumberGenerator.new()
var _rows: VBoxContainer
var _result_icon: TextureRect
var _result_label: Label
var _money_label: Label
var _closing := false

static func has_geodes(player: Player) -> bool:
	_bind(player)
	for geode in GeodeDataScript.all():
		if GameState.has_item(geode.item_id):
			return true
	return false

static func open(player: Player, vendor_name: String) -> AcceptDialog:
	var dialog = load("res://scripts/ui/geode_crack_dialog.gd").new()
	dialog._player = player
	dialog.title = vendor_name
	Coop.ui_parent(player).add_child(dialog)
	dialog.popup_centered(Vector2i(460, 0))
	dialog._focus_first()
	return dialog

func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	exclusive = true
	theme = CaveConfirm._make_theme()
	ok_button_text = "Selesai"
	add_button("Upgrade Alat", true, "upgrade")
	custom_action.connect(_on_custom_action)
	confirmed.connect(_finish)
	canceled.connect(_finish)
	_rng.randomize()

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	var intro := Label.new()
	intro.text = "Bawa geodamu, kupecahkan dengan palu. Isinya bisa permata, mineral, atau bijih."
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.custom_minimum_size.x = 420
	box.add_child(intro)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 4)
	box.add_child(_rows)
	var result := HBoxContainer.new()
	result.add_theme_constant_override("separation", 8)
	_result_icon = TextureRect.new()
	_result_icon.custom_minimum_size = Vector2(32, 32)
	_result_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_result_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_result_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	result.add_child(_result_icon)
	_result_label = Label.new()
	_result_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.add_child(_result_label)
	box.add_child(result)
	_money_label = Label.new()
	box.add_child(_money_label)

func _ready() -> void:
	Coop.set_menu_open(_player, true)
	_refresh()

func _refresh() -> void:
	for child in _rows.get_children():
		child.queue_free()
	_money_label.text = "Uang: %d G" % GameState.money
	_use_player()
	var any := false
	for geode in GeodeDataScript.all():
		var count := GameState.get_item_count(geode.item_id)
		if count <= 0:
			continue
		any = true
		var item := GameState._resolve_item(geode.item_id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var icon := TextureRect.new()
		icon.texture = item.icon if item != null else null
		icon.custom_minimum_size = Vector2(32, 32)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		row.add_child(icon)
		var label := Label.new()
		label.text = "%s x%d" % [item.display_name if item != null else geode.item_id, count]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var button := Button.new()
		button.text = "Pecah (%d G)" % geode.crack_price
		button.disabled = GameState.money < geode.crack_price
		button.pressed.connect(crack.bind(geode.item_id))
		row.add_child(button)
		_rows.add_child(row)
	if not any:
		var empty := Label.new()
		empty.text = "Tidak ada geoda di tas."
		_rows.add_child(empty)

## Pecah satu geoda milik pemain. Mengembalikan isi {"item_id", "amount"} atau {} bila gagal.
func crack(geode_id: String) -> Dictionary:
	var geode = GeodeDataScript.find(geode_id)
	_use_player()
	if geode == null or not GameState.has_item(geode_id):
		return {}
	if not GameState.spend_money(geode.crack_price):
		_result_label.text = "Uangmu belum cukup."
		return {}
	GameState.remove_item(geode_id, 1)
	SkillSystem.gain(null, &"miner", SkillSystem.RULES.geode_exp)
	var result: Dictionary = geode.roll(_rng)
	var leftover := int(GameState.add_item(result.item_id, result.amount))
	if leftover > 0 and is_instance_valid(_player):
		ItemPickup.drop_from(_player, result.item_id, leftover)
	var item := GameState._resolve_item(result.item_id)
	_result_icon.texture = item.icon if item != null else null
	_result_label.text = "Isinya: %d %s!" % [result.amount, item.display_name if item != null else result.item_id]
	if leftover > 0:
		_result_label.text += " Tas penuh, sisanya jatuh di dekatmu."
	Juice.play_sound(&"item_drop")
	_refresh()
	_focus_first.call_deferred()
	return result

func _focus_first() -> void:
	for row in _rows.get_children():
		for child in row.get_children():
			if child is Button and not child.disabled and not child.is_queued_for_deletion():
				child.grab_focus()
				return
	get_ok_button().grab_focus()

func _use_player() -> void:
	_bind(_player)

## Arahkan API tas GameState ke pemain ini (co-op), atau P1 bila tidak ada.
static func _bind(player: Player) -> void:
	if is_instance_valid(player):
		GameState.use_player(player)
	else:
		GameState.use_player(GameState.p1())

func _on_custom_action(action: StringName) -> void:
	if action == &"upgrade":
		_finish()
		upgrade_requested.emit()

func _finish() -> void:
	if _closing:
		return
	_closing = true
	Coop.set_menu_open(_player, false)
	hide()
	queue_free()
