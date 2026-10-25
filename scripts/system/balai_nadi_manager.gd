class_name BalaiNadiManager
extends Node

signal contribution_added(project_id: String, item_id: String, amount: int)
signal project_completed(project_id: String)
signal wing_finished(wing_id: String)
signal state_changed

const RESTORATION = preload("res://resources/restoration/balai_nadi_restoration.tres")
const GREENHOUSE = preload("res://resources/restoration/greenhouse_restoration.tres")
## Bundel serangga Sayap Alam (GDD 7, 4A-3).
const BUG_BUNDLE = preload("res://resources/restoration/bug_bundle.tres")
const CATALOG = preload("res://resources/restoration/balai_nadi_catalog.tres")
var definitions: Array[RestorationProject] = CATALOG.projects.duplicate()
var _projects: Dictionary = {}
var _busy := false

const WINGS := {
	"alam": {"name": "Sayap Alam", "description": "Kebun komunitas, tanaman, hasil panen, dan sumber daya alam."},
	"karya": {"name": "Sayap Karya", "description": "Bengkel, resep crafting, perbaikan fasilitas, dan upgrade tool."},
	"niaga": {"name": "Sayap Niaga", "description": "Pasar, merchant, jaringan perdagangan, dan peluang ekonomi."},
	"pengetahuan": {"name": "Sayap Pengetahuan", "description": "Perpustakaan, mineral, artefak, spesimen, dan pengetahuan dunia."},
}

func restoration_stage() -> String:
	if all_wings_completed():
		return "Jantung Desa"
	if completed(RESTORATION.project_id) and completed(GREENHOUSE.project_id):
		return "Kehidupan Kembali"
	for project in definitions:
		for item_id in project.requirements:
			if contributed(project.project_id, item_id) > 0:
				return "Pemulihan"
	return "Terbengkalai"

# ── Sayap (GDD 4.9): bonus permanen saat semua paket satu sayap selesai ──

func wings() -> Array[BalaiWing]:
	return CATALOG.wings

func wing(wing_id: String) -> BalaiWing:
	for entry in CATALOG.wings:
		if entry.wing_id == wing_id:
			return entry
	return null

func wing_projects(wing_id: String) -> Array[RestorationProject]:
	var result: Array[RestorationProject] = []
	for project in definitions:
		if project.wing_id == wing_id:
			result.append(project)
	return result

func wing_completed(wing_id: String) -> bool:
	if wing(wing_id) == null:
		return false
	var projects := wing_projects(wing_id)
	if projects.is_empty():
		return false
	for project in projects:
		if not completed(project.project_id):
			return false
	return true

func all_wings_completed() -> bool:
	if CATALOG.wings.is_empty():
		return false
	for entry in CATALOG.wings:
		if not wing_completed(entry.wing_id):
			return false
	return true

## Jumlah bonus stat dari sayap yang sudah lengkap; ditambahkan SkillSystem.stat/household.
func wing_stat(key: StringName) -> float:
	var total := 0.0
	for entry in CATALOG.wings:
		if entry.effects.has(key) and wing_completed(entry.wing_id):
			total += float(entry.effects[key])
	return total

## Kebutuhan yang harus lengkap: slots_required (ala Stardew) atau semua.
func slots_needed(project: RestorationProject) -> int:
	var total := project.requirements.size()
	return total if project.slots_required <= 0 else mini(project.slots_required, total)

func filled_slots(project: RestorationProject) -> int:
	var filled := 0
	for item_id in project.requirements:
		if contributed(project.project_id, item_id) >= required(project, item_id):
			filled += 1
	return filled

func available_amount(donor: PlayerData, item_id: String) -> int:
	return GameState.money if item_id == "money" else donor.get_item_count(item_id)

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
	return maxi(0, required(project, item_id) - contributed(project_id, item_id))

## Semua bahan sudah memenuhi syarat (mis. setelah Village Treasurer) tetapi paket belum ditutup.
func ready_to_finish(project_id: String) -> bool:
	var project := definition(project_id)
	return project != null and not completed(project_id) and _requirements_met(project)

## Jumlah yang dibutuhkan setelah Village Treasurer (Economist Lv5 A); uang tidak berubah.
func required(project: RestorationProject, item_id: String) -> int:
	if project == null or not project.requirements.has(item_id):
		return 0
	return SkillSystem.balai_requirement(item_id, int(project.requirements[item_id]))

