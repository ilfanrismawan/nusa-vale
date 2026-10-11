extends Node2D

## Kota Nusa Vale. Scene dibuat oleh scratch/gen_town.py (jangan diedit manual).

@onready var modulate_light: CanvasModulate = $CanvasModulate

func _ready() -> void:
	DayCycle.is_running = true
	FarmManager.initialize(self)
	DayCycle.time_tick.connect(_on_time_tick)
	_on_time_tick(DayCycle.hour, DayCycle.minute)

	if DiscoveryManager.discover("town"):
		Notify.say("Selamat datang di Kota Nusa Vale!")
		Notify.say("Sekolah dan Universitas di utara alun-alun, toko di timur.")

func _exit_tree() -> void:
	FarmManager.clear_references()

func _on_time_tick(hour: int, _minute: int) -> void:
	if hour >= 6 and hour < 16:
		modulate_light.color = Color(1.0, 1.0, 1.0)
	elif hour >= 16 and hour < 19:
		modulate_light.color = Color(1.0, 0.75, 0.5)
	else:
		modulate_light.color = Color(0.3, 0.35, 0.6)
