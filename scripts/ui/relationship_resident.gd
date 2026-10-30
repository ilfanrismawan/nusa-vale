class_name RelationshipResidentRow
extends Button

@onready var portrait: TextureRect = %Portrait
@onready var name_label: Label = %NameLabel
@onready var status_label: Label = %StatusLabel
@onready var hearts_container: GridContainer = %HeartsContainer
@onready var gift_check_1: Label = %GiftCheck1
@onready var gift_check_2: Label = %GiftCheck2
@onready var talk_check: Label = %TalkCheck

@onready var _name_bounds: Rect2 = name_label.get_rect()

var npc_id: String = ""

const HEART_ICON := preload("res://resources/ui/icon_tab_heart.tres")

func setup(id: String, display_name: String, portrait_tex: Texture2D, points: int, max_hearts: int, romance_status: String, gifts_this_week: int, talked_today: bool, is_romanceable: bool) -> void:
	npc_id = id
	name = id
	tooltip_text = "%s\nHadiah minggu ini: %d/2\nBicara hari ini: %s\nKlik untuk membuka detail" % [display_name, gifts_this_week, "Sudah" if talked_today else "Belum"]
	if is_instance_valid(portrait):
		portrait.texture = portrait_tex
	%PortraitInitial.visible = portrait_tex == null
	%PortraitInitial.text = display_name.left(1).to_upper()
	if is_instance_valid(name_label):
		name_label.text = display_name
		var font := name_label.get_theme_font("font")
		name_label.add_theme_font_size_override("font_size", 16)
		var wrap_flags := TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
		var text_scale := 1.0
		while text_scale > 0.4 and font.get_multiline_string_size(display_name, HORIZONTAL_ALIGNMENT_LEFT, _name_bounds.size.x / text_scale, 16, -1, wrap_flags).y * text_scale > _name_bounds.size.y:
			text_scale -= 0.05
		name_label.position = _name_bounds.position
		name_label.size = _name_bounds.size / text_scale
		name_label.scale = Vector2.ONE * text_scale

	if is_instance_valid(status_label):
		var status_text := romance_status if not romance_status.is_empty() else ("Lajang" if is_romanceable else "")
		status_label.text = status_text

	if is_instance_valid(hearts_container):
		var current_hearts := floori(float(points) / NPCSocialService.POINTS_PER_HEART)
		var child_count := hearts_container.get_child_count()
		for i in 10:
			var heart: TextureRect
			if i < child_count:
				heart = hearts_container.get_child(i) as TextureRect
			else:
				heart = TextureRect.new()
				heart.texture = HEART_ICON
				heart.custom_minimum_size = Vector2(7, 5)
				heart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				heart.mouse_filter = Control.MOUSE_FILTER_IGNORE
				hearts_container.add_child(heart)

			if i < current_hearts:
				heart.modulate = (Color(0.88, 0.32, 0.45) if is_romanceable else Color(0.77, 0.55, 0.25))
			elif i < max_hearts:
				heart.modulate = Color(0.48, 0.35, 0.26, 0.45)
			else:
				heart.modulate = Color(0.35, 0.25, 0.20, 0.25)

	if is_instance_valid(gift_check_1):
		gift_check_1.text = "%d/2" % gifts_this_week
		gift_check_1.modulate = Color(0.22, 0.65, 0.25, 1.0) if gifts_this_week >= 1 else Color(0.55, 0.42, 0.30, 0.8)
	if is_instance_valid(gift_check_2):
		gift_check_2.text = "☒" if gifts_this_week >= 2 else "☐"
		gift_check_2.modulate = Color(0.22, 0.65, 0.25, 1.0) if gifts_this_week >= 2 else Color(0.55, 0.42, 0.30, 0.8)

	if is_instance_valid(talk_check):
		talk_check.text = "%d/1" % int(talked_today)
		talk_check.modulate = Color(0.22, 0.65, 0.25, 1.0) if talked_today else Color(0.55, 0.42, 0.30, 0.8)