## Synchronous transaction, including the existing slot save. Reentrant input is rejected.
## Pass the donor explicitly: GameState.current can change between co-op frames.
func contribute(donor: PlayerData, project_id: String, item_id: String, requested: int = 2147483647) -> int:
	var project := definition(project_id)
	if _busy or donor == null or not GameState.players.has(donor) or project == null or requested <= 0:
		return 0
	var accepted := mini(requested, mini(remaining(project_id, item_id), available_amount(donor, item_id)))
	# Village Treasurer bisa membuat paket yang sudah terisi langsung memenuhi syarat:
	# kontribusi 0 lalu menyelesaikannya.
	if accepted <= 0 and not ready_to_finish(project_id):
		return 0
	_busy = true
	var old_inventory := donor.inventory.duplicate(true)
	var old_money := GameState.money
	var old_unlock := UnlockManager.is_unlocked(project.unlock_id)
	var old_state: Dictionary = _projects[project_id].duplicate(true)
	var old_flag := WorldState.has_flag(project.completion_flag)
	var old_skills := donor.skills.to_dict()
	var project_wing := wing(project.wing_id)
	var old_wing_done := wing_completed(project.wing_id)
	var old_wing_flag := WorldState.has_flag(project_wing.completion_flag) if project_wing != null else false
	var donated_value := accepted
	if item_id != "money":
		var donated := GameState._resolve_item(item_id)
		donated_value = accepted * (donated.sell_price if donated != null else 0)
	if item_id == "money":
		GameState.money -= accepted
	elif accepted > 0 and not donor.remove_item(item_id, accepted):
		_busy = false
		return 0
	_projects[project_id].contributions[item_id] = contributed(project_id, item_id) + accepted
	var finished := _requirements_met(project)
	_projects[project_id].completed = finished
	if not project.unlock_id.is_empty():
		UnlockManager.unlocks[project.unlock_id] = finished
	# Save the flag in the same snapshot, but publish world/completion events only on success.
	if not project.completion_flag.is_empty():
		WorldState.flags[project.completion_flag] = finished
	# Hanya dua proyek restorasi lama yang memicu Biji Daya "balai"; paket sayap tidak.
	var staged_daya := finished and project_id in [RESTORATION.project_id, GREENHOUSE.project_id] and GameState.daya.stage_reward("balai", donor)
	# Role Economist (GDD 13): EXP dari nilai sumbangan; paket selesai = Token Talenta.
	SkillSystem.gain_from_value(donor, &"economist", donated_value, SkillSystem.RULES.balai_gold_per_exp)
	if finished:
		donor.skills.tokens += SkillSystem.RULES.balai_tokens
	var wing_done := project_wing != null and not old_wing_done and wing_completed(project.wing_id)
	if wing_done:
		donor.skills.tokens += project_wing.reward_tokens
		if not project_wing.completion_flag.is_empty():
			WorldState.flags[project_wing.completion_flag] = true
	if not SaveManager.save_game():
		if staged_daya:
			GameState.daya.pending.erase("balai")
		donor.inventory = old_inventory
		donor.skills.load_dict(old_skills)
		GameState.money = old_money
		if not project.unlock_id.is_empty():
			UnlockManager.unlocks[project.unlock_id] = old_unlock
		_projects[project_id] = old_state
		if not project.completion_flag.is_empty():
			WorldState.flags[project.completion_flag] = old_flag
		if wing_done and not project_wing.completion_flag.is_empty():
			WorldState.flags[project_wing.completion_flag] = old_wing_flag
		GameState.inventory_changed.emit()
		state_changed.emit()
		Notify.say("Kontribusi belum tersimpan. Bahan dikembalikan; coba lagi.")
		_busy = false
		return 0
	GameState.money_changed.emit(GameState.money)
	state_changed.emit()
	contribution_added.emit(project_id, item_id, accepted)
	var name_text: String = "Dana" if item_id == "money" else GameState._resolve_item(item_id).display_name
	if accepted > 0:
		Notify.say("Terima kasih! %s x%d ditambahkan ke balai." % [name_text, accepted])
	if finished:
		if not project.unlock_id.is_empty() and not old_unlock:
			UnlockManager.unlock_changed.emit(project.unlock_id, true)
		if not project.completion_flag.is_empty() and not old_flag:
			WorldState.flag_changed.emit(project.completion_flag, true)
		GameState.daya.deliver()
		_give_rewards(donor, project)
		project_completed.emit(project_id)
		Notify.say(project.completion_message)
		Notify.say("Hadiah: %d Token Talenta! Pakai di tab Keahlian." % SkillSystem.RULES.balai_tokens)
	if wing_done:
		if not project_wing.completion_flag.is_empty() and not old_wing_flag:
			WorldState.flag_changed.emit(project_wing.completion_flag, true)
		wing_finished.emit(project_wing.wing_id)
		Notify.say(project_wing.completion_message)
		Notify.say("Bonus permanen: %s · +%d Token Talenta." % [project_wing.bonus_text, project_wing.reward_tokens])
	_busy = false
	return accepted

## Hadiah barang bundel masuk ke tas penyumbang; yang tidak muat jatuh di dekat pemainnya.
func _give_rewards(donor: PlayerData, project: RestorationProject) -> void:
	for item_id in project.reward_items:
		var amount: int = project.reward_items[item_id]
		var leftover := donor.add_item(item_id, amount)
		var item := GameState._resolve_item(item_id)
		if item != null:
			Notify.say("Hadiah: %s x%d" % [item.display_name, amount])
		if leftover > 0:
			for node in get_tree().get_nodes_in_group(&"player"):
				if node is Player and (node as Player).data == donor:
					ItemPickup.spawn(node.get_parent(), (node as Player).global_position + Vector2(0, 12), item_id, leftover)
					break

func _requirements_met(project: RestorationProject) -> bool:
	return not project.requirements.is_empty() and filled_slots(project) >= slots_needed(project)

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
		# Save lama yang tercatat selesai tanpa progres lengkap: tampilkan penuh.
		if finished and not _requirements_met(project):
			for item_id in project.requirements:
				progress[item_id] = project.requirements[item_id]
		if not project.completion_flag.is_empty():
			WorldState.set_flag(project.completion_flag, finished)
		if not project.unlock_id.is_empty():
			UnlockManager.set_unlock(project.unlock_id, finished)
	for entry in CATALOG.wings:
		if not entry.completion_flag.is_empty():
			WorldState.set_flag(entry.completion_flag, wing_completed(entry.wing_id))
	state_changed.emit()
