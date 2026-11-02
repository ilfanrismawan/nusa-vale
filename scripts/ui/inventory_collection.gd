extends PanelContainer
## Penemuan disimpan DiscoveryManager, tetap terbuka setelah item dijual/dibuang.

@export var entry_scene: PackedScene = preload("res://scenes/ui/inventory_collection_entry.tscn")

const CATEGORIES := [ItemData.Category.FISH, ItemData.Category.FORAGE, ItemData.Category.CROP, ItemData.Category.MATERIAL]
var category: ItemData.Category = ItemData.Category.FISH
var catalog: Array[ItemData] = []
var _summary: Label
var _list: GridContainer
var _detail: Control
var _detail_icon: TextureRect
var _filters: Array[TextureButton] = []
## Ikon item yang belum ditemukan tampil sebagai siluet.
const UNKNOWN_TINT := Color(0.32, 0.2, 0.1, 0.3)
var _metadata: Dictionary = {}
var _catalog_loaded := false

func _ready() -> void:
	_summary = %Summary
	_list = %List
	_detail = %Detail
	_detail_icon = %DetailIcon
	_filters.assign(%FilterTabsContainer.get_children())
	for i in _filters.size():
		_filters[i].pressed.connect(_set_category.bind(CATEGORIES[i]))
	DiscoveryManager.discovered.connect(_on_discovered)
	refresh()

func _load_catalog() -> void:
	for folder in ["fish_data", "forage_data"]:
		for file in DirAccess.get_files_at("res://resources/" + folder):
			var name_text := file.trim_suffix(".remap")
			if not name_text.ends_with(".tres"):
				continue
			var resource := load("res://resources/" + folder + "/" + name_text)
			if resource is FishData or resource is ForageData:
				_metadata[resource.item.item_id] = resource
	for file in DirAccess.get_files_at("res://resources/item_data"):
		var name_text := file.trim_suffix(".remap")
		if not name_text.ends_with(".tres"):
			continue
		var item := load("res://resources/item_data/" + name_text) as ItemData
		if item == null or not CATEGORIES.has(item.category):
			continue
		if item.category == ItemData.Category.MATERIAL and not (item.item_id.ends_with("_ore") or item.item_id.ends_with("_bar") or item.item_id in ["stone", "coal"]):
			continue
		catalog.append(item)
	catalog.sort_custom(func(a: ItemData, b: ItemData): return a.display_name.naturalnocasecmp_to(b.display_name) < 0)

func is_known(item: ItemData) -> bool:
	return DiscoveryManager.has_discovered("item_" + item.item_id) or (item.category == ItemData.Category.FISH and DiscoveryManager.has_discovered("fish_" + item.item_id))

func _set_category(value: ItemData.Category) -> void:
	category = value
	%CollectionPager.current_page = 0
	refresh()

func refresh() -> void:
	if not visible or not is_instance_valid(_list):
		return
	if not _catalog_loaded:
		_load_catalog()
		_catalog_loaded = true
	# Migrasi save lama: item yang masih dimiliki semua pemain ikut dicatat.
	for data in GameState.players:
		for slot in data.inventory:
			if slot != null and slot.get("item") != null and CATEGORIES.has(slot.item.category):
				DiscoveryManager.discover("item_" + slot.item.item_id)
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var found := 0
	var total := 0
	for item in catalog:
		if item.category != category:
			continue
		total += 1
		var known := is_known(item)
		if known:
			found += 1
		var button := entry_scene.instantiate() as Button
		button.icon = item.icon
		button.tooltip_text = item.display_name if known else "???"
		if not known:
			for state in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color", "icon_focus_color"]:
				button.add_theme_color_override(state, UNKNOWN_TINT)
		button.pressed.connect(_show_detail.bind(item))
		_list.add_child(button)
	%CollectionPager.refresh()
	_summary.text = "%d / %d ditemukan" % [found, total]
	_detail_icon.texture = null
	_detail.text = "Pilih ikon untuk melihat info. Siluet terbuka saat ditemukan; penemuan dibagi bersama semua pemain."
	for i in range(_filters.size()):
		_filters[i].set_pressed_no_signal(category == CATEGORIES[i])

func _show_detail(item: ItemData) -> void:
	if not is_known(item):
		_detail_icon.texture = null
		_detail.text = "??? Belum ditemukan. Jelajahi dunia untuk membuka catatan ini."
		return
	_detail_icon.texture = item.icon
	var info: Resource = _metadata.get(item.item_id)
	var text := item.description
	if info is FishData:
		text = "Lokasi: %s | %02d:00-%02d:00" % [_pretty(info.locations), info.min_hour, info.max_hour]
	elif info is ForageData:
		text = "Lokasi: %s | %s" % [_pretty(info.locations), "Semua musim" if info.seasons.is_empty() else _pretty(info.seasons)]
	_detail.text = "%s - %d G\n%s" % [item.display_name, item.sell_price, text]

func _on_discovered(_id: String) -> void:
	if visible:
		# Deferred agar migrasi penemuan tidak memanggil refresh secara rekursif.
		if not _refresh_pending:
			_refresh_pending = true
			call_deferred("_refresh_discoveries")

var _refresh_pending := false
func _refresh_discoveries() -> void:
	_refresh_pending = false
	refresh()

## ID data (mis. town_river) jadi teks tampilan (Town River).
func _pretty(ids: PackedStringArray) -> String:
	var names := PackedStringArray()
	for id in ids:
		names.append(id.capitalize())
	return ", ".join(names)
