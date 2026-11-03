extends Sprite2D

## Lapisan jendela menyala Menara Penyihir: tampil pelan saat sore/malam
## (DayCycle.night_intensity), berkedip lembut seperti cahaya lilin.

var _phase := randf() * TAU


func _process(_delta: float) -> void:
	var night := clampf(DayCycle.night_intensity(), 0.0, 1.0)
	visible = night > 0.0
	if visible:
		var t := Time.get_ticks_msec() * 0.001
		modulate.a = night * (0.85 + sin(t * 5.0 + _phase) * 0.08)
