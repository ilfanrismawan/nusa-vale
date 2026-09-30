extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print(FarmManager)
	print(FarmManager.get_script())
	print(FarmManager.has_method("initialize"))
	FarmManager.initialize(self)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
