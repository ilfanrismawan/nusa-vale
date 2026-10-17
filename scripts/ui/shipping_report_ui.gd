extends CanvasLayer

@export var design_size := Vector2(1280, 720)
@export var row_scene: PackedScene = preload("res://scenes/ui/shipping_report_row.tscn")
var report: Dictionary = {}
var _closed := false
var _pause_reason: StringName

func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_pause_reason = StringName("shipping_report_%d" % get_instance_id())
	PauseManager.set_reason(_pause_reason, true)
	%Continue.pressed.connect(_close)
	get_viewport().size_changed.connect(_resize)
	_resize()
	_populate()
	%Continue.grab_focus()

func _resize() -> void:
	var view := get_viewport().get_visible_rect().size
	var fit := minf(view.x / design_size.x, view.y / design_size.y)
	$Design.scale = Vector2.ONE * fit
	$Design.position = (view - design_size * fit) * 0.5

func _populate() -> void:
	var day := maxi(1, int(report.get("day", 1)))
	var season_index := floori(float(day - 1) / DayCycle.DAYS_PER_SEASON) % DayCycle.SEASONS.size()
	var year := floori(float(day - 1) / (DayCycle.DAYS_PER_SEASON * DayCycle.SEASONS.size())) + 1
	%Date.text = "%s · Hari %d · Tahun %d" % [SaveManager.SEASON_NAMES[season_index], (day - 1) % DayCycle.DAYS_PER_SEASON + 1, year]
	var rows: Array = report.get("rows", [])
	var quantity := 0
	for entry in rows:
		var row := row_scene.instantiate()
		%Rows.add_child(row)
		var item := GameState._resolve_item(str(entry.id))
		row.get_node("Icon").texture = item.icon if item != null else null
		row.get_node("Name").text = str(entry.name)
		row.get_node("UnitPrice").text = "%s G" % SaveSlotMenu._format_money(int(entry.price))
		row.get_node("Quantity").text = "×%d" % int(entry.count)
		row.get_node("Subtotal").text = "%s G" % SaveSlotMenu._format_money(int(entry.price) * int(entry.count))
		quantity += int(entry.count)
	%Empty.visible = rows.is_empty()
	%Totals.text = "%s G" % SaveSlotMenu._format_money(int(report.get("total", 0)))
	%Stats.text = "%d jenis barang\n%d item terjual" % [rows.size(), quantity]
	%Balance.text = "%s G" % SaveSlotMenu._format_money(GameState.money)

func _input(event: InputEvent) -> void:
	if _closed or not Coop.is_p1_event(event):
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		if not event.is_echo():
			get_viewport().set_input_as_handled()
			_close()

func _close() -> void:
	if _closed:
		return
	_closed = true
	hide()
	PauseManager.set_reason(_pause_reason, false)
	queue_free()

func _exit_tree() -> void:
	PauseManager.set_reason(_pause_reason, false)
