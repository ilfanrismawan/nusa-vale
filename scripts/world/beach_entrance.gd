extends "res://scripts/world/scene_entrance.gd"

## Jalan ke Pantai di tepi selatan Town. Terkunci sampai UnlockManager "beach" terbuka
## (Nelayan Lv 2, lihat UnlockManager.try_unlock_beach).

const WARNING_COOLDOWN := 3.0
var _warned_at := -WARNING_COOLDOWN

func _on_body_entered(body: Node2D) -> void:
	if Transition.on_transition or not body is Player:
		return
	if not UnlockManager.is_unlocked("beach") and not UnlockManager.try_unlock_beach():
		var now := Time.get_ticks_msec() / 1000.0
		if now - _warned_at >= WARNING_COOLDOWN:
			_warned_at = now
			if UnlockManager.fisher_level_waiting_for_sleep():
				Notify.say("Pantai terbuka setelah tidur: level Nelayan baru aktif besok pagi.")
			else:
				Notify.say("Jalan ke Pantai masih ditutup. Capai Nelayan Lv %d dengan memancing." % UnlockManager.BEACH_FISHER_LEVEL)
		return
	super._on_body_entered(body)
