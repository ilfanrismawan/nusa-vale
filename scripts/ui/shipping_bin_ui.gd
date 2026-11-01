class_name ShippingBinUI
extends CanvasLayer
## Buku Shipping Bin (GDD 4.7). Halaman kiri: isi tas, pilih barang + jumlah lalu Titip.
## Halaman kanan: Kotak Kiriman hari ini. Titipan boleh diambil lagi sampai Ubay mengangkut
## (pukul 17.00) atau sampai tidur; uangnya dibayar saat tidur. Daftar dipakai bersama di co-op.
## Tata letak, warna, dan teks ada di scenes/ui/shipping_bin_ui.tscn dan
## resources/ui/shipping_bin_theme.tres; script ini hanya mengisi data.

signal closed

const HUD = preload("res://scenes/ui/hud.gd")
## preload, bukan class_name, supaya jalan walau cache kelas editor belum diperbarui.
const BagSlot = preload("res://scripts/ui/shipping_bag_slot.gd")
const BinRow = preload("res://scripts/ui/shipping_bin_row.gd")

@export var design_size := Vector2(854, 480)
## Bila layar lebih besar dari design_size, skala dibulatkan ke bawah agar piksel tetap tajam.
@export var integer_scale := true
@export var row_scene: PackedScene = preload("res://scenes/ui/shipping_bin_row.tscn")
## Shift + tombol -/+ mengubah jumlah sebanyak ini.
@export var big_step := 10
@export var hints_keyboard := "[E] Titip   [R] Titip semua   [Q] Ambil lagi   [Esc] Tutup"
@export var hints_gamepad := "(A) Titip   (R3) Titip semua   (Y) Ambil lagi   (B) Tutup"
@export var empty_selection_text := "Pilih barang dari tas."
@export var unsellable_text := "Tidak bisa dijual"

## Pemain yang membuka kotak (tasnya yang ditampilkan).
var player: Player
## Shipping Bin yang dibuka (untuk animasi tutup memantul). Boleh kosong.
var bin: Node

var _opened := false
var _refresh_pending := false
var _category: int = ItemData.Category.ALL
var _page := 0
var _selected := -1
var _amount := 1
var _visible: Array[int] = []

@onready var _design: Control = $Design
@onready var _slot_grid: GridContainer = %SlotGrid
@onready var _categories: Container = %Categories
@onready var _rows: VBoxContainer = %Rows

func _ready() -> void:
	layer = FarmServiceTheme.LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	if player == null:
		player = Coop.current_player()
	for slot in _slot_grid.get_children():
		if slot is BagSlot:
			slot.pressed.connect(_on_slot_pressed.bind(slot))
			slot.focus_entered.connect(_on_slot_pressed.bind(slot))
			slot.right_clicked.connect(_on_slot_right_clicked.bind(slot))
	for chip in _categories.get_children():
		if chip is BaseButton:
			chip.pressed.connect(_on_category.bind(chip))
	%Minus.pressed.connect(func(): _step(-1))
	%Plus.pressed.connect(func(): _step(1))
	%All.pressed.connect(_select_all_amount)
	%Ship.pressed.connect(func(): _ship(_amount))
	%PrevPage.pressed.connect(func(): _turn_page(-1))
	%NextPage.pressed.connect(func(): _turn_page(1))
	%Close.pressed.connect(close)
	GameState.inventory_changed.connect(_queue_refresh)
	GameState.shipping.changed.connect(_queue_refresh)
	get_viewport().size_changed.connect(_resize)
	_opened = true
	Coop.set_menu_open(player, true)
	_resize()
	_refresh()
	var first := _slot_grid.get_child(0) as Control
	if first != null:
		first.grab_focus()

func _resize() -> void:
	var view := get_viewport().get_visible_rect().size
	var fit := minf(view.x / design_size.x, view.y / design_size.y)
	if integer_scale and fit >= 1.0:
		fit = floorf(fit)
	_design.scale = Vector2.ONE * fit
	_design.position = ((view - design_size * fit) * 0.5).floor()

func _queue_refresh() -> void:
	if _refresh_pending or not _opened:
		return
	_refresh_pending = true
	_refresh.call_deferred()

# ── Isi halaman ─────────────────────────────────────────────────────

func _data() -> PlayerData:
	return player.data if is_instance_valid(player) else GameState.current

func _slot_item(index: int) -> ItemData:
	var data := _data()
	if index < 0 or index >= data.bag_size or index >= data.inventory.size() or data.inventory[index] == null:
		return null
	return data.inventory[index].get("item")

func _slot_count(index: int) -> int:
	return int(_data().inventory[index].get("count", 1)) if _slot_item(index) != null else 0

