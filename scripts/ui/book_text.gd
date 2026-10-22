extends Control
## All text stays accessible through discrete pages, without scroll or truncation.
var text := "":
	set(value):
		if text == value: return
		text = value
		_page = 0
		if is_node_ready(): _paginate()
var _pages: Array[String] = []
var _page := 0

func _ready() -> void:
	$Navigation/Previous.pressed.connect(_change.bind(-1))
	$Navigation/Next.pressed.connect(_change.bind(1))
	resized.connect(_paginate)
	_paginate.call_deferred()

func _paginate() -> void:
	if not is_node_ready(): return
	var body := $Body as Label
	var font := body.get_theme_font("font")
	var font_size := body.get_theme_font_size("font_size")
	var width := maxf(1.0, size.x)
	var line_height := font.get_height(font_size) + body.get_theme_constant("line_spacing")
	var capacity := maxi(1, floori(maxf(1.0, size.y - 22.0) / maxf(1.0, line_height)))
	var lines: PackedStringArray = []
	for paragraph in text.split("\n"):
		var line := ""
		for word in paragraph.split(" ", false):
			var candidate := word if line.is_empty() else line + " " + word
			if font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= width:
				line = candidate
				continue
			if not line.is_empty():
				lines.append(line)
				line = ""
			if font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= width:
				line = word
				continue
			# Only unusually long words require character-level wrapping.
			for character in word:
				if not line.is_empty() and font.get_string_size(line + character, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width:
					lines.append(line)
					line = ""
				line += character
		lines.append(line)
	_pages.clear()
	for start in range(0, lines.size(), capacity):
		_pages.append("\n".join(lines.slice(start, mini(start + capacity, lines.size()))))
	if _pages.is_empty(): _pages.append("")
	_page = clampi(_page, 0, _pages.size() - 1)
	_render()

func _change(direction: int) -> void:
	_page = clampi(_page + direction, 0, _pages.size() - 1)
	_render()

func _render() -> void:
	$Body.text = _pages[_page]
	$Navigation.visible = _pages.size() > 1
	$Navigation/Page.text = "%d / %d" % [_page + 1, _pages.size()]
	$Navigation/Previous.disabled = _page == 0
	$Navigation/Next.disabled = _page == _pages.size() - 1
