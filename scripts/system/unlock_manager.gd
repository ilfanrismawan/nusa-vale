extends Node

signal unlock_changed(unlock_id: String, unlocked: bool)

const DEFAULT_UNLOCKS: Dictionary = {
	"greenhouse": false,
	"forest": false,
	"deep_forest": false,
	"cave": false,
	"school": false,
	"mountain": false,
	"beach": false,
}

var unlocks: Dictionary = {}

const DEEP_FOREST_COST := 3000
const DEEP_FOREST_MATERIALS := {"wood": 150, "stone": 75}


func deep_forest_requirements_met() -> bool:
	if not is_unlocked("forest") or GameState.money < DEEP_FOREST_COST:
		return false
	for id in DEEP_FOREST_MATERIALS:
		if not GameState.has_item(id, DEEP_FOREST_MATERIALS[id]):
			return false
	return true


func purchase_deep_forest() -> bool:
	if is_unlocked("deep_forest") or not deep_forest_requirements_met():
		return false
	# All requirements are checked before the synchronous transaction.
	for id in DEEP_FOREST_MATERIALS:
		GameState.remove_item(id, DEEP_FOREST_MATERIALS[id])
	GameState.spend_money(DEEP_FOREST_COST)
	return unlock("deep_forest")


## Level role Penambang (aktif, bukan sekadar EXP) yang membuka Gua Tambang.
const CAVE_MINER_LEVEL := 2


## Akses permanen setelah salah satu pemain mencapai Penambang Lv 2 (EXP dari memecahkan batu).
func try_unlock_cave() -> bool:
	if is_unlocked("cave"):
		return true
	if best_miner_level() < CAVE_MINER_LEVEL:
		return false
	return unlock("cave")


## Level Penambang aktif tertinggi di antara pemain (co-op: cukup satu pemain).
func best_miner_level() -> int:
	var best := 0
	for data in GameState.players:
		if data != null and data.skills != null:
			best = maxi(best, data.skills.level(&"miner"))
	return best


## Penambang tertinggi sudah punya EXP Lv 2 tetapi belum tidur untuk mengaktifkannya.
func miner_level_waiting_for_sleep() -> bool:
	for data in GameState.players:
		if data != null and data.skills != null and data.skills.earned_level(&"miner") >= CAVE_MINER_LEVEL:
			return true
	return false


func _ready() -> void:
	reset()


func reset() -> void:
	unlocks = DEFAULT_UNLOCKS.duplicate(true)


func is_unlocked(unlock_id: String) -> bool:
	if not unlocks.has(unlock_id):
		return false

	return bool(unlocks[unlock_id])


func unlock(unlock_id: String) -> bool:
	if not _is_valid_unlock_id(unlock_id):
		push_warning("UnlockManager: Unknown unlock ID: %s" % unlock_id)
		return false

	if is_unlocked(unlock_id):
		return false

	unlocks[unlock_id] = true
	unlock_changed.emit(unlock_id, true)

	return true


func lock(unlock_id: String) -> bool:
	if not _is_valid_unlock_id(unlock_id):
		push_warning("UnlockManager: Unknown unlock ID: %s" % unlock_id)
		return false

	if not is_unlocked(unlock_id):
		return false

	unlocks[unlock_id] = false
	unlock_changed.emit(unlock_id, false)

	return true


func set_unlock(unlock_id: String, value: bool) -> bool:
	if not _is_valid_unlock_id(unlock_id):
		push_warning("UnlockManager: Unknown unlock ID: %s" % unlock_id)
		return false

	if bool(unlocks.get(unlock_id, false)) == value:
		return false

	unlocks[unlock_id] = value
	unlock_changed.emit(unlock_id, value)

	return true


func get_unlocks() -> Dictionary:
	return unlocks.duplicate(true)


func load_unlocks(data: Dictionary) -> void:
	for unlock_id in DEFAULT_UNLOCKS:
		if data.has(unlock_id):
			unlocks[unlock_id] = bool(data[unlock_id])


func _is_valid_unlock_id(unlock_id: String) -> bool:
	return DEFAULT_UNLOCKS.has(unlock_id)
