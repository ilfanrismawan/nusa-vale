class_name BalaiNadiUI
extends CanvasLayer

const Presentation = preload("res://scripts/resources/balai_nadi_presentation.gd")
@export var presentation: Presentation = preload("res://resources/ui/balai_nadi_presentation.tres")
@export var bundle_scene: PackedScene = preload("res://scenes/ui/balai_bundle_card.tscn")
@export var requirement_scene: PackedScene = preload("res://scenes/ui/balai_requirement_card.tscn")
@export var wing_scene: PackedScene = preload("res://scenes/ui/balai_wing_button.tscn")
@export var design_size := Vector2(1280, 720)
@export_range(1, 4) var bundles_per_page := 4
@export_range(1, 4) var requirements_per_page := 4

var player: Player
@export var project_id := "balai_nadi_restoration"
var _opened := false
var _rows: Dictionary = {}
var _wing := "all"
var _bundle_page := 0
var _requirement_page := 0
var _selected_item := ""
var _submitting := false
var _projects: Array[RestorationProject] = []
var _requirements_signature := ""
@onready var _status: Label = %Status
@onready var _quantity: SpinBox = %Quantity

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = FarmServiceTheme.LAYER
	%Close.pressed.connect(close_menu)
	%PreviousBundles.pressed.connect(_change_bundle_page.bind(-1))
	%NextBundles.pressed.connect(_change_bundle_page.bind(1))
	%PreviousRequirements.pressed.connect(_change_requirement_page.bind(-1))
	%NextRequirements.pressed.connect(_change_requirement_page.bind(1))
	%Donate.pressed.connect(_donate)
	%Maximum.pressed.connect(_set_maximum)
	get_viewport().size_changed.connect(_resize)
	GameState.inventory_changed.connect(_refresh)
	GameState.money_changed.connect(_money_changed)
	GameState.balai_nadi.state_changed.connect(_refresh)
	_build_wings()
	_opened = true
	Coop.set_menu_open(player, true)
	_select_wing("all")
	_resize()
	_focus_initial.call_deferred()

func _focus_initial() -> void:
	if _opened and is_inside_tree() and %Wings.get_child_count() > 0:
		%Wings.get_child(0).grab_focus()

func _resize() -> void:
	var view := get_viewport().get_visible_rect().size
	var fit := minf(view.x / design_size.x, view.y / design_size.y)
	$Design.scale = Vector2.ONE * fit
	$Design.position = (view - design_size * fit) * 0.5

