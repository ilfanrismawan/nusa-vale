extends CanvasLayer

@export var design_size := Vector2(1280, 720)
var rows: Array[Dictionary] = []
var _pause_reason: StringName
var _closed := false
var _recap_page := 0
var _choice_page := 0
var _pending: Array[Dictionary] = []
@onready var _continue: Button = %Continue

func _ready() -> void:
	layer = 91
	process_mode = Node.PROCESS_MODE_ALWAYS
	_pause_reason = StringName("level_up_%d" % get_instance_id())
	PauseManager.set_reason(_pause_reason, true)
	_continue.pressed.connect(_close)
	%PreviousRecap.pressed.connect(_change_recap.bind(-1))
	%NextRecap.pressed.connect(_change_recap.bind(1))
	%PreviousChoice.pressed.connect(_change_choice.bind(-1))
	%NextChoice.pressed.connect(_change_choice.bind(1))
	%BranchA.pressed.connect(_select_branch.bind("a"))
	%BranchB.pressed.connect(_select_branch.bind("b"))
	get_viewport().size_changed.connect(_resize)
	_resize()
	_populate()
	_continue.grab_focus()

func _resize() -> void:
	var view := get_viewport().get_visible_rect().size
	var fit := minf(view.x / design_size.x, view.y / design_size.y)
	$Design.scale = Vector2.ONE * fit
	$Design.position = (view - design_size * fit) * 0.5

func _populate() -> void:
	var valid: Array[Dictionary] = []
	for row in rows:
		if SkillSystem.role(row.role_id) != null:
			valid.append(row)
	_recap_page = clampi(_recap_page, 0, maxi(0, valid.size() - 1))
	%Summary.text = "%d keahlian meningkat · Awal hari yang baru" % valid.size()
	%RecapPage.text = "%d / %d" % [_recap_page + 1 if not valid.is_empty() else 0, valid.size()]
	%PreviousRecap.disabled = valid.size() <= 1
	%NextRecap.disabled = valid.size() <= 1
	%RoleIcon.texture = null
	%RoleTitle.text = "Terus bertumbuh"
	%Owner.text = "Setiap aktivitas membawa pengalaman baru."
	%Levels.text = "Belum ada kenaikan level"
	%Perks.text = "Pilihan cabang yang belum ditentukan tetap dapat diselesaikan di sini atau di tab Keahlian."
	if not valid.is_empty():
		var row := valid[_recap_page]
		var role := SkillSystem.role(row.role_id)
		%RoleIcon.texture = role.icon
		%RoleTitle.text = role.title
		%Owner.text = _who(row.data)
		%Levels.text = "Lv %d  →  Lv %d" % [int(row.from), int(row.to)]
		var perks := PackedStringArray()
		for at_level in range(int(row.from) + 1, int(row.to) + 1):
			for perk in role.perks_at(at_level, ""):
				perks.append("• %s\n%s%s" % [perk.title, perk.description, " (Segera hadir)" if perk.coming_soon else ""])
		%Perks.text = "\n\n".join(perks) if not perks.is_empty() else "Terus tingkatkan keahlian ini untuk memperoleh manfaat berikutnya."
	_pending.clear()
	for data in GameState.players:
		if data == null or data.skills == null:
			continue
		for choice in data.skills.pending_choices():
			var role := SkillSystem.role(choice.role_id)
			if role != null:
				_pending.append({"data": data, "role": role, "level": int(choice.level)})
	_choice_page = clampi(_choice_page, 0, maxi(0, _pending.size() - 1))
	%ChoicePage.text = "%d / %d" % [_choice_page + 1 if not _pending.is_empty() else 0, _pending.size()]
	%PreviousChoice.disabled = _pending.size() <= 1
	%NextChoice.disabled = _pending.size() <= 1
	%BranchA.visible = not _pending.is_empty()
	%BranchB.visible = not _pending.is_empty()
	%ChoiceEmpty.visible = _pending.is_empty()
	%ChoiceTitle.text = "Semua pilihan selesai" if _pending.is_empty() else "Pilih jalur keahlian"
	%ChoiceOwner.text = "Manfaat keahlianmu siap digunakan." if _pending.is_empty() else ""
	if not _pending.is_empty():
		var entry := _pending[_choice_page]
		var role: RoleData = entry.role
		%ChoiceOwner.text = "%s · %s · Lv %d" % [_who(entry.data), role.title, entry.level]
		for branch in ["a", "b"]:
			var button: Button = %BranchA if branch == "a" else %BranchB
			var lines := PackedStringArray()
			for perk in role.perks_at(entry.level, branch):
				lines.append(perk.description + (" (Segera hadir)" if perk.coming_soon else ""))
			button.text = "%s · %s\n\n%s" % [branch.to_upper(), role.branch_title(entry.level, branch), "\n".join(lines)]
			button.disabled = not role.branch_available(entry.level, branch)
	_continue.text = "Nanti saja" if not _pending.is_empty() else "Mulai Hari Baru"
	%Hint.text = "Pilihan dapat dilanjutkan di tab Keahlian. Esc: lanjut tanpa memilih." if not _pending.is_empty() else "Progres keahlian sudah aktif. Saatnya melanjutkan petualangan!"

func _change_recap(direction: int) -> void:
	var count := 0
	for row in rows:
		if SkillSystem.role(row.role_id) != null:
			count += 1
	if count > 0:
		_recap_page = posmod(_recap_page + direction, count)
	_populate()
	%PerkScroll.scroll_vertical = 0

func _change_choice(direction: int) -> void:
	if not _pending.is_empty():
		_choice_page = posmod(_choice_page + direction, _pending.size())
	_populate()

func _select_branch(branch: String) -> void:
	if not _closed and not _pending.is_empty():
		var entry := _pending[_choice_page]
		_choose(entry.data, entry.role, entry.level, branch)

func _choose(data: PlayerData, role: RoleData, at_level: int, branch: String) -> void:
	if data.skills.choose(role.role_id, at_level, branch):
		Notify.say("%s Lv %d: %s dipilih." % [role.title, at_level, role.branch_title(at_level, branch)])
	_populate()
	_continue.grab_focus()

func _who(data: PlayerData) -> String:
	return data.player_name if not data.player_name.strip_edges().is_empty() else "P%d" % (data.index + 1)

func _input(event: InputEvent) -> void:
	if not _closed and Coop.is_p1_event(event) and event.is_action_pressed("ui_cancel") and not event.is_echo():
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
