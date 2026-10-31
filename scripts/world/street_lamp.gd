extends Node2D
## Lampu jalan: frame 0 = mati, frame 1 = menyala. Menyala dan memancarkan
## cahaya (PointLight2D "Light") saat malam, seperti lampu dekorasi farm.

@export var base_energy: float = 0.7
@export var flicker_amount: float = 0.06

@onready var _art: Sprite2D = $Art
@onready var _light: PointLight2D = $Light

var _phase: float = 0.0
var _night := false


func _ready() -> void:
	_phase = randf() * TAU
	_set_night(DayCycle.night_intensity() > 0.0)


func _process(_delta: float) -> void:
	var night := DayCycle.night_intensity() > 0.0
	if night != _night:
		_set_night(night)
	if _night and flicker_amount > 0.0:
		_light.energy = base_energy + sin(Time.get_ticks_msec() * 0.006 + _phase) * flicker_amount


# Puluhan lampu di Town: tulis frame/light hanya saat siang<->malam berganti,
# bukan tiap frame (set_frame selalu memicu redraw).
func _set_night(night: bool) -> void:
	_night = night
	_art.frame = 1 if night else 0
	_light.enabled = night
	_light.energy = base_energy
