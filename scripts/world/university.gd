extends Node2D

## Interior Universitas Nusa Vale. Scene dibuat oleh scratch/gen_university.py.

func _ready() -> void:
	if DiscoveryManager.discover("university"):
		Notify.say("Memasuki Universitas Nusa Vale.")
