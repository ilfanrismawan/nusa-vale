class_name VehicleVisual
extends Node2D

## Tampilan kendaraan yang ditumpangi (GDD 10). Root scene di scenes/vehicles/, diatur di editor:
## Sprite2D anak dengan hframes/vframes; satu baris sheet per arah. Arah kiri = baris samping dibalik.
## RideState memanggil set_facing() dan set_moving(), lalu menggeser sprite pemain
## sebesar rider_offset supaya terlihat duduk di atas kendaraan.

@export var sprite: Sprite2D
## Baris sheet untuk menghadap bawah, atas, dan samping (kanan).
@export var row_down: int = 0
@export var row_up: int = 1
@export var row_side: int = 2
## Frame animasi per baris (roda berputar). Diam = frame 0.
@export_range(1, 8) var frames_per_row: int = 2
@export_range(1.0, 24.0, 0.5) var fps: float = 10.0
## Tetap beranimasi walau diam (sapu berkilau).
@export var animate_when_idle: bool = false
## Geser sprite pemain saat menumpang, menghadap samping / bawah-atas.
@export var rider_offset_side: Vector2 = Vector2(0, -3)
@export var rider_offset_front: Vector2 = Vector2(0, -3)
## Kendaraan digambar di depan pemain (z_index relatif). Negatif = di belakang.
@export var draw_in_front_side: int = 1
@export var draw_in_front_down: int = 1
@export var draw_in_front_up: int = 1

var _row := 0
var _flip := false
var _moving := false
var _time := 0.0
var _facing := Vector2.DOWN

func set_facing(direction: Vector2) -> void:
	_facing = direction
	if direction.x != 0.0:
		_row = row_side
		_flip = direction.x < 0.0
		z_index = draw_in_front_side
	elif direction.y < 0.0:
		_row = row_up
		_flip = false
		z_index = draw_in_front_up
	else:
		_row = row_down
		_flip = false
		z_index = draw_in_front_down
	_apply()

func set_moving(value: bool) -> void:
	_moving = value

func rider_offset() -> Vector2:
	return rider_offset_side if _facing.x != 0.0 else rider_offset_front

func _process(delta: float) -> void:
	if _moving or animate_when_idle:
		_time += delta
	_apply()

func _apply() -> void:
	if sprite == null:
		return
	sprite.flip_h = _flip
	var column := int(_time * fps) % frames_per_row if (_moving or animate_when_idle) else 0
	sprite.frame = clampi(_row * sprite.hframes + column, 0, sprite.hframes * sprite.vframes - 1)
