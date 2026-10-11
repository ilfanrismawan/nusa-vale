extends Node2D

## Interior sekolah desa. Scene dibuat oleh scratch/gen_school_v2.py.

func _ready() -> void:
	if DiscoveryManager.discover("school"):
		Notify.say("Memasuki Sekolah Nusa Vale.")
