extends Node2D

@onready var modulate_light: CanvasModulate = $CanvasModulate

const CleanupSpawner = preload("res://scripts/world/farm_cleanup_spawner.gd")
const BugSpawner = preload("res://scripts/world/bug_spawner.gd")
const PlantedTreeSpawner = preload("res://scripts/world/planted_tree_spawner.gd")

func _enter_tree() -> void:
	# Sebelum physics/spawner/UI mulai memakai isi area.
	CleanupSpawner.populate(self)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var mailbox := Area2D.new()
	mailbox.name = "SocialMailbox"
	mailbox.position = Vector2(1088, 288)
	mailbox.set_script(preload("res://scripts/world/social_mailbox.gd"))
	add_child(mailbox)
	DayCycle.is_running = true
	FarmManager.initialize(self)
	StructureManager.attach.call_deferred(self)
	WeedSpawner.attach_weeds(self, "farm", ^"YSort", 4, 30, true)
	DigSpotSpawner.attach_dig_spots(self, "farm", ^"YSort", 1, 3, true)
	# Gathering (GDD 7): serangga liar dan pohon dari biji pohon.
	BugSpawner.attach(self, "farm", ^"YSort", 5)
	# Hanya gagak yang mampir ke ladang (GDD 4.10.13); suasana, tidak memakan tanaman.
	PlantedTreeSpawner.attach_planted(self, "farm", ^"YSort")
	
func _exit_tree() -> void:
	FarmManager.clear_references()