## Sama dengan aturan mode jual tas: alat dan Biji Daya tidak dijual, harga harus > 0.
static func can_ship(item: ItemData) -> bool:
	if item == null or item.sell_price <= 0 or item.is_tool() or item.category == ItemData.Category.TOOL:
		return false
	return not item.item_id.begins_with("biji_daya_")

func _refresh() -> void:
	_refresh_pending = false
	if not _opened:
		return
	_refresh_bag()
	_refresh_selected()
	_refresh_shipment()
	%Hints.text = hints_gamepad if is_instance_valid(player) and player.input.prefers_pad() else hints_keyboard

func _refresh_bag() -> void:
	var data := _data()
	var used := 0
	_visible.clear()
	for i in data.bag_size:
		var item := _slot_item(i)
		if item != null:
			used += 1
		if _category == ItemData.Category.ALL or (item != null and item.category == _category):
			_visible.append(i)
	%Capacity.text = "%d / %d slot" % [used, data.bag_size]
	var slots := _slot_grid.get_children()
	var per_page := maxi(1, slots.size())
	var pages := maxi(1, ceili(float(_visible.size()) / per_page))
	_page = clampi(_page, 0, pages - 1)
	%PageLabel.text = "Hal %d / %d" % [_page + 1, pages]
	%PrevPage.disabled = _page <= 0
	%NextPage.disabled = _page >= pages - 1
	if _selected >= 0 and _slot_item(_selected) == null:
		_selected = -1
	for k in slots.size():
		var slot := slots[k] as BagSlot
		if slot == null:
			continue
		var at := _page * per_page + k
		var index: int = _visible[at] if at < _visible.size() else -1
		var item := _slot_item(index)
		if item == null:
			slot.clear_item(index)
		else:
			slot.show_item(index, item, _slot_count(index), can_ship(item))
		slot.set_selected(index >= 0 and index == _selected)

func _refresh_selected() -> void:
	var item := _slot_item(_selected)
	var has := item != null
	var sellable := can_ship(item)
	%ItemIcon.texture = item.icon if has else null
	%ItemName.text = item.display_name if has else empty_selection_text
	var count := _slot_count(_selected)
	_amount = clampi(_amount, 1, maxi(1, count))
	var unit := SkillSystem.sell_price(_data(), item, true) if sellable else 0
	if not has:
		%ItemPrice.text = ""
	elif not sellable:
		%ItemPrice.text = unsellable_text
	else:
		var bonus := unit - item.sell_price
		%ItemPrice.text = "%s G / buah" % HUD.format_money(unit) + ("  (+%s G bonus)" % HUD.format_money(bonus) if bonus > 0 else "")
	%Amount.text = str(_amount) if sellable else "-"
	for button in [%Minus, %Plus, %All, %Ship]:
		button.disabled = not sellable
	%Minus.disabled = %Minus.disabled or _amount <= 1
	%Plus.disabled = %Plus.disabled or _amount >= count
	%Ship.text = "Titip %s G" % HUD.format_money(unit * _amount) if sellable else "Titip"

func _refresh_shipment() -> void:
	var shipping: ShippingManager = GameState.shipping
	var focused_row := -1
	var focus_node := get_viewport().gui_get_focus_owner()
	if focus_node != null and _rows.is_ancestor_of(focus_node):
		for child in _rows.get_children():
			if child.is_ancestor_of(focus_node):
				focused_row = child.index
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	var items := 0
	for i in shipping.pending.size():
		var row: Dictionary = shipping.pending[i]
		var line := row_scene.instantiate() as BinRow
		_rows.add_child(line)
		line.setup(row, i, GameState._resolve_item(str(row.id)), i % 2 == 0, shipping.can_take_back(row))
		line.take_back_pressed.connect(_take_back)
		items += int(row.count)
	if focused_row >= 0 and _rows.get_child_count() > 0:
		var keep := _rows.get_child(mini(focused_row, _rows.get_child_count() - 1)) as BinRow
		if keep.take_back_button().visible:
			keep.take_back_button().grab_focus()
	%Empty.visible = shipping.pending.is_empty()
	%Date.text = "%s, Hari %d" % [DayCycle.get_season_display_name(), DayCycle.get_day_of_season()]
	%TotalValue.text = "%s G" % HUD.format_money(shipping.total_pending())
	%Stats.text = "%d item - %d jenis" % [items, shipping.pending.size()]
	var ubay_done := shipping.ubay_day == DayCycle.current_day
	%Note.text = "Ubay sudah mengangkut kiriman hari ini. Titipan baru bisa diambil lagi sampai tidur." if ubay_done else "Bisa diambil lagi sampai Ubay datang (%02d.00) atau kamu tidur." % ShippingManager.UBAY_HOUR
	%PayInfo.text = "Dibayar saat kamu tidur malam ini"
	%CourierInfo.visible = SkillSystem.household(&"shipping_pickups") > 0.0
	%CourierInfo.text = "Kurir Logistik membayar pukul 12.00 & 17.00"

