extends PointLight2D
## Cahaya yang hanya menyala saat malam (DayCycle.night_intensity() > 0).
## Dipakai untuk cahaya jendela, air mancur, dll. Taruh sebagai anak bangunan
## atau langsung di scene, lalu atur warna/texture/texture_scale di Inspector.

## Energi dasar saat malam.
@export var base_energy: float = 0.7
## Besar kedip acak kecil (0 = stabil, cocok untuk lampu listrik).
@export var flicker_amount: float = 0.0
## Denyut pelan naik-turun (cocok untuk air mancur).
@export var pulse_amount: float = 0.0
@export var pulse_speed: float = 1.5
## Makin malam makin terang (sore redup, tengah malam penuh).
@export var scale_with_night: bool = true

var _phase: float = 0.0


func _ready() -> void:
	_phase = randf() * TAU
	enabled = false


func _process(_delta: float) -> void:
	var night := DayCycle.night_intensity()
	enabled = night > 0.0
	if not enabled:
		return
	var t := Time.get_ticks_msec() * 0.001
	var e := base_energy
	if scale_with_night:
		e *= lerpf(0.6, 1.0, clampf(night, 0.0, 1.0))
	e += sin(t * pulse_speed * TAU * 0.5 + _phase) * pulse_amount
	if flicker_amount > 0.0:
		e += sin(t * 37.0 + _phase) * sin(t * 13.0) * flicker_amount
	energy = maxf(e, 0.0)
