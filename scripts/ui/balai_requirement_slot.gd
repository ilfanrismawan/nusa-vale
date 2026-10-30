extends Button
## Kotak kaca satu kebutuhan paket di kartu Balai Nadi.

@export var selected_scale := 1.08

var _target := 1.0

func _ready() -> void:
	pivot_offset = size * 0.5

func set_selected(on: bool) -> void:
	%Glass.glow = 0.9 if on else 0.0
	_target = selected_scale if on else 1.0

func pulse() -> void:
	scale = Vector2.ONE * 1.25

func _process(delta: float) -> void:
	scale = scale.lerp(Vector2.ONE * _target, 1.0 - exp(-delta * 14.0))
