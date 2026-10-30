class_name BalaiNadiUI
extends CanvasLayer
## Menu Balai Nadi gaya AssistiveTouch (GDD 4.9.1): tombol inti di tengah mekar menjadi
## lingkaran sayap, lalu lingkaran paket, lalu kartu kaca untuk menyumbang.
## Stik/WASD menunjuk kelopak sesuai arah, A/E pilih, B/Esc kembali satu tingkat.

enum Level { WINGS, BUNDLES, CARD }

const Presentation = preload("res://scripts/resources/balai_nadi_presentation.gd")
const Petal = preload("res://scripts/ui/balai_radial_petal.gd")
@export var presentation: Presentation = preload("res://resources/ui/balai_nadi_presentation.tres")
@export var petal_scene: PackedScene = preload("res://scenes/ui/balai_radial_petal.tscn")
@export var slot_scene: PackedScene = preload("res://scenes/ui/balai_requirement_slot.tscn")
@export var design_size := Vector2(1280, 720)
@export_group("Lingkaran")
@export var wing_radius := 190.0
@export var bundle_radius := 200.0
## Jarak kelopak terpilih bergeser keluar.
@export var selected_push := 18.0
@export var float_amplitude := 5.0
@export var float_speed := 2.2
## Seberapa jauh seluruh lingkaran condong ke arah stik.
@export var tilt_strength := 14.0
@export var bloom_time := 0.18
@export_group("Kartu")
@export var card_float := 3.0
@export var nav_repeat_delay := 0.35
@export var nav_repeat_rate := 0.12

var player: Player
@export var project_id := "balai_nadi_restoration"
var _opened := false
var _level := Level.WINGS
var _wing := ""
var _projects: Array[RestorationProject] = []
var _rows: Dictionary = {}
var _selected_item := ""
var _submitting := false
var _wings_open := false
var _petals: Array[Petal] = []
var _sel := 0
var _time := 0.0
var _bloom := 0.0
var _tilt := Vector2.ZERO
var _nav_held := Vector2i.ZERO
var _nav_timer := 0.0
var _card_base := Vector2.ZERO
@onready var _status: Label = %Status

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = FarmServiceTheme.LAYER
	_card_base = %Card.position
	%Donate.pressed.connect(_donate)
	%DonateAll.pressed.connect(_donate_all)
	%Back.pressed.connect(_back)
	%Core.chosen.connect(func(_petal): _back())
	get_viewport().size_changed.connect(_resize)
	GameState.inventory_changed.connect(_refresh)
	GameState.money_changed.connect(_money_changed)
	GameState.balai_nadi.state_changed.connect(_refresh)
	_opened = true
	Coop.set_menu_open(player, true)
	_wings_open = GameState.balai_nadi.wings_unlocked()
	_show_wings()
	_resize()

func _resize() -> void:
	var view := get_viewport().get_visible_rect().size
	var fit := minf(view.x / design_size.x, view.y / design_size.y)
	$Design.scale = Vector2.ONE * fit
	$Design.position = (view - design_size * fit) * 0.5

