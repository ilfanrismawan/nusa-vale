extends Node2D
## Lampu jalan: frame 0 = mati, frame 1 = menyala. Menyala dan memancarkan
## cahaya (PointLight2D "Light") saat malam, seperti lampu dekorasi farm.

@export var base_energy: float = 0.7
@export var flicker_amount: float = 0.06

@onready var _art: Sprite2D = $Art
@onready var _light: PointLight2D = $Light

var _phase: float = 0.0


func _ready() -> void:
	_phase = randf() * TAU
	_update()


func _process(_delta: float) -> void:
	_update()


func _update() -> void:
	var night := DayCycle.night_intensity() > 0.0
	_art.frame = 1 if night else 0
	_light.enabled = night
	if night:
		_light.energy = base_energy + sin(Time.get_ticks_msec() * 0.006 + _phase) * flicker_amount
