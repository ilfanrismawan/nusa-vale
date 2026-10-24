extends Container
## Lay out resident cards in two paper halves, reserving the centre binding.
@export_range(2, 6, 2) var columns := 4
@export var card_height := 72.0
@export var horizontal_gap := 8.0
@export var vertical_gap := 6.0
@export var binding_gap := 36.0

func _get_minimum_size() -> Vector2:
	return Vector2(404, 150)

func _notification(what: int) -> void:
	if what != NOTIFICATION_SORT_CHILDREN:
		return
	var per_side := maxi(1, columns / 2)
	var page_width := (size.x - binding_gap) * 0.5
	var card_width := (page_width - horizontal_gap * (per_side - 1)) / per_side
	var index := 0
	for child in get_children():
		if not child is Control or not child.visible:
			continue
		var column := index % columns
		var side := column / per_side
		var x := side * (page_width + binding_gap) + (column % per_side) * (card_width + horizontal_gap)
		var y := (index / columns) * (card_height + vertical_gap)
		fit_child_in_rect(child, Rect2(Vector2(x, y), Vector2(card_width, card_height)))
		index += 1