func _clear(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


# ── Tingkat 1 & 2: lingkaran ───────────────────────────────────────

func _projects_of(wing: String) -> Array[RestorationProject]:
	var list: Array[RestorationProject] = []
	for project in GameState.balai_nadi.available_projects():
		if project.wing_id == wing:
			list.append(project)
	return list

func _done_count(list: Array[RestorationProject]) -> int:
	var done := 0
	for project in list:
		if GameState.balai_nadi.completed(project.project_id):
			done += 1
	return done

## Kembali ke lingkaran sayap. Sebelum Balai Utama pulih, sayap lain tetap tersembunyi:
## kelopaknya langsung paket yang tersedia (hanya Pulihkan Balai).
func _show_wings(focus_key := "") -> void:
	_level = Level.WINGS
	_wing = ""
	_projects = GameState.balai_nadi.available_projects()
	var entries: Array[Dictionary] = []
	if _wings_open:
		for wing in presentation.radial_wings:
			if not _projects_of(wing).is_empty():
				entries.append({"kind": "wing", "key": wing})
	else:
		for project in _projects:
			entries.append({"kind": "project", "key": project.project_id})
	# Teks minimal: judul hanya di lingkaran paket (nama sayap).
	%Title.text = ""
	%Core.set_back(false)
	_build_petals(entries, focus_key)
	_show_level()

## Kompatibel dengan pemanggil lama: "all" = lingkaran sayap.
func _select_wing(wing: String) -> void:
	if wing == "all":
		_show_wings()
		return
	var list := _projects_of(wing)
	if list.is_empty():
		return
	_wing = wing
	if list.size() == 1:
		_select_project_id(list[0].project_id)
		return
	_level = Level.BUNDLES
	_projects = list
	var entries: Array[Dictionary] = []
	for project in list:
		entries.append({"kind": "project", "key": project.project_id})
	%Title.text = presentation.wing_labels.get(wing, wing.capitalize())
	%Core.set_back(true)
	_build_petals(entries, project_id)
	_show_level()

func _filtered_projects() -> Array[RestorationProject]:
	return _projects

func _build_petals(entries: Array[Dictionary], focus_key: String) -> void:
	_clear(%Petals)
	_petals.clear()
	_sel = 0
	for index in entries.size():
		var petal := petal_scene.instantiate() as Petal
		%Petals.add_child(petal)
		petal.set_meta("entry", entries[index])
		petal.chosen.connect(_on_petal_chosen)
		petal.hovered.connect(_on_petal_hovered)
		_petals.append(petal)
		if entries[index].key == focus_key:
			_sel = index
	_bloom = 0.0
	_update_petals()
	_set_selection(_sel)

func _wing_icon(wing: String) -> Texture2D:
	var item_id: String = presentation.wing_icon_items.get(wing, "")
	var item := GameState._resolve_item(item_id) if not item_id.is_empty() else null
	return item.icon if item != null else presentation.default_icon

func _project_icon(project: RestorationProject) -> Texture2D:
	if project.ui_icon != null:
		return project.ui_icon
	for id in project.requirements:
		var item := GameState._resolve_item(id) if id != "money" else null
		if item != null:
			return item.icon
	return presentation.default_icon

func _short_name(project: RestorationProject) -> String:
	return project.ui_short_name if not project.ui_short_name.is_empty() else project.display_name

func _update_petals() -> void:
	var manager := GameState.balai_nadi
	for petal in _petals:
		var entry: Dictionary = petal.get_meta("entry")
		if entry.kind == "wing":
			var list := _projects_of(entry.key)
			var done := _done_count(list)
			petal.setup(_wing_icon(entry.key), float(done) / maxi(1, list.size()), "%d/%d" % [done, list.size()], presentation.wing_short.get(entry.key, entry.key.capitalize()), done == list.size())
		else:
			var project := manager.definition(entry.key)
			var needed := manager.slots_needed(project)
			var filled := mini(manager.filled_slots(project), needed)
			petal.setup(_project_icon(project), float(filled) / maxi(1, needed), "%d/%d" % [filled, needed], _short_name(project), manager.completed(project.project_id))
	if _level == Level.BUNDLES:
		var done := _done_count(_projects)
		%Core.setup(_wing_icon(_wing), float(done) / maxi(1, _projects.size()), "%d/%d" % [done, _projects.size()], "", done == _projects.size())
	else:
		var shown := manager.available_projects()
		var done := _done_count(shown)
		%Core.setup(presentation.default_icon, float(done) / maxi(1, shown.size()), "%d/%d" % [done, shown.size()], "", false)

func _set_selection(index: int) -> void:
	if _petals.is_empty():
		return
	index = clampi(index, 0, _petals.size() - 1)
	if index != _sel and _opened and is_inside_tree():
		Juice.play_sound(&"swish", 6.0)
	_sel = index
	for i in _petals.size():
		_petals[i].set_selected(i == _sel)
	_update_bonus()

func _petal_dir(index: int) -> Vector2:
	if _petals.size() <= 1:
		return Vector2.UP
	return Vector2.from_angle(-PI * 0.5 + TAU * index / _petals.size())

func _on_petal_hovered(petal: Petal) -> void:
	if _level != Level.CARD:
		_set_selection(_petals.find(petal))

func _on_petal_chosen(petal: Petal) -> void:
	if _level == Level.CARD:
		return
	_set_selection(_petals.find(petal))
	_activate()

func _activate() -> void:
	if _petals.is_empty():
		return
	var entry: Dictionary = _petals[_sel].get_meta("entry")
	Juice.play_sound(&"pickup")
	if entry.kind == "wing":
		_select_wing(entry.key)
	else:
		_select_project_id(entry.key)

## Bonus sayap hanya tampil di sebelah kelopak sayap yang sedang dipilih.
func _update_bonus() -> void:
	%BonusPill.visible = false
	if _level != Level.WINGS or _petals.is_empty():
		return
	var entry: Dictionary = _petals[_sel].get_meta("entry")
	var wing := GameState.balai_nadi.wing(entry.key) if entry.kind == "wing" else null
	if wing == null or wing.bonus_text.is_empty():
		return
	%BonusLabel.text = ("Aktif: %s ✓" if GameState.balai_nadi.wing_completed(wing.wing_id) else "Bonus: %s") % wing.bonus_text
	var width: float = %BonusLabel.get_minimum_size().x + 36.0
	%BonusPill.size = Vector2(width, 48)
	%BonusPill.visible = true


# ── Gerak: mekar, melayang, condong ke arah stik ───────────────────

func _process(delta: float) -> void:
	if not _opened:
		return
	_time += delta
	_bloom = move_toward(_bloom, 1.0, delta / maxf(0.01, bloom_time))
	var aim := player.input.get_vector() if is_instance_valid(player) else Vector2.ZERO
	if _level == Level.CARD:
		_card_nav(aim, delta)
		%Card.position = _card_base + Vector2(0, sin(_time * 2.0) * card_float)
		return
	if aim.length() > 0.5 and _petals.size() > 1:
		var best := 0
		for i in _petals.size():
			if aim.dot(_petal_dir(i)) > aim.dot(_petal_dir(best)):
				best = i
		if best != _sel:
			_set_selection(best)
	var target := aim * tilt_strength if aim.length() > 0.2 else _petal_dir(_sel) * tilt_strength * 0.5
	_tilt = _tilt.lerp(target, 1.0 - exp(-delta * 8.0))
	_layout()

func _layout() -> void:
	var opened := ease(_bloom, 0.4)
	var radius := wing_radius if _level == Level.WINGS else bundle_radius
	var bob := Vector2(0, sin(_time * 2.0) * float_amplitude * 0.6)
	%Core.position = -%Core.size * 0.5 + _tilt * 0.6 + bob
	%Core.get_node("%Glass").light_dir = Vector2(-0.35, -1.0) - _tilt / maxf(1.0, tilt_strength) * 0.8
	for i in _petals.size():
		var petal := _petals[i]
		var dir := _petal_dir(i)
		var float_y := sin(_time * float_speed + i * 1.3) * float_amplitude
		var spot := dir * (radius * opened + selected_push * petal.push) + Vector2(0, float_y) + _tilt * 0.4
		petal.position = spot - petal.size * 0.5
		petal.modulate.a = opened
	if %BonusPill.visible:
		var petal := _petals[_sel]
		var center := petal.position + petal.size * 0.5
		var right := _petal_dir(_sel).x >= -0.1
		%BonusPill.position = center + Vector2(64 if right else -64 - %BonusPill.size.x, -%BonusPill.size.y * 0.5)


# ── Tingkat 3: kartu paket ─────────────────────────────────────────

func _select_project(index: int) -> void:
	if index >= 0 and index < GameState.balai_nadi.definitions.size():
		_select_project_id(GameState.balai_nadi.definitions[index].project_id)

func _select_project_id(id: String) -> void:
	var manager := GameState.balai_nadi
	var project := manager.definition(id)
	if project == null or not manager.project_available(project):
		return
	project_id = id
	_wing = project.wing_id
	_level = Level.CARD
	_selected_item = ""
	for item_id in project.requirements:
		if manager.remaining(id, item_id) > 0:
			_selected_item = item_id
			break
	if _selected_item.is_empty() and not project.requirements.is_empty():
		_selected_item = str(project.requirements.keys()[0])
	_build_requirements()
	_show_level()
	%Card.scale = Vector2.ONE * 0.86
	%Card.modulate.a = 0.0
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(%Card, "scale", Vector2.ONE, bloom_time * 1.4)
	tween.tween_property(%Card, "modulate:a", 1.0, bloom_time)

func _build_requirements() -> void:
	_clear(%Requirements)
	_rows.clear()
	var project := GameState.balai_nadi.definition(project_id)
	if project == null:
		return
	for id in project.requirements:
		var slot := slot_scene.instantiate() as Button
		%Requirements.add_child(slot)
		var item := GameState._resolve_item(id) if id != "money" else null
		slot.get_node("%Icon").texture = item.icon if item != null else presentation.money_icon
		slot.set_meta("item_id", id)
		slot.pressed.connect(_select_requirement.bind(id))
		_rows[id] = {"button": slot, "label": slot.get_node("%Count"), "check": slot.get_node("%Check"), "icon": slot.get_node("%Icon")}

func _select_requirement(id: String) -> void:
	if _level != Level.CARD:
		_select_project_id(project_id)
	var project := GameState.balai_nadi.definition(project_id)
	if project == null or not project.requirements.has(id):
		return
	_selected_item = id
	_refresh()

func _card_nav(aim: Vector2, delta: float) -> void:
	var dir := Vector2i(int(signf(aim.x)) if absf(aim.x) > 0.5 else 0, int(signf(aim.y)) if absf(aim.y) > 0.5 else 0)
	if dir == Vector2i.ZERO:
		_nav_held = dir
		return
	if dir != _nav_held:
		_nav_held = dir
		_nav_timer = nav_repeat_delay
	else:
		_nav_timer -= delta
		if _nav_timer > 0.0:
			return
		_nav_timer = nav_repeat_rate
	var ids: Array = _rows.keys()
	var columns: int = %Requirements.columns
	var index := ids.find(_selected_item)
	var next := index + dir.x + dir.y * columns
	if next >= 0 and next < ids.size() and (dir.y != 0 or next / columns == index / columns):
		Juice.play_sound(&"swish", 6.0)
		_select_requirement(str(ids[next]))

func _short(value: int) -> String:
	return "%.1fk" % (value / 1000.0) if value >= 10000 else str(value)

func _money_changed(_money: int) -> void:
	_refresh()


# ── Penyegaran ─────────────────────────────────────────────────────

func _show_level() -> void:
	%Radial.visible = _level != Level.CARD
	%Card.visible = _level == Level.CARD
	_update_bonus()
	_refresh()

func _hint(pad_key: String, key: String, label: String) -> String:
	var pad := is_instance_valid(player) and player.input.prefers_pad()
	return "[%s] %s" % [pad_key if pad else key, label]

func _update_hints() -> void:
	var parts := PackedStringArray()
	match _level:
		Level.WINGS:
			parts = PackedStringArray([_hint("A", "E", "Pilih"), _hint("B", "Esc", "Tutup")])
		Level.BUNDLES:
			parts = PackedStringArray([_hint("A", "E", "Buka"), _hint("B", "Esc", "Kembali")])
		Level.CARD:
			parts = PackedStringArray([_hint("A", "E", "Sumbang"), _hint("Y", "R", "Semua"), _hint("B", "Esc", "Kembali")])
	%HintLabel.text = "    ".join(parts)
	var width: float = %HintLabel.get_minimum_size().x + 48.0
	%Hints.size = Vector2(width, 48)
	%Hints.position.x = (design_size.x - width) * 0.5

func _refresh() -> void:
	if not _opened or _submitting:
		return
	var manager := GameState.balai_nadi
	if manager.wings_unlocked() != _wings_open:
		_wings_open = manager.wings_unlocked()
		if _level != Level.CARD:
			_show_wings()
			return
	_update_hints()
	if _level != Level.CARD:
		_update_petals()
		_update_bonus()
		return
	var project := manager.definition(project_id)
	if project == null:
		return
	var needed := manager.slots_needed(project)
	var filled := mini(manager.filled_slots(project), needed)
	var finished := manager.completed(project_id)
	var ready := manager.ready_to_finish(project_id)
	%Header.setup(_project_icon(project), float(filled) / maxi(1, needed), "", "", finished)
	%CardTitle.text = _short_name(project)
	%CardProgress.text = "Terisi %d dari %d" % [filled, needed]
	%CompletedStamp.text = presentation.complete_label
	%CompletedStamp.visible = finished
	for id in _rows:
		var row: Dictionary = _rows[id]
		var amount := manager.contributed(project_id, id)
		var need := manager.required(project, id)
		var left := manager.remaining(project_id, id)
		var have := manager.available_amount(player.data, id)
		row.label.text = "%s / %s" % [_short(mini(amount, need)), _short(need)]
		row.check.visible = left == 0 and amount >= need
		row.icon.modulate.a = 1.0 if have > 0 or amount >= need or finished else 0.45
		row.button.set_selected(id == _selected_item)
	var left := manager.remaining(project_id, _selected_item)
	var have := manager.available_amount(player.data, _selected_item)
	var item := GameState._resolve_item(_selected_item) if _selected_item != "money" else null
	var title := item.display_name if item != null else "Dana bersama"
	if _selected_item.is_empty():
		%ItemName.text = ""
	elif left > 0:
		%ItemName.text = "%s · punya %s" % [title, _short(have)]
	else:
		%ItemName.text = "%s ✓" % title
	%Donate.disabled = finished or (mini(left, have) <= 0 and not ready) or _selected_item.is_empty()
	%Donate.text = "Selesaikan" if ready else "Sumbang"
	%DonateAll.disabled = finished or not (ready or _any_donatable(project))
	_status.text = project.completion_message if finished else ""
	var reward_icon := presentation.default_icon
	%RewardCount.text = ""
	if not project.reward_items.is_empty():
		var reward_id := str(project.reward_items.keys()[0])
		var reward := GameState._resolve_item(reward_id)
		if reward != null:
			reward_icon = reward.icon
		%RewardCount.text = "×%d" % int(project.reward_items[reward_id])
	%RewardIcon.texture = reward_icon
	%RewardTokens.text = "+%d Talenta" % SkillSystem.RULES.balai_tokens

func _any_donatable(project: RestorationProject) -> bool:
	for id in project.requirements:
		if mini(GameState.balai_nadi.remaining(project_id, id), GameState.balai_nadi.available_amount(player.data, id)) > 0:
			return true
	return false


# ── Menyumbang ─────────────────────────────────────────────────────

func _donate() -> void:
	if not _opened or _submitting or _level != Level.CARD or %Donate.disabled:
		return
	var manager := GameState.balai_nadi
	var requested := 1 if manager.ready_to_finish(project_id) else mini(manager.remaining(project_id, _selected_item), manager.available_amount(player.data, _selected_item))
	if requested <= 0:
		return
	var donated_id := _selected_item
	_submitting = true
	var accepted := manager.contribute(player.data, project_id, donated_id, requested)
	_submitting = false
	_after_donation(accepted > 0, [donated_id])

## Sumbangkan semua bahan yang dimiliki untuk paket ini sekaligus.
func _donate_all() -> void:
	if not _opened or _submitting or _level != Level.CARD or %DonateAll.disabled:
		return
	var manager := GameState.balai_nadi
	var project := manager.definition(project_id)
	var donated: Array[String] = []
	_submitting = true
	for id in project.requirements:
		if manager.completed(project_id):
			break
		var amount := mini(manager.remaining(project_id, id), manager.available_amount(player.data, id))
		if amount > 0 and manager.contribute(player.data, project_id, id, amount) > 0:
			donated.append(id)
	if manager.ready_to_finish(project_id) and not project.requirements.is_empty():
		manager.contribute(player.data, project_id, str(project.requirements.keys()[0]), 1)
	_submitting = false
	_after_donation(not donated.is_empty() or manager.completed(project_id), donated)

func _after_donation(success: bool, ids: Array) -> void:
	var manager := GameState.balai_nadi
	_refresh()
	if not success and not manager.completed(project_id):
		_status.text = "Belum bisa menyumbang. Periksa bahan di tas."
		return
	Juice.play_sound(&"sparkle" if manager.completed(project_id) else &"pickup")
	for id in ids:
		if _rows.has(id):
			_rows[id].button.pulse()
	# Lanjut ke kebutuhan berikutnya yang masih bisa diisi.
	if manager.remaining(project_id, _selected_item) == 0:
		for id in _rows:
			if manager.remaining(project_id, id) > 0 and manager.available_amount(player.data, id) > 0:
				_select_requirement(id)
				break

func _contribute(item_id: String) -> void:
	_select_requirement(item_id)
	_donate()


# ── Input & tutup ──────────────────────────────────────────────────

func _back() -> void:
	match _level:
		Level.CARD:
			var focus := project_id
			if not _wing.is_empty() and _wings_open and _projects_of(_wing).size() > 1:
				_select_wing(_wing)
				_set_selection(_petals.find_custom(func(p): return p.get_meta("entry").key == focus))
			else:
				_show_wings(_wing if _wings_open else focus)
		Level.BUNDLES:
			_show_wings(_wing)
		_:
			close_menu()

func _input(event: InputEvent) -> void:
	if not _opened or not Coop.accepts_event(player, event):
		return
	if event is InputEventMouseButton and not player.input.uses_mouse():
		get_viewport().set_input_as_handled()
		return
	if player.input.is_event(event, &"ui_cancel") or player.input.is_event(event, &"inventory"):
		get_viewport().set_input_as_handled()
		_back()
	elif event is InputEventMouseButton:
		return
	elif player.input.is_event(event, &"ui_accept") or player.input.is_event(event, &"interact"):
		get_viewport().set_input_as_handled()
		if _level == Level.CARD:
			_donate()
		else:
			_activate()
	elif _level == Level.CARD and (player.input.is_event(event, &"crafting_menu") or player.input.is_event(event, &"sort_inventory")):
		get_viewport().set_input_as_handled()
		_donate_all()

func close_menu() -> void:
	if not _opened:
		return
	_opened = false
	set_process_input(false)
	hide()
	Coop.set_menu_open(player, false)
	queue_free()

func _exit_tree() -> void:
	if _opened and is_instance_valid(player):
		Coop.set_menu_open(player, false)
