class_name VehicleZone
extends Node

## Taruh di scene area untuk menimpa aturan kendaraan bawaan (GDD 10).
## Tanpa node ini: path scene berisi "interior" atau "/cave/" = kendaraan dilarang, lainnya boleh.

const GROUP := &"vehicle_zone"

## true = kendaraan boleh dipakai di scene ini, false = dilarang (ruangan sempit).
@export var allowed: bool = true

func _enter_tree() -> void:
	add_to_group(GROUP)
