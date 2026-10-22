class_name DefeatSequence
extends Node

## Urutan saat HP pemain habis: tumbang, dibawa ke Klinik (biaya perawatan dan sebagian
## barang hilang), lalu bangun di rumah. Stamina habis (exhausted): pingsan dan langsung
## dipulangkan seperti pingsan 05.10, tanpa klinik dan tanpa denda. Node ini hidup di root tree, jadi tetap berjalan
## walau scene solo diganti (Player lama ikut terhapus).

const LOCK := &"defeated"

var rules: DefeatRules
var player_index := 0
var exhausted := false
var _body: Player

## Stamina setelah bangun karena pingsan kelelahan (GDD: sama dengan pingsan 05.10).
const EXHAUSTED_STAMINA := 0.5

static func start(body: Player, p_rules: DefeatRules = null, p_exhausted: bool = false) -> DefeatSequence:
	var sequence := DefeatSequence.new()
	sequence.rules = p_rules if p_rules != null else Combat.DEFEAT_RULES
	sequence.exhausted = p_exhausted
	sequence.player_index = body.player_index
	sequence._body = body
	sequence.process_mode = Node.PROCESS_MODE_ALWAYS
	body.get_tree().root.add_child(sequence)
	sequence._run()
	return sequence

## Potong uang bersama dan sebagian barang acak. Mengembalikan {"money": int, "lost": Array[String]}.
## on_farm: tumbang di ladang (Economist Lv7 menghapus denda uang di sana).
static func apply_penalty(data: PlayerData, p_rules: DefeatRules, rng: RandomNumberGenerator = null, on_farm: bool = false) -> Dictionary:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var fee := floori(GameState.money * p_rules.money_penalty_percent / 100.0)
	if p_rules.money_penalty_max > 0:
		fee = mini(fee, p_rules.money_penalty_max)
	# Role Economist (GDD 13): denda pingsan -25%/-50%, gratis di ladang.
	fee = floori(fee * (1.0 - clampf(SkillSystem.stat(data, &"faint_penalty"), 0.0, 1.0)))
	if on_farm and SkillSystem.has(data, &"faint_farm_free"):
		fee = 0
	fee = clampi(fee, 0, GameState.money)
	if fee > 0:
		GameState.spend_money(fee)
	var candidates: Array[int] = []
	for slot in data.bag_size:
		var entry: Variant = data.inventory[slot]
		if entry != null and can_lose(entry["item"]):
			candidates.append(slot)
	var lost: Array[String] = []
	for i in mini(p_rules.item_loss_stacks, candidates.size()):
		var pick := rng.randi_range(i, candidates.size() - 1)
		var slot := candidates[pick]
		candidates[pick] = candidates[i]
		candidates[i] = slot
		var item: ItemData = data.inventory[slot]["item"]
		var count: int = data.inventory[slot]["count"]
		var amount := clampi(ceili(count * p_rules.item_loss_fraction), 0, count)
		if amount > 0 and data.remove_item_at(slot, amount):
			lost.append("%s x%d" % [item.display_name, amount])
	return {"money": fee, "lost": lost}

static func _in_farm(body: Node) -> bool:
	var node := body if is_instance_valid(body) else null
	while node != null:
		if node.scene_file_path.get_file().to_lower() == "farm.tscn":
			return true
		node = node.get_parent()
	return false

## Barang yang aman dari denda: alat, senjata, perlengkapan, bangunan, barang taruh, Biji Daya.
static func can_lose(item: ItemData) -> bool:
	if item == null or item.is_tool() or item.placeable:
		return false
	if item.category in [ItemData.Category.TOOL, ItemData.Category.EQUIPMENT, ItemData.Category.BUILDING]:
		return false
	return not item.item_id.begins_with("biji_daya")

