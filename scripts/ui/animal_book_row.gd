class_name AnimalBookRow
extends Button
## Satu hewan di halaman kiri tab Hewan: potret, nama, dan ikon tugas hari ini
## (gelembung yang sama dengan penanda di atas kepala; terang = belum, abu-abu = sudah).

const STATUS_SHEET := "res://assets/ranch/animal_status.png"
const CELL := 12
const COLUMNS := {"feed": 0, "pet": 1, "brush": 2, "product": 3}

var key := ""


func setup(entry: Dictionary) -> void:
	key = entry.key
	%Portrait.texture = entry.portrait
	%Name.text = entry.name
	tooltip_text = "%s · %s" % [entry.species, entry.stage]
	for child in %Needs.get_children():
		%Needs.remove_child(child)
		child.queue_free()
	for need in entry.needs:
		if not COLUMNS.has(need.kind):
			continue
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(CELL, CELL)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.texture = need_icon(need)
		%Needs.add_child(icon)


## Ikon gelembung status untuk satu tugas: baris 0 sheet = belum, baris 1 = sudah; hasil = ikon item.
static func need_icon(need: Dictionary) -> Texture2D:
	if need.kind == "product" and need.get("icon") != null:
		return need.icon
	if not COLUMNS.has(need.kind) or not ResourceLoader.exists(STATUS_SHEET):
		return null
	var region := AtlasTexture.new()
	region.atlas = load(STATUS_SHEET)
	region.region = Rect2(int(COLUMNS[need.kind]) * CELL, CELL if need.done else 0, CELL, CELL)
	return region
