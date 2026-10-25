extends Node2D

## Ganti tekstur semua Sprite2D bernama "Art" di bawah node ini sesuai status restorasi Balai Nadi.
## Tekstur diatur di Inspector; posisi, skala, dan tabrakan tetap dari scene.
@export var project_id := "balai_nadi_restoration"
@export var restored_texture: Texture2D
@export var ruined_texture: Texture2D

func _ready() -> void:
	GameState.balai_nadi.state_changed.connect(_refresh)
	_refresh()

func _refresh() -> void:
	var texture := restored_texture if GameState.balai_nadi.completed(project_id) else ruined_texture
	if texture == null:
		return
	for art in find_children("Art", "Sprite2D", true, false):
		(art as Sprite2D).texture = texture
