class_name DayaManager
extends Node

# Unique world rewards; capacity belongs to the player who consumes the seed.
var obtained: Dictionary = {}
var pending: Dictionary = {}
var crops: Array[String] = []
var consumed: Array[String] = []
var _consuming := false
signal state_changed
var _delivering := false

func _ready() -> void:
	FarmManager.crop_harvested.connect(_harvest)
	GameState.inventory_changed.connect(func(): call_deferred("deliver"))

func reset() -> void:
	obtained.clear()
	pending.clear()
	crops.clear()
	consumed.clear()
	state_changed.emit()

func _harvest(_cell: Vector2i, item_id: String, _count: int) -> void:
	if item_id.is_empty() or _count <= 0:
		return
	var new_crop := not crops.has(item_id)
	if new_crop:
		crops.append(item_id)
	if crops.size() >= 2:
		unlock("harvest", GameState.current)
	elif new_crop and crops.size() == 1:
		Notify.say("Akar pulau berdenyut. Panen satu jenis tanaman lain untuk menemukan Biji Daya.")

func _restored(_project: String) -> void:
	unlock("balai", GameState.current)

func stage_reward(id: String, recipient: PlayerData) -> bool:
	if recipient == null or not GameState.players.has(recipient) or id not in PlayerData.DAYA_IDS or obtained.has(id) or pending.has(id) or consumed.has(id):
		return false
	pending[id] = recipient.index
	return true

func unlock(id: String, recipient: PlayerData) -> void:
	if not stage_reward(id, recipient):
		return
	deliver()
	if pending.has(id):
		Notify.say("Biji Daya menunggumu. Kosongkan satu slot tas untuk menerimanya.")

func deliver() -> void:
	if _delivering or _consuming:
		return
	_delivering = true
	for id in pending.keys():
		var recipient := GameState.get_player(int(pending[id]))
		if recipient.find_empty_slot() < 0:
			continue
		# Mark first to prevent reentrant inventory signals duplicating the reward.
		obtained[id] = true
		pending.erase(id)
		recipient.add_item("biji_daya_" + id, 1)
		Notify.say("Biji Daya ditemukan! Konsumsi dari tas untuk stamina maksimum +10 permanen.")
	_delivering = false
	state_changed.emit()

func consume(recipient: PlayerData, slot: int, expected_id: String) -> bool:
	if _consuming or recipient == null or not GameState.players.has(recipient) or slot < 0 or slot >= recipient.bag_size:
		return false
	var entry: Variant = recipient.inventory[slot]
	if not entry is Dictionary or not entry.get("item") is ItemData or int(entry.get("count", 0)) < 1 or entry.item.item_id != "biji_daya_" + expected_id:
		return false
	if expected_id not in PlayerData.DAYA_IDS or not obtained.has(expected_id) or consumed.has(expected_id):
		return false
	for data in GameState.players:
		if data.consumed_daya.has(expected_id):
			return false
	_consuming = true
	var old_inventory := recipient.inventory.duplicate(true)
	var old_stamina := recipient.stamina
	recipient.consumed_daya.append(expected_id)
	consumed.append(expected_id)
	recipient.remove_item_at(slot, 1)
	recipient.restore_stamina(10)
	if not SaveManager.save_game():
		recipient.inventory = old_inventory
		recipient.consumed_daya.erase(expected_id)
		consumed.erase(expected_id)
		recipient.stamina = old_stamina
		GameState.inventory_changed.emit()
		_consuming = false
		Notify.say("Biji Daya belum tersimpan. Biji dikembalikan; coba lagi.")
		return false
	_consuming = false
	state_changed.emit()
	Notify.say("Hangatnya menetap di tubuhmu. Stamina maksimum +10.")
	return true

func to_save() -> Dictionary:
	return {"obtained": obtained.duplicate(), "pending": pending.duplicate(), "crops": crops.duplicate(), "consumed": consumed.duplicate()}

func load_save(value: Variant) -> void:
	reset()
	if not value is Dictionary:
		return
	for id in PlayerData.DAYA_IDS:
		if value.get("obtained", {}) is Dictionary and value.get("obtained", {}).get(id, false) == true:
			obtained[id] = true
		var waiting: Variant = value.get("pending", {})
		if waiting is Dictionary and waiting.has(id) and not obtained.has(id) and (waiting[id] is int or waiting[id] is float) and is_finite(float(waiting[id])):
			pending[id] = clampi(int(waiting[id]), 0, GameState.MAX_PLAYERS - 1)
	var saved_consumed: Variant = value.get("consumed", [])
	for id in PlayerData.DAYA_IDS:
		var was_consumed: bool = saved_consumed is Array and saved_consumed.has(id)
		for player in GameState.players:
			was_consumed = was_consumed or player.consumed_daya.has(id)
		if was_consumed:
			consumed.append(id)
			obtained[id] = true
			pending.erase(id)
	var saved_crops: Variant = value.get("crops", [])
	if saved_crops is Array:
		for item in saved_crops:
			if item is String and not crops.has(item):
				crops.append(item)
	# Old saves can still receive the first restored facility reward.
	for project in GameState.balai_nadi.definitions:
		if GameState.balai_nadi.completed(project.project_id):
			stage_reward("balai", GameState.p1())
	call_deferred("deliver")
