extends PanelContainer
## Tab Hewan di buku inventory (GDD 4.10.14): halaman kiri daftar peliharaan dan ternak per kandang
## dengan ikon tugas hari ini, halaman kanan detail hewan terpilih (tahap, kasih sayang, tugas,
## info jenis dari resources/animals). Hanya dilihat; data dari AnimalBook.
## Filter = tab ikon di tepi kiri luar buku (seperti Crafting): semua, belum dirawat, hasil siap,
## peliharaan, Kandang Unggas, Barn. Daftar panjang dibagi halaman; atas di baris pertama /
## bawah di baris terakhir membalik halaman, jadi gamepad tidak perlu ke tombol < >.

@export var row_scene: PackedScene = preload("res://scenes/ui/animal_book_row.tscn")
@export var heart_icon: Texture2D = preload("res://resources/ui/icon_tab_heart.tres")
## Baris (judul kandang + hewan) per halaman daftar; buku tidak memakai scroll.
@export_range(3, 12) var rows_per_page := 10
@export var title_color := Color(0.25, 0.14, 0.08, 1)
@export var muted_color := Color(0.45, 0.31, 0.2, 1)
@export var todo_color := Color(0.62, 0.22, 0.14, 1)
@export var filter_hover_color := Color(1.08, 1.05, 1.0)

const NEED_NAMES := {"feed": "Makan", "pet": "Elus", "brush": "Sikat", "sick": "Obat", "product": "Hasil"}
## Urutan sama dengan tab di FilterTabsContainer.
const FILTERS := ["all", "todo", "ready", "pet", "chicken_coop", "barn"]
const EMPTY_TEXT := {
	"all": "Belum ada hewan. Beli ternak di toko Eep atau pilih peliharaan saat membuat karakter.",
	"todo": "Semua hewan sudah dirawat hari ini.",
	"ready": "Belum ada hasil yang siap diambil.",
	"pet": "Belum ada peliharaan.",
	"chicken_coop": "Belum ada hewan di Kandang Unggas.",
	"barn": "Belum ada hewan di Barn.",
}

var inventory_ui: CanvasLayer
var _entries: Array[Dictionary] = []
var _shown: Array[Dictionary] = []
var _filter := "all"
var _page := 0
var _selected := ""
var _group := ButtonGroup.new()
var _filters: Array[TextureButton] = []


func _ready() -> void:
	_filters.assign(%FilterTabsContainer.get_children())
	for index in _filters.size():
		var tab := _filters[index]
		tab.pressed.connect(_set_filter.bind(FILTERS[index]))
		tab.mouse_entered.connect(func(): tab.modulate = filter_hover_color)
		tab.mouse_exited.connect(func(): tab.modulate = Color.WHITE)
	%PrevPage.pressed.connect(_turn.bind(-1))
	%NextPage.pressed.connect(_turn.bind(1))
	DayCycle.day_passed.connect(func(_day: int):
		if is_visible_in_tree():
			refresh())


## Dipanggil buku inventory setiap kali tab dibuka.
func refresh() -> void:
	_entries = AnimalBook.entries()
	_apply_filter()
	_focus_selected.call_deferred()


func _set_filter(filter: String) -> void:
	_filter = filter
	_page = 0
	_apply_filter()


func _apply_filter() -> void:
	_shown = AnimalBook.filtered(_entries, _filter)
	for index in _filters.size():
		_filters[index].set_pressed_no_signal(FILTERS[index] == _filter)
	var todo := 0
	for entry in _entries:
		todo += 1 if entry.todo else 0
	%Title.text = "Hewan %d · belum dirawat %d" % [_entries.size(), todo]
	if _shown.filter(func(entry: Dictionary) -> bool: return entry.key == _selected).is_empty():
		_selected = _shown[0].key if not _shown.is_empty() else ""
	_build_list()
	_show_detail()


## Daftar dibagi per halaman: judul kandang diulang di awal halaman bila kandangnya berlanjut.
func _pages() -> Array:
	var pages: Array = []
	var current: Array = []
	var group := ""
	for entry in _shown:
		var needs_header: bool = entry.group != group or current.is_empty()
		if current.size() + (2 if needs_header else 1) > rows_per_page:
			pages.append(current)
			current = []
			needs_header = true
		if needs_header:
			current.append({"header": entry.group})
		group = entry.group
		current.append(entry)
	if not current.is_empty():
		pages.append(current)
	return pages


