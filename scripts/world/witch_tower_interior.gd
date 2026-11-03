extends "res://scripts/world/node_interior.gd"

## Interior Menara Penyihir. Semua perabot adalah node di scene (dibuat tools/gen_witch_tower.py,
## boleh digeser di editor); script ini hanya menambah pesan kunjungan pertama.


func _ready() -> void:
	super._ready()
	if DiscoveryManager.discover("witch_tower"):
		Notify.say("Menara Penyihir: Nyai Kenanga menjual tongkat dan bahan sihir. Kuali, meja jimat, dan altar enchant ada di sini.")