# ── Aksi ────────────────────────────────────────────────────────────

func _on_slot_pressed(slot: BagSlot) -> void:
	if slot.bag_index == _selected:
		return
	_selected = slot.bag_index if _slot_item(slot.bag_index) != null else -1
	_amount = 1
	_queue_refresh()

func _on_slot_right_clicked(slot: BagSlot) -> void:
	_on_slot_pressed(slot)
	if _selected >= 0:
		_ship(1)

func _on_category(chip: BaseButton) -> void:
	_category = int(chip.get_meta(&"category", ItemData.Category.ALL))
	_page = 0
	_queue_refresh()

func _turn_page(step: int) -> void:
	_page += step
	_queue_refresh()

func _step(direction: int) -> void:
	var step := big_step if Input.is_key_pressed(KEY_SHIFT) else 1
	_amount = clampi(_amount + direction * step, 1, maxi(1, _slot_count(_selected)))
	_refresh_selected()

func _select_all_amount() -> void:
	_amount = maxi(1, _slot_count(_selected))
	_refresh_selected()

## Titip `amount` dari slot terpilih. Harga dikunci saat dititip (termasuk bonus role).
func _ship(amount: int) -> bool:
	var item := _slot_item(_selected)
	if not can_ship(item):
		if item != null:
			Notify.say("Barang ini tidak bisa dijual.")
		return false
	var take := clampi(amount, 1, _slot_count(_selected))
	var data := _data()
	if not data.remove_item_at(_selected, take):
		return false
	GameState.shipping.deposit(item, take, data)
	Juice.play_sound(&"bin_close")
	if is_instance_valid(bin) and bin.has_method("bounce"):
		bin.bounce()
	_amount = 1
	_refresh()
	return true

## Ambil lagi satu baris Kotak Kiriman ke tas pemain ini (selama belum diangkut Ubay).
func _take_back(row_index: int) -> void:
	var shipping: ShippingManager = GameState.shipping
	if row_index < 0 or row_index >= shipping.pending.size():
		return
	var row: Dictionary = shipping.pending[row_index]
	if not shipping.can_take_back(row):
		Notify.say("Sudah diangkut Ubay, tidak bisa diambil lagi.")
		return
	var want := int(row.count)
	var got := shipping.take_back(row_index, want, _data())
	if got <= 0:
		Notify.say("Tas penuh.")
		return
	Juice.play_sound(&"bin_open")
	if got < want:
		Notify.say("Tas penuh, %d masih di Shipping Bin." % (want - got))
	_refresh()

## Q / Y: ambil lagi baris terakhir yang belum diangkut.
func _take_back_last() -> void:
	var pending: Array = GameState.shipping.pending
	for i in range(pending.size() - 1, -1, -1):
		if GameState.shipping.can_take_back(pending[i]):
			_take_back(i)
			return
	Notify.say("Tidak ada titipan yang bisa diambil lagi.")

func _input(event: InputEvent) -> void:
	if not _opened or not is_instance_valid(player) or not Coop.accepts_event(player, event):
		return
	var input := player.input
	if input.is_event(event, &"ui_cancel") or input.is_event(event, &"inventory"):
		_handled()
		close()
	elif input.is_event(event, &"sort_inventory"):
		_handled()
		_select_all_amount()
		_ship(_amount)
	elif input.is_event(event, &"crafting_menu") or _is_take_back_key(event):
		_handled()
		_take_back_last()
	elif not event is InputEventMouseButton and input.is_event(event, &"interact"):
		var focus := get_viewport().gui_get_focus_owner()
		if focus is BaseButton and not focus is BagSlot and focus != %Ship:
			_handled()
			if not focus.disabled:
				focus.pressed.emit()
		else:
			_handled()
			_ship(_amount)

func _is_take_back_key(event: InputEvent) -> bool:
	return event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_Q \
		and player.input.device == PlayerInput.DEVICE_KEYBOARD

func _handled() -> void:
	get_viewport().set_input_as_handled()

func close() -> void:
	if not _opened:
		return
	_opened = false
	hide()
	Coop.set_menu_open(player, false)
	closed.emit()
	queue_free()

func _exit_tree() -> void:
	if _opened and is_instance_valid(player):
		Coop.set_menu_open(player, false)
	_opened = false