func _run() -> void:
	var data := GameState.get_player(player_index)
	await get_tree().create_timer(rules.collapse_seconds, false).timeout
	if exhausted:
		await _run_exhausted(data)
		return

	var on_farm := _in_farm(_body)
	var penalty := apply_penalty(data, rules, null, on_farm)
	data.hp = maxi(1, ceili(data.max_hp * rules.hp_after_respawn))
	data.stamina = mini(data.stamina, ceili(data.max_stamina * rules.stamina_after_respawn))
	var solo := not Coop.has_root()

	# Klinik.
	await _travel(rules.clinic_scene, rules.clinic_position)
	_hold_body()
	var message := "Kamu tumbang dan dibawa ke Klinik Desa."
	message += " Biaya perawatan %d G." % int(penalty.money) if int(penalty.money) > 0 else " Perawatan gratis."
	var lost: Array = penalty.lost
	if not lost.is_empty():
		message += " Barang hilang: %s." % ", ".join(PackedStringArray(lost))
	Notify.say(message)
	await get_tree().create_timer(rules.clinic_seconds, false).timeout

	# Pulang dan bangun.
	if solo and rules.wake_next_morning:
		DayCycle.advance_day()
		DayCycle.hour = rules.wake_hour
		DayCycle.minute = 0
		DayCycle.time_tick.emit(DayCycle.hour, DayCycle.minute)
	await _travel(rules.respawn_scene, rules.respawn_position)
	_release_body()
	if solo:
		SaveManager.save_game()
	var hp_percent := roundi(rules.hp_after_respawn * 100.0)
	if solo and rules.wake_next_morning:
		Notify.say("Bangun di rumah pukul %02d.00 dengan HP %d%%." % [rules.wake_hour, hp_percent])
	else:
		Notify.say("Bangun di rumah dengan HP %d%%." % hp_percent)
	queue_free()

func _run_exhausted(data: PlayerData) -> void:
	var solo := not Coop.has_root()
	if solo and rules.wake_next_morning:
		DayCycle.advance_day()
		DayCycle.hour = rules.wake_hour
		DayCycle.minute = 0
		DayCycle.time_tick.emit(DayCycle.hour, DayCycle.minute)
	await _travel(rules.respawn_scene, rules.respawn_position)
	data.stamina = ceili(data.max_stamina * EXHAUSTED_STAMINA)
	_release_body()
	if solo:
		SaveManager.save_game()
	var percent := roundi(EXHAUSTED_STAMINA * 100.0)
	if solo and rules.wake_next_morning:
		Notify.say("Kamu pingsan karena kelelahan. Bangun di rumah pukul %02d.00 dengan energi %d%%." % [rules.wake_hour, percent])
	else:
		Notify.say("Kamu pingsan karena kelelahan dan dibawa pulang. Energi %d%%." % percent)
	queue_free()

func _travel(path: String, spawn: Vector2) -> void:
	GameState.next_spawn_position = spawn
	GameState.has_spawn_point = true
	var body := _current_body()
	if body == null:
		GameState.has_spawn_point = false
		return
	if Coop.has_root():
		await Transition.scene_transition(path, body)
		# CoopRoot memindahkan pemain dengan fade sendiri; tunggu sampai selesai.
		await get_tree().create_timer(0.9, false).timeout
	else:
		await Transition.scene_transition(path, body)

## Solo: Player dibuat ulang tiap ganti scene. Co-op: body yang sama dipindah area.
func _current_body() -> Player:
	if is_instance_valid(_body) and _body.is_inside_tree():
		return _body
	for node in get_tree().get_nodes_in_group("night_players"):
		if node is Player and node.player_index == player_index:
			_body = node
			return _body
	return null

## Di klinik pemain tetap terbaring dan tidak bisa bergerak.
func _hold_body() -> void:
	var body := _current_body()
	if body == null:
		return
	body.set_input_locked(LOCK, true)
	body.animation_controller.set_visual_override(&"sleep")

func _release_body() -> void:
	var body := _current_body()
	if body == null:
		return
	body.finish_defeat()