func _clear(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

func _build_wings() -> void:
	_clear(%Wings)
	for wing in presentation.wing_order:
		var button := wing_scene.instantiate() as Button
		%Wings.add_child(button)
		button.text = presentation.wing_labels.get(wing, wing.capitalize())
		button.set_meta("wing", wing)
		button.pressed.connect(_select_wing.bind(wing))

func _select_wing(wing: String) -> void:
	_wing = wing
	_bundle_page = 0
	_projects.clear()
	for project in GameState.balai_nadi.definitions:
		if wing == "all" or project.wing_id == wing:
			_projects.append(project)
	for button in %Wings.get_children():
		button.set_pressed_no_signal(button.get_meta("wing") == wing)
	%WingTitle.text = presentation.wing_labels.get(wing, wing.capitalize())
	%Empty.text = presentation.empty_message
	%Empty.visible = _projects.is_empty()
	%Detail.visible = not _projects.is_empty()
	%RewardPanel.visible = not _projects.is_empty()
	if not _projects.is_empty():
		var exists := _projects.any(func(project): return project.project_id == project_id)
		if not exists:
			project_id = _projects[0].project_id
		for index in _projects.size():
			if _projects[index].project_id == project_id:
				_bundle_page = index / bundles_per_page
				break
		_select_project_id(project_id)
	_build_bundle_cards()
	_refresh()

func _filtered_projects() -> Array[RestorationProject]:
	return _projects

func _change_bundle_page(direction: int) -> void:
	var pages := maxi(1, ceili(float(_projects.size()) / bundles_per_page))
	_bundle_page = posmod(_bundle_page + direction, pages)
	_build_bundle_cards()

func _build_bundle_cards() -> void:
	_clear(%Bundles)
	var end := mini((_bundle_page + 1) * bundles_per_page, _projects.size())
	for index in range(_bundle_page * bundles_per_page, end):
		var project := _projects[index]
		var card := bundle_scene.instantiate() as Button
		%Bundles.add_child(card)
		card.get_node("Icon").texture = _project_icon(project)
		card.get_node("Title").text = project.ui_short_name if not project.ui_short_name.is_empty() else project.display_name
		card.set_meta("project_id", project.project_id)
		card.pressed.connect(_select_project_id.bind(project.project_id))
	var pages := maxi(1, ceili(float(_projects.size()) / bundles_per_page))
	%BundlePage.text = "%d / %d" % [_bundle_page + 1, pages]
	%PreviousBundles.disabled = pages <= 1
	%NextBundles.disabled = pages <= 1
	_update_bundle_progress()

func _project_icon(project: RestorationProject) -> Texture2D:
	if project.ui_icon != null:
		return project.ui_icon
	for id in project.requirements:
		var item := GameState._resolve_item(id) if id != "money" else null
		if item != null:
			return item.icon
	return presentation.default_icon

func _select_project(index: int) -> void:
	if index >= 0 and index < GameState.balai_nadi.definitions.size():
		_select_project_id(GameState.balai_nadi.definitions[index].project_id)

func _select_project_id(id: String) -> void:
	var project := GameState.balai_nadi.definition(id)
	if project == null:
		return
	project_id = id
	_requirement_page = 0
	_selected_item = str(project.requirements.keys()[0]) if not project.requirements.is_empty() else ""
	_requirements_signature = ""
	_build_requirements()
	_refresh()

func _change_requirement_page(direction: int) -> void:
	var project := GameState.balai_nadi.definition(project_id)
	var pages := maxi(1, ceili(float(project.requirements.size()) / requirements_per_page))
	_requirement_page = posmod(_requirement_page + direction, pages)
	var ids := project.requirements.keys()
	if not ids.is_empty():
		_selected_item = str(ids[_requirement_page * requirements_per_page])
	_build_requirements()
	_refresh()

func _build_requirements() -> void:
	_clear(%Requirements)
	_rows.clear()
	var project := GameState.balai_nadi.definition(project_id)
	if project == null:
		return
	var ids := project.requirements.keys()
	var end := mini((_requirement_page + 1) * requirements_per_page, ids.size())
	for index in range(_requirement_page * requirements_per_page, end):
		var id: String = ids[index]
		var card := requirement_scene.instantiate() as Button
		%Requirements.add_child(card)
		var item := GameState._resolve_item(id) if id != "money" else null
		card.get_node("Icon").texture = item.icon if item != null else presentation.money_icon
		card.get_node("Name").text = item.display_name if item != null else "Dana bersama"
		card.set_meta("item_id", id)
		card.pressed.connect(_select_requirement.bind(id))
		_rows[id] = {"button": card, "label": card.get_node("Count"), "bar": card.get_node("Progress")}
	var pages := maxi(1, ceili(float(ids.size()) / requirements_per_page))
	%RequirementPage.text = "Kebutuhan %d / %d" % [_requirement_page + 1, pages]
	%PreviousRequirements.disabled = pages <= 1
	%NextRequirements.disabled = pages <= 1

func _select_requirement(id: String) -> void:
	if not GameState.balai_nadi.definition(project_id).requirements.has(id):
		return
	_selected_item = id
	_requirements_signature = ""
	_refresh()

func _money_changed(_money: int) -> void:
	_refresh()

func _update_bundle_progress() -> void:
	var manager := GameState.balai_nadi
	var completed := 0
	for project in manager.definitions:
		if manager.completed(project.project_id):
			completed += 1
	%OverallProgress.max_value = maxi(1, manager.definitions.size())
	%OverallProgress.value = completed
	%Overall.text = "%d / %d paket selesai · %s" % [completed, manager.definitions.size(), manager.restoration_stage()]
	for card in %Bundles.get_children():
		var id: String = card.get_meta("project_id")
		var project := manager.definition(id)
		var filled := 0
		for item_id in project.requirements:
			if manager.remaining(id, item_id) <= 0:
				filled += 1
		card.set_pressed_no_signal(id == project_id)
		card.get_node("Progress").max_value = maxi(1, project.requirements.size())
		card.get_node("Progress").value = filled
		card.get_node("ProgressText").text = "Lengkap ✓" if manager.completed(id) else "%d / %d terpenuhi" % [filled, project.requirements.size()]

func _refresh() -> void:
	if not _opened or _submitting:
		return
	var manager := GameState.balai_nadi
	%Owner.text = "Bahan: tas P%d · Dana bersama: %d G" % [player.data.index + 1, GameState.money]
	_update_bundle_progress()
	var project := manager.definition(project_id)
	if project == null:
		return
	%ProjectTitle.text = project.display_name
	%Description.text = project.description
	%ProjectIcon.texture = _project_icon(project)
	%CompletedStamp.visible = manager.completed(project_id)
	%CompletedStamp.text = presentation.complete_label
	for id in _rows:
		var row: Dictionary = _rows[id]
		var amount := manager.contributed(project_id, id)
		var needed := manager.required(project, id)
		var remaining := manager.remaining(project_id, id)
		row.label.text = "%d / %d" % [mini(amount, needed), needed]
		row.bar.max_value = maxi(1, needed)
		row.bar.value = mini(amount, needed)
		row.button.set_pressed_no_signal(id == _selected_item)
		row.button.get_node("Check").visible = remaining == 0
	var left := manager.remaining(project_id, _selected_item)
	var available := manager.available_amount(player.data, _selected_item)
	var maximum := mini(left, available)
	var ready := manager.ready_to_finish(project_id)
	var finished := manager.completed(project_id)
	var signature := "%s:%s:%d:%s" % [project_id, _selected_item, maximum, finished]
	if signature != _requirements_signature:
		var reset_amount := _requirements_signature.is_empty() or _quantity.value <= 0
		var previous_amount := _quantity.value
		_requirements_signature = signature
		_quantity.min_value = 0 if maximum <= 0 else 1
		_quantity.max_value = maximum
		_quantity.value = maximum if reset_amount else clampf(previous_amount, _quantity.min_value, maximum)
	_quantity.editable = maximum > 0 and not finished
	%Maximum.disabled = maximum <= 0 or finished
	%Donate.disabled = finished or (maximum <= 0 and not ready) or _selected_item.is_empty()
	%Donate.text = "Paket Lengkap" if finished else "Selesaikan Paket" if ready else "Sumbangkan"
	var title := "Dana bersama" if _selected_item == "money" else ""
	var selected := GameState._resolve_item(_selected_item) if _selected_item != "money" else null
	if selected != null:
		title = selected.display_name
	_status.text = "Tahap: %s\n%s" % [manager.restoration_stage(), project.completion_message if finished else "%s · Sisa %d · Tersedia %d. Pilih jumlah sebelum menyumbang." % [title, left, available]]
	%Reward.text = _reward_text(project)
	%RewardIcon.texture = _project_icon(project)
	if not project.reward_items.is_empty():
		var reward := GameState._resolve_item(str(project.reward_items.keys()[0]))
		if reward != null:
			%RewardIcon.texture = reward.icon

func _reward_text(project: RestorationProject) -> String:
	var rewards := PackedStringArray()
	for id in project.reward_items:
		var item := GameState._resolve_item(id)
		rewards.append("%s ×%d" % [item.display_name if item != null else id, project.reward_items[id]])
	rewards.append("%d Token Talenta" % SkillSystem.RULES.balai_tokens)
	return "%s\n%s · Diberikan otomatis setelah paket lengkap." % [project.completion_message, " · ".join(rewards)]

func _set_maximum() -> void:
	_quantity.value = _quantity.max_value

func _donate() -> void:
	if not _opened or _submitting or _projects.is_empty() or %Donate.disabled:
		return
	var manager := GameState.balai_nadi
	var requested := 1 if manager.ready_to_finish(project_id) else int(_quantity.value)
	if requested <= 0:
		return
	_submitting = true
	var accepted := manager.contribute(player.data, project_id, _selected_item, requested)
	_submitting = false
	_refresh()
	if accepted <= 0 and not manager.completed(project_id):
		_status.text = "Kontribusi belum diterima. Periksa bahan dan penyimpanan, lalu coba lagi."

func _contribute(item_id: String) -> void:
	_select_requirement(item_id)
	_donate()

func _input(event: InputEvent) -> void:
	if not _opened or not Coop.accepts_event(player, event):
		return
	if player.input.is_event(event, &"ui_cancel") or player.input.is_event(event, &"inventory"):
		get_viewport().set_input_as_handled()
		close_menu()
	elif event is InputEventMouseButton and not player.input.uses_mouse():
		get_viewport().set_input_as_handled()

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
