extends Node2D

@onready var modulate_light: CanvasModulate = $CanvasModulate

const CleanupSpawner = preload("res://scripts/world/farm_cleanup_spawner.gd")

func _enter_tree() -> void:
	# Sebelum physics/spawner/UI mulai memakai isi area.
	CleanupSpawner.populate(self)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	DayCycle.is_running = true
	FarmManager.initialize(self)
	StructureManager.attach.call_deferred(self)
	WeedSpawner.attach_weeds(self, "farm", ^"YSort", 4, 30, true)
	DigSpotSpawner.attach_dig_spots(self, "farm", ^"YSort", 1, 3, true)
	
	Notify.say("WASD JALAN | Klik pakai alat | 1-6 / Q E ganti alat")
	Notify.say("Enter di dekat toko, bin, atau kasur | I tas | Esc menu")

func _exit_tree() -> void:
	FarmManager.clear_references()
