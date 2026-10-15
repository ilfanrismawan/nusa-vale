class_name KitchenStation
extends Area2D

func _ready() -> void:
	set_meta("player_interaction", true)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(30, 24)
	shape.shape = rect
	add_child(shape)
	var sprite := Sprite2D.new()
	sprite.texture = preload("res://assets/farm_rpg/objects/Work Benches/Kitchen pot.png")
	sprite.position.y = -10
	add_child(sprite)
	var label := Label.new()
	label.text = "Dapur Warung"
	label.position = Vector2(-36, -42)
	label.add_theme_font_override("font", preload("res://assets/fonts/m5x7.ttf"))
	label.add_theme_font_size_override("font_size", 12)
	add_child(label)

func interact(player: Player) -> void:
	if player.is_input_locked():
		return
	var menu := preload("res://scripts/ui/cooking_ui.gd").new()
	menu.player = player
	Coop.ui_parent(player).add_child(menu)
