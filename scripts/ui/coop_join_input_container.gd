extends SubViewportContainer

## Hanya perangkat tamu yang diteruskan lewat CoopJoinPane.forward().
func _propagate_input_event(_event: InputEvent) -> bool:
	return false
