class_name SkillManager
extends Node

## Anak GameState (GameState.skills). Saat hari berganti: level EXP jadi aktif, bunga
## Smart Investor dibayar, lalu layar rekap "Level Up!" muncul setelah laporan pengiriman.

const LEVEL_UP_UI := preload("res://scenes/ui/level_up_ui.tscn")
## Jeda setelah tidur sebelum memeriksa laporan pengiriman (laporan muncul 2 detik setelah pagi).
const RECAP_DELAY := 2.3

## Kenaikan level terakhir: [{data: PlayerData, role_id, from, to}].
var last_levels: Array[Dictionary] = []
var _ui: CanvasLayer


func _ready() -> void:
	DayCycle.day_passed.connect(_on_day_passed)

func reset() -> void:
	last_levels.clear()
	if is_instance_valid(_ui):
		_ui.queue_free()
	_ui = null

func _on_day_passed(_day: int) -> void:
	last_levels.clear()
	for data in GameState.players:
		if data == null or data.skills == null:
			continue
		for row in data.skills.apply_levels():
			row["data"] = data
			last_levels.append(row)
	_check_cave_unlock()
	_pay_interest()
	if last_levels.is_empty() and not _has_pending_choice():
		return
	get_tree().create_timer(RECAP_DELAY).timeout.connect(_show_recap_after_report)

## Penambang Lv 2 membuka Gua Tambang (UnlockManager.try_unlock_cave).
func _check_cave_unlock() -> void:
	if UnlockManager.is_unlocked("cave"):
		return
	if UnlockManager.try_unlock_cave():
		Notify.say("Penambang Lv %d! Gua Tambang di Gunung kini terbuka." % UnlockManager.CAVE_MINER_LEVEL)

## Smart Investor (Economist Lv5 B): bunga harian dari uang bersama.
func _pay_interest() -> void:
	if SkillSystem.household(&"daily_interest") <= 0.0 or GameState.money <= 0:
		return
	var interest := mini(SkillSystem.RULES.interest_cap, floori(GameState.money * SkillSystem.RULES.interest_rate))
	if interest > 0:
		GameState.add_money(interest)
		Notify.say("Bunga tabungan: +%d G." % interest)

func _has_pending_choice() -> bool:
	for data in GameState.players:
		if data != null and data.skills != null and not data.skills.pending_choices().is_empty():
			return true
	return false

func _show_recap_after_report() -> void:
	var report: Node = GameState.shipping._report_ui
	if is_instance_valid(report) and report.is_inside_tree():
		report.tree_exited.connect(show_recap, CONNECT_ONE_SHOT | CONNECT_DEFERRED)
		return
	show_recap()

## Layar rekap: kenaikan level + pilihan cabang A/B yang belum dipilih.
func show_recap() -> void:
	if is_instance_valid(_ui) or (last_levels.is_empty() and not _has_pending_choice()):
		return
	_ui = LEVEL_UP_UI.instantiate()
	_ui.rows = last_levels.duplicate()
	add_child(_ui)
	last_levels.clear()
