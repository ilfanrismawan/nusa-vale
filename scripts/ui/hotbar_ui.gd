extends CanvasLayer

signal slot_clicked(index: int)
@onready var slot_container: HBoxContainer = $"MarginContainer/HBoxContainer"

var slots: Array[TextureRect] = []
var frames: Array[Panel] = []
var active_index: int = 0

const SLOT_SIZE := 28  # pixel, kecil untuk pixel art game

func setup(actions: Array[ActionData]) -> void:			
	# Hapus slot lama
	for child in slot_container.get_children():
		child.queue_free()
	slots.clear()
	frames.clear()
	
	
	# Buat slot baru per action
	for i in actions.size():
		var action := actions[i]

		# Frame (background kotak)
		var frame := Panel.new()
		frame.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)

		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.1, 0.1, 0.15, 0.85)
		style.border_width_bottom = 2
		style.border_width_top = 2
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_color = Color(0.3, 0.3, 0.35)
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_left = 4
		style.corner_radius_bottom_right = 4
		frame.add_theme_stylebox_override("panel", style)
		
		frame.mouse_filter = Control.MOUSE_FILTER_STOP
		var slot_idx := i
	
		frame.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				slot_clicked.emit(slot_idx))

		# Icon di dalam frame
		var tex := TextureRect.new()
		tex.texture = action.icon
		tex.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

		frame.add_child(tex)
		slot_container.add_child(frame)
		slots.append(tex)
		frames.append(frame)

	highlight_slot(0)

func highlight_slot(index: int) -> void:
	active_index = index
	for i in frames.size():
		var style: StyleBoxFlat = frames[i].get_theme_stylebox("panel")
		if i == index:
			style.border_color = Color(1.0, 0.85, 0.2)  # kuning/emas
		else:
			style.border_color = Color(0.3, 0.3, 0.35)
