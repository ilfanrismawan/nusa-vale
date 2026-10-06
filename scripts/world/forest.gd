extends Node2D

@onready var modulate_light: CanvasModulate = $CanvasModulate

func _ready() -> void:
	DayCycle.is_running = true
	FarmManager.initialize(self)
	DayCycle.time_tick.connect(_on_time_tick)
	_on_time_tick(DayCycle.hour, DayCycle.minute)

	Notify.say("Hutan: Tebang pohon dengan Kapak | Tambang batu/bijih dengan Beliung")

func _exit_tree() -> void:
	FarmManager.clear_references()

func _on_time_tick(hour: int, _minute: int) -> void:
	if hour >= 6 and hour < 16:
		# Siang - rimbun dan teduh
		modulate_light.color = Color(0.9, 1.0, 0.9)
	elif hour >= 16 and hour < 19:
		# Sore / Senja - temaram keemasan
		modulate_light.color = Color(0.95, 0.75, 0.5)
	else:
		# Malam - gelap kebiruan di dalam hutan
		modulate_light.color = Color(0.2, 0.25, 0.45)
