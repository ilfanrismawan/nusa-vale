extends Node2D

@onready var modulate_light: CanvasModulate = $CanvasModulate

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	FarmManager.initialize(self)
	DayCycle.time_tick.connect(_on_time_tick)
	_on_time_tick(DayCycle.hour, DayCycle.minute)
	
	Notify.say("WASD JALAN | Klik pakai alat | 1-6 / Q E ganti alat")
	Notify.say("Enter di deakt toko, bin, atau kasur | I tas | Esc menu")

#efek pergantian siang sore malam
func _on_time_tick(hour: int, _minute: int) -> void:
	if hour >= 6 and hour < 16:
		# Siang (Putih normal)
		modulate_light.color = Color(1.0, 1.0, 1.0)
		# Sore / Senja (Oranye hangat)
	elif hour >= 16 and hour < 19:
		modulate_light.color = Color(1.0, 0.75, 0.5)
	else:
		 # Malam (Biru gelap temaram)
		modulate_light.color = Color(0.3, 0.35, 0.6)