func _build_list() -> void:
	for child in %List.get_children():
		%List.remove_child(child)
		child.queue_free()
	var pages := _pages()
	_page = clampi(_page, 0, maxi(0, pages.size() - 1))
	if not pages.is_empty() and not _on_page(pages[_page]):
		for index in pages.size():
			if _on_page(pages[index]):
				_page = index
	%Empty.visible = pages.is_empty()
	%Empty.text = EMPTY_TEXT[_filter]
	%Pager.visible = pages.size() > 1
	%PageLabel.text = "%d/%d" % [_page + 1, maxi(1, pages.size())]
	%PrevPage.disabled = _page <= 0
	%NextPage.disabled = _page >= pages.size() - 1
	if pages.is_empty():
		return
	for item in pages[_page]:
		if item.has("header"):
			var header := Label.new()
			header.text = item.header
			header.add_theme_color_override("font_color", muted_color)
			header.clip_text = true
			%List.add_child(header)
			continue
		var row := row_scene.instantiate() as AnimalBookRow
		row.button_group = _group
		%List.add_child(row)
		row.setup(item)
		row.button_pressed = item.key == _selected
		row.pressed.connect(_select.bind(item.key))
		row.focus_entered.connect(_select.bind(item.key))
		row.gui_input.connect(_row_input.bind(item.key))


func _on_page(page: Array) -> bool:
	for item in page:
		if item.get("key", "") == _selected:
			return true
	return false


## Atas di baris pertama / bawah di baris terakhir: balik halaman daftar.
func _row_input(event: InputEvent, key: String) -> void:
	var rows := %List.get_children().filter(func(node: Node) -> bool: return node is AnimalBookRow)
	if rows.is_empty():
		return
	var pages := _pages()
	if event.is_action_pressed(&"ui_down") and rows[-1].key == key and _page < pages.size() - 1:
		_turn(1)
		accept_event()
	elif event.is_action_pressed(&"ui_up") and rows[0].key == key and _page > 0:
		_turn(-1, true)
		accept_event()


## Balik halaman dan pilih hewan pertama (atau terakhir, saat naik dari atas daftar).
func _turn(step: int, select_last := false) -> void:
	var pages := _pages()
	_page = clampi(_page + step, 0, maxi(0, pages.size() - 1))
	var keys: Array = []
	for item in (pages[_page] if not pages.is_empty() else []):
		if item.has("key"):
			keys.append(item.key)
	if not keys.is_empty():
		_selected = keys[-1] if select_last else keys[0]
	_build_list()
	_show_detail()
	_focus_selected.call_deferred()


func _select(key: String) -> void:
	if key == _selected:
		return
	_selected = key
	for row in %List.get_children():
		if row is AnimalBookRow:
			row.set_pressed_no_signal(row.key == key)
	_show_detail()


func _focus_selected() -> void:
	for row in %List.get_children():
		if row is AnimalBookRow and row.key == _selected and is_visible_in_tree():
			row.grab_focus()
			return


func _show_detail() -> void:
	var entry: Dictionary = {}
	for candidate in _shown:
		if candidate.key == _selected:
			entry = candidate
	%Detail.visible = not entry.is_empty()
	if entry.is_empty():
		return
	%Portrait.texture = entry.portrait
	%AnimalName.text = entry.name
	%Species.text = "%s · %s" % [entry.species, entry.group]
	%Stage.text = entry.stage
	var max_affection := maxi(1, int(entry.max_affection))
	var hearts := int(entry.affection) * 5 / max_affection
	for index in %Hearts.get_child_count():
		var heart := %Hearts.get_child(index) as TextureRect
		heart.texture = heart_icon
		heart.modulate = Color.WHITE if index < hearts else Color(0.45, 0.31, 0.2, 0.35)
	%Affection.text = "%d/%d" % [int(entry.affection), max_affection]
	_fill_needs(entry.needs)
	for child in %Info.get_children():
		%Info.remove_child(child)
		child.queue_free()
	for pair in entry.info:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		%Info.add_child(row)
		var key_label := _label(str(pair[0]), muted_color)
		key_label.custom_minimum_size.x = 62
		row.add_child(key_label)
		var value := _label(str(pair[1]), title_color)
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		value.clip_text = true
		value.tooltip_text = str(pair[1])
		value.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(value)
	%Description.text = entry.description


func _fill_needs(needs: Array) -> void:
	for child in %Needs.get_children():
		%Needs.remove_child(child)
		child.queue_free()
	var shown := 0
	for need in needs:
		if not NEED_NAMES.has(need.kind):
			continue
		shown += 1
		var done: bool = bool(need.done) and need.kind != "product"
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(AnimalBookRow.CELL, AnimalBookRow.CELL)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.texture = AnimalBookRow.need_icon(need)
		%Needs.add_child(icon)
		%Needs.add_child(_label(NEED_NAMES[need.kind], muted_color if done else todo_color))
	if shown == 0:
		%Needs.add_child(_label("Tidak ada tugas", muted_color))


func _label(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return label
