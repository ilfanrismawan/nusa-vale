class_name WorldMapArea
extends Button
## Satu area di Peta Lembah (tab Peta di buku tas). Kotak tombol ini = area yang bisa dipilih
## di atas gambar peta; child "Tag" = papan nama area. Semua data area diisi di Inspector
## (scenes/ui/inventory_world_map.tscn), halaman peta hanya membaca dan menampilkannya.

@export var area_id := ""
@export var display_name := ""
## Baris kecil di bawah nama (mis. "Timur Ladang").
@export var subtitle := ""
@export var icon_texture: Texture2D
## id UnlockManager; kosong = selalu terbuka. id yang tidak dikenal (mis. modern_city) = terkunci.
@export var unlock_id := ""
## Saat terkunci nama diganti "???" (untuk area yang belum diketahui pemain).
@export var hide_name_when_locked := false
@export_multiline var locked_hint := "Area ini belum terbuka."
## Kabut di atas gambar peta yang tampil selama area terkunci.
@export var fog: NodePath
## Awalan path scene yang dihitung sebagai area ini (untuk pin pemain), huruf kecil.
@export var scene_prefixes: PackedStringArray = []
## Nilai "map" jadwal NPC yang dihitung sebagai area ini (untuk daftar warga).
@export var npc_maps: PackedStringArray = []
## id ServiceHours yang ada di area ini (status buka/tutup dihitung saat ini).
@export var services: PackedStringArray = []
## Baris tempat tetap tanpa jam buka (mis. "Rumah & Greenhouse").
@export var places: PackedStringArray = []
## location_id FishingSpot / ForageSpawner di area ini (untuk ikon "Musim ini").
@export var fish_locations: PackedStringArray = []
@export var forage_locations: PackedStringArray = []
## Titik pin pemain, relatif ke kotak area.
@export var pin_point := Vector2(8, 8)
@export var tag_normal: StyleBox
@export var tag_selected: StyleBox
@export var tag_locked: StyleBox
@export var selected_color := Color(1, 0.8, 0.16, 1)
@export var dim_color := Color(0.12, 0.07, 0.04, 0.45)

var selected := false:
	set(value):
		selected = value
		_update_tag()
		queue_redraw()
var dimmed := false:
	set(value):
		dimmed = value
		queue_redraw()


func _ready() -> void:
	_update_tag()


func is_open() -> bool:
	return unlock_id.is_empty() or UnlockManager.is_unlocked(unlock_id)


func shown_name() -> String:
	return "???" if hide_name_when_locked and not is_open() else display_name


func has_tag(tag: String) -> bool:
	match tag:
		"shop":
			return not services.is_empty()
		"fish":
			return not fish_locations.is_empty()
		"forage":
			return not forage_locations.is_empty()
	return false


func matches_scene(path: String) -> bool:
	var p := path.to_lower()
	for prefix in scene_prefixes:
		if not prefix.is_empty() and p.begins_with(prefix.to_lower()):
			return true
	return false


func pin_position() -> Vector2:
	return position + pin_point


func refresh_state() -> void:
	var open := is_open()
	var fog_node := get_node_or_null(fog) as CanvasItem
	if fog_node != null:
		fog_node.visible = not open
	_update_tag()


func _update_tag() -> void:
	var tag := get_node_or_null("Tag") as PanelContainer
	if tag == null:
		return
	var open := unlock_id.is_empty() or (is_inside_tree() and UnlockManager.is_unlocked(unlock_id))
	var style: StyleBox = tag_selected if selected else (tag_normal if open else tag_locked)
	if style != null:
		tag.add_theme_stylebox_override("panel", style)
	var label := tag.get_node_or_null("Name") as Label
	if label != null:
		label.text = shown_name() if is_inside_tree() else display_name
		label.modulate = Color.WHITE if open else Color(0.55, 0.55, 0.62, 1)
	var lock := tag.get_node_or_null("Lock") as CanvasItem
	if lock != null:
		lock.visible = not open and not hide_name_when_locked


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	if dimmed and not selected:
		draw_rect(rect, dim_color)
	if selected:
		draw_rect(rect.grow(-1), selected_color, false, 2.0)
