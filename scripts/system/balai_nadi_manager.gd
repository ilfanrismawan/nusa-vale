class_name BalaiNadiManager
extends Node

signal contribution_added(project_id: String, item_id: String, amount: int)
signal project_completed(project_id: String)
signal state_changed

const RESTORATION = preload("res://resources/restoration/balai_nadi_restoration.tres")
const GREENHOUSE = preload("res://resources/restoration/greenhouse_restoration.tres")
var definitions: Array[RestorationProject] = [RESTORATION, GREENHOUSE]
var _projects: Dictionary = {}
var _busy := false

func _ready() -> void:
	reset()

func definition(project_id: String) -> RestorationProject:
	for project in definitions:
		if project.project_id == project_id:
			return project
	return null

func contributed(project_id: String, item_id: String) -> int:
	return int(_projects.get(project_id, {}).get("contributions", {}).get(item_id, 0))

func completed(project_id: String) -> bool:
	return bool(_projects.get(project_id, {}).get("completed", false))

func remaining(project_id: String, item_id: String) -> int:
	var project := definition(project_id)
	if project == null or completed(project_id):
		return 0
	return maxi(0, int(project.requirements.get(item_id, 0)) - contributed(project_id, item_id))

## Synchronous transaction, including the existing slot save. Reentrant input is rejected.
## Pass the donor explicitly: GameState.current can change between co-op frames.
func contribute(donor: PlayerData, project_id: String, item_id: String, requested: int = 2147483647) -> int:
	var project := definition(project_id)
	if _busy or donor == null or not GameState.players.has(donor) or project == null or requested <= 0:
		return 0
	var accepted := mini(requested, mini(remaining(project_id, item_id), donor.get_item_count(item_id)))
	if accepted <= 0:
		return 0
	_busy = true
	var old_inventory := donor.inventory.duplicate(true)
	var old_state: Dictionary = _projects[project_id].duplicate(true)
	var old_flag := WorldState.has_flag(project.completion_flag)
	if not donor.remove_item(item_id, accepted):
		_busy = false
		return 0
	_projects[project_id].contributions[item_id] = contributed(project_id, item_id) + accepted
	var finished := _requirements_met(project)
	_projects[project_id].completed = finished
	# Save the flag in the same snapshot, but publish world/completion events only on success.
	if not project.completion_flag.is_empty():
		WorldState.flags[project.completion_flag] = finished
	if not SaveManager.save_game():
		donor.inventory = old_inventory
		_projects[project_id] = old_state
		if not project.completion_flag.is_empty():
			WorldState.flags[project.completion_flag] = old_flag
		GameState.inventory_changed.emit()
		state_changed.emit()
		Notify.say("Kontribusi belum tersimpan. Bahan dikembalikan; coba lagi.")
		_busy = false
		return 0
	state_changed.emit()
	contribution_added.emit(project_id, item_id, accepted)
	var item := GameState._resolve_item(item_id)
	Notify.say("Terima kasih! %s x%d ditambahkan ke balai." % [item.display_name, accepted])
	if finished:
		if not project.completion_flag.is_empty() and not old_flag:
			WorldState.flag_changed.emit(project.completion_flag, true)
		project_completed.emit(project_id)
		Notify.say(project.completion_message)
	_busy = false
	return accepted

func _requirements_met(project: RestorationProject) -> bool:
	for item_id in project.requirements:
		if contributed(project.project_id, item_id) < project.requirements[item_id]:
			return false
	return not project.requirements.is_empty()

func to_save() -> Dictionary:
	return {"projects": _projects.duplicate(true)}

func reset() -> void:
	load_save({})

## Loading reconciles flags and visual state, never emits a completion/reward event.
func load_save(saved: Variant) -> void:
	_projects.clear()
	var records: Dictionary = saved.get("projects", {}) if saved is Dictionary and saved.get("projects", {}) is Dictionary else {}
	for project in definitions:
		var record: Variant = records.get(project.project_id, {})
		if not record is Dictionary:
			record = {}
		var amounts: Variant = record.get("contributions", {})
		if not amounts is Dictionary:
			amounts = {}
		var progress := {}
		for item_id in project.requirements:
			var amount: Variant = amounts.get(item_id, 0)
			progress[item_id] = clampi(int(amount), 0, project.requirements[item_id]) if (amount is int or amount is float) and is_finite(float(amount)) else 0
		_projects[project.project_id] = {"contributions": progress, "completed": false}
		var finished: bool = record.get("completed", false) == true or _requirements_met(project)
		_projects[project.project_id].completed = finished
		if finished:
			for item_id in project.requirements:
				progress[item_id] = project.requirements[item_id]
		if not project.completion_flag.is_empty():
			WorldState.set_flag(project.completion_flag, finished)
	state_changed.emit()
