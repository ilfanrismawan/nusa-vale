extends Node2D

## Reserved logical coordinates keep greenhouse plots separate from existing farm cells.
## Layer FarmManager (BaseLayerGround, SoilLayer, WateredLayer, Crop) ada di scene dengan offset
## posisi -FIRST_CELL * 16; petak tanam = sel BaseLayerGround yang dicat di editor.
## Layout awal disusun tools/build_greenhouse.gd.
const FIRST_CELL := Vector2i(10000, 10000)

func _ready() -> void:
	set_meta("farm_area", "greenhouse")
	FarmManager.initialize(self)
	SaveManager.game_loaded.connect(_reload_plots)
	DayCycle.day_passed.connect(_refresh_plots)
	DayCycle.is_running = true

func _reload_plots() -> void:
	$SoilLayer.clear()
	$WateredLayer.clear()
	$Crop.clear()
	FarmManager.initialize(self)

func _refresh_plots(_day: int) -> void:
	# Co-op may have another area's layers bound while this room is still loaded.
	$WateredLayer.clear()
	FarmManager.initialize(self)

func _exit_tree() -> void:
	if FarmManager._bound_world == self:
		FarmManager.clear_references()
