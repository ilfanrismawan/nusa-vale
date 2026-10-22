class_name SceneLighting
extends Node

## Pengaturan tint siang/sore/malam (DayCycle) untuk satu scene. Opsional:
## tanpa node ini, DayCycle memilih sendiri dari path scene
## (outdoor penuh, path berisi "interior" lebih lembut, path berisi "/cave/" tanpa tint).
## Taruh node ini di mana saja di dalam scene dunia, lalu atur di Inspector.

## Matikan untuk tempat yang punya tampilan sendiri (gua, ruang rahasia).
@export var follow_time := true
## Seberapa kuat warna waktu dipakai: 1 = sama dengan outdoor, 0 = tidak berubah.
@export_range(0.0, 1.0, 0.05) var time_strength := 0.5
## Warna dasar ruangan, dikalikan dengan warna waktu. Jika scene sudah punya
## CanvasModulate sendiri, warnanya juga ikut dikalikan.
@export var room_color := Color.WHITE

func _enter_tree() -> void:
	DayCycle.configure_scene(self)

## Kekuatan yang benar-benar dipakai DayCycle.
func effective_strength() -> float:
	return time_strength if follow_time else 0.0
