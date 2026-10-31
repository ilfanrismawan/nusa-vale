class_name FoodEffectList
extends VBoxContainer

## Daftar buff (hijau, panah naik) dan debuff (merah, panah turun) sebuah makanan.
## Ikon, warna, dan font diedit pada baris template BuffRow / DebuffRow di
## scenes/ui/food_effect_list.tscn; script hanya menduplikasinya per baris efek.

## > 0 menimpa ukuran font template (mis. panel kecil di inventory).
@export var font_size := 0
## > 0 menimpa ukuran ikon template.
@export var icon_size := Vector2.ZERO
## > 0 = panel sempit: paling banyak sekian baris, satu baris per efek (dipotong "…"),
## sisanya diringkas menjadi "+N efek lain" dengan tooltip. Debuff selalu ikut tampil.
@export var max_rows := 0
## Teks saat barang tidak punya efek makan. Kosong = daftar disembunyikan.
@export var empty_text := ""

func show_item(item: ItemData) -> void:
	var buff_row := get_node("BuffRow") as Control
	var debuff_row := get_node("DebuffRow") as Control
	buff_row.hide()
	debuff_row.hide()
	for child in get_children():
		if child != buff_row and child != debuff_row:
			remove_child(child)
			child.queue_free()
	var lines: Array[Dictionary] = []
	if item != null:
		lines = item.effect_lines()
	visible = not lines.is_empty() or not empty_text.is_empty()
	if lines.is_empty() and not empty_text.is_empty():
		_neutral_row(buff_row, empty_text, "")
	if max_rows > 0 and lines.size() >= 2 and lines[0].get("instant", false) and lines[1].get("instant", false):
		lines[0] = {"text": "%s, %s" % [lines[0].text, lines[1].text], "positive": true, "tooltip": lines[0].tooltip}
		lines.remove_at(1)
	var hidden: Array[Dictionary] = []
	if max_rows > 0 and lines.size() > max_rows:
		var buffs := lines.filter(func(line): return line.positive)
		var debuffs := lines.filter(func(line): return not line.positive)
		var room := max_rows - 1
		var debuff_count := mini(debuffs.size(), maxi(1, room / 2) if not debuffs.is_empty() else 0)
		var buff_count := mini(buffs.size(), room - debuff_count)
		debuff_count = mini(debuffs.size(), room - buff_count)
		var shown := buffs.slice(0, buff_count) + debuffs.slice(0, debuff_count)
		hidden.assign(buffs.slice(buff_count) + debuffs.slice(debuff_count))
		lines.assign(shown)
	for line in lines:
		_add_row(buff_row if line.positive else debuff_row, line.text, line.get("tooltip", ""))
	if not hidden.is_empty():
		var rest: PackedStringArray = []
		for line in hidden:
			rest.append(("▲ " if line.positive else "▼ ") + line.text)
		_neutral_row(buff_row, "+%d efek lain" % hidden.size(), "\n".join(rest))

func _neutral_row(template: Control, text: String, tooltip: String) -> void:
	var row := _add_row(template, text, tooltip)
	row.get_node("Icon").hide()
	row.modulate = Color(1, 1, 1, 0.6)

func _add_row(template: Control, text: String, tooltip: String) -> Control:
	var row := template.duplicate() as Control
	var label := row.get_node("Text") as Label
	label.text = text
	if font_size > 0:
		label.add_theme_font_size_override("font_size", font_size)
	if max_rows > 0:
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.clip_text = true
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if icon_size != Vector2.ZERO:
		(row.get_node("Icon") as Control).custom_minimum_size = icon_size
	row.tooltip_text = tooltip if not tooltip.is_empty() else text
	row.show()
	add_child(row)
	return row
