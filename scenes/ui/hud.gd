extends CanvasLayer

@onready var time_label: Label = %TimeLabel
@onready var clock_hand: Sprite2D = %ClockHand
@onready var clock_bg: TextureRect = $HUDAnchor/Sprite2D/ClockDisplay/ClockBg
@onready var day_label: Label = %DayLabel
@onready var money_label: Control = %MoneyLabel
@onready var btn_settings: Button = %BtnSettings
@onready var stamina_bar: TextureProgressBar = %StaminaBar
var _stamina_capacity_tween: Tween
var _displayed_stamina_max := 0
@onready var food_buff_label: Label = %FoodEffectsLabel
## Bar HP merah (Bars.png), dibuat di kode di kiri bar stamina.
const BARS: Texture2D = preload("res://assets/farm_rpg/ui/Bars.png")
var hp_bar: TextureProgressBar
var _hp_shown := -1
## Bar putih di belakang bar HP yang turun menyusul (terlihat berapa HP yang baru hilang).
var _hp_ghost: TextureProgressBar
var _hp_ghost_tween: Tween
var _hp_pulse: Tween
var _stamina_pulse: Tween
var _stamina_shown := -1
## HP/stamina di bawah bagian ini membuat bar berdenyut.
const LOW_RATIO := 0.25

## Pemain pemilik UI ini (diisi Player). Kosong = P1.
var player: Player
var data: PlayerData:
	get: return player.data if is_instance_valid(player) else GameState.p1()

## Input pemilik UI: co-op hanya bereaksi pada perangkat pemain ini.
func _owner_input() -> PlayerInput:
	return player.input if is_instance_valid(player) else PlayerInput.solo()

func _ready() -> void:
	get_viewport().size_changed.connect(_layout_hud)
	var night := preload("res://scripts/effects/night_horror.gd").new()
	night.name = "NightHorror"
	night.player = player
	add_child(night)
	DayCycle.time_tick.connect(_on_time_tick)
	DayCycle.day_passed.connect(_on_day_passed)
	DayCycle.season_changed.connect(_on_season_changed)
	GameState.money_changed.connect(_on_money_changed)
	data.stamina_changed.connect(_on_stamina_changed)
	data.hp_changed.connect(_on_hp_changed)
	data.stamina_exhausted.connect(_on_stamina_exhausted)
	
	if is_instance_valid(btn_settings):
		btn_settings.pressed.connect(_on_settings_pressed)
	
	_setup_clock()
	_update_day(DayCycle.current_day)
	_update_time(DayCycle.hour, DayCycle.minute)
	_update_money(GameState.money)
	_on_stamina_changed(data.stamina, data.max_stamina)
	_build_hp_bar()
	_build_water_meter()
	_build_weather()
	_layout_hud()

func _layout_hud() -> void:
	if not is_instance_valid(stamina_bar):
		return
	var view_size := get_viewport().get_visible_rect().size
	var bar_size := stamina_bar.size * stamina_bar.scale
	var stamina_left := view_size.x - bar_size.x - 16.0
	_place_bar(stamina_bar, Vector2(stamina_left, view_size.y - bar_size.y - 16.0))
	if hp_bar != null:
		var hp_size := hp_bar.size * hp_bar.scale
		_place_bar(hp_bar, Vector2(stamina_left - hp_size.x - 8.0, view_size.y - hp_size.y - 16.0))
	if water_panel != null:
		water_panel.position = Vector2(16, view_size.y - water_panel.size.y - 88).round()

## Menaruh bar supaya sudut kiri atas yang TERLIHAT ada di top_left.
## Bar diskalakan dari pivot_offset (untuk goyang), jadi posisinya digeser sebesar pivot * (1 - scale).
func _place_bar(bar: Control, top_left: Vector2) -> void:
	bar.position = (top_left - bar.pivot_offset * (Vector2.ONE - bar.scale)).round()

var weather_label: Label
var weather_icon: TextureRect

func _build_weather() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(12, 12)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color("292b3de8")
	frame.border_color = Color("efd7a3")
	frame.set_border_width_all(1)
	frame.set_content_margin_all(5)
	panel.add_theme_stylebox_override("panel", frame)
	add_child(panel)
	var row := HBoxContainer.new()
	panel.add_child(row)
	weather_icon = TextureRect.new()
	weather_icon.custom_minimum_size = Vector2(16, 16)
	row.add_child(weather_icon)
	weather_label = Label.new()
	weather_label.add_theme_font_override("font", MONEY_FONT)
	weather_label.add_theme_font_size_override("font_size", 16)
	row.add_child(weather_label)
	GameState.weather.changed.connect(_update_weather)
	_update_weather()

func _update_weather() -> void:
	if weather_label == null:
		return
	weather_label.text = GameState.weather.display_name()
	weather_icon.texture = preload("res://assets/ui/weather_rain.svg") if GameState.weather.is_raining() else preload("res://assets/ui/weather_sunny.svg")

var water_panel: PanelContainer
var water_bar: ProgressBar
var water_label: Label
var water_icon: TextureRect

func _build_water_meter() -> void:
	water_panel = PanelContainer.new()
	water_panel.name = "WaterCapacity"
	water_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	water_panel.position = Vector2(12, get_viewport().get_visible_rect().size.y - 92)
	water_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color("292b3de8")
	frame.border_color = Color("efd7a3")
	frame.set_border_width_all(2)
	frame.set_content_margin_all(6)
	water_panel.add_theme_stylebox_override("panel", frame)
	add_child(water_panel)
	var row := HBoxContainer.new()
	water_panel.add_child(row)
	water_icon = TextureRect.new()
	water_icon.custom_minimum_size = Vector2(24, 24)
	water_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	water_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(water_icon)
	var column := VBoxContainer.new()
	row.add_child(column)
	water_label = Label.new()
	water_label.add_theme_font_override("font", MONEY_FONT)
	water_label.add_theme_font_size_override("font_size", 16)
	column.add_child(water_label)
	water_bar = ProgressBar.new()
	water_bar.custom_minimum_size = Vector2(140, 9)
	water_bar.show_percentage = false
	var background_style := StyleBoxFlat.new()
	background_style.bg_color = Color("141d30")
	water_bar.add_theme_stylebox_override("background", background_style)
	column.add_child(water_bar)
	_update_water_meter()

func _process(_delta: float) -> void:
	_layout_hud()
	_update_water_meter()
	if food_buff_label != null:
		var lines: PackedStringArray = []
		for active in data.active_food_effects:
			var effect: FoodEffectData = active.effect
			lines.append("%s ×%d · %d dtk" % [effect.display_name, int(active.stacks), ceili(float(active.remaining))])
		food_buff_label.visible = not lines.is_empty()
		food_buff_label.text = "\n".join(lines)

func _update_water_meter() -> void:
	if water_panel == null:
		return
	var item: ItemData = player.tool_controller.current_item if is_instance_valid(player) else null
	var tool: ToolData = item.action_data.tool_data if item != null and item.action_data != null else null
	water_panel.visible = tool != null and tool.tool_type == ToolData.ToolType.WATERING_CAN
	if not water_panel.visible:
		return
	var remaining := clampi(data.watering_water, 0, tool.water_capacity)
	water_icon.texture = item.icon
	water_bar.max_value = tool.water_capacity
	water_bar.value = remaining
	water_label.text = "Air %d / %d%s" % [remaining, tool.water_capacity, " — Isi ulang" if remaining == 0 else ""]
	var fill := water_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill == null or not water_bar.has_theme_stylebox_override("fill"):
		fill = StyleBoxFlat.new()
		water_bar.add_theme_stylebox_override("fill", fill)
	fill.bg_color = Color("f28b66") if remaining <= tool.water_capacity * 0.2 else Color("61c9f1")

func _on_stamina_changed(current: int, maximum: int) -> void:
	if not is_instance_valid(stamina_bar):
		return
	if maximum != _displayed_stamina_max:
		_displayed_stamina_max = maximum
		var available_height := maxf(126.0, get_viewport().get_visible_rect().size.y - 180.0)
		var target_scale := Vector2(3.0, minf(3.0 * float(maximum) / 100.0, available_height / 42.0))
		if _stamina_capacity_tween != null and _stamina_capacity_tween.is_running():
			_stamina_capacity_tween.kill()
		var tween := create_tween()
		_stamina_capacity_tween = tween
		tween.set_parallel(true)
		tween.tween_property(stamina_bar, "scale", target_scale, 0.6)
	stamina_bar.tooltip_text = "Stamina %d / %d" % [current, maximum]
	stamina_bar.max_value = maximum
	stamina_bar.value = current
	if _stamina_shown >= 0 and current < _stamina_shown:
		_wobble(stamina_bar, 2.0)
	_stamina_shown = current
	_stamina_pulse = _set_pulse(stamina_bar, _stamina_pulse, maximum > 0 and current <= maximum * LOW_RATIO, Color(1.6, 1.2, 0.5))

## Aksi ditolak karena lelah: bar stamina bergetar keras dan berkedip merah.
func _on_stamina_exhausted() -> void:
	if not is_instance_valid(stamina_bar):
		return
	_wobble(stamina_bar, 7.0)
	var tw := create_tween()
	for i in 3:
		tw.tween_property(stamina_bar, "self_modulate", Color(2.0, 0.5, 0.5), 0.06)
		tw.tween_property(stamina_bar, "self_modulate", Color.WHITE, 0.08)
	_spray(stamina_bar, Color(0.55, 0.8, 1.0), 6)
		
func _build_hp_bar() -> void:
	if not is_instance_valid(stamina_bar):
		return
	hp_bar = TextureProgressBar.new()
	hp_bar.name = "HpBar"
	hp_bar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	hp_bar.fill_mode = TextureProgressBar.FILL_BOTTOM_TO_TOP
	var under := AtlasTexture.new()
	under.atlas = BARS
	under.region = Rect2(148, 3, 8, 42)
	var progress := AtlasTexture.new()
	progress.atlas = BARS
	progress.region = Rect2(116, 50, 10, 42)
	hp_bar.texture_progress = progress
	hp_bar.size = Vector2(10, 42)
	hp_bar.scale = Vector2(3, 3)
	hp_bar.pivot_offset = hp_bar.size * Vector2(0.5, 1.0)
	# Latar bar ada di bar bayangan (digambar di belakang) supaya sisa putihnya terlihat.
	_hp_ghost = TextureProgressBar.new()
	_hp_ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_hp_ghost.fill_mode = TextureProgressBar.FILL_BOTTOM_TO_TOP
	_hp_ghost.texture_under = under
	_hp_ghost.texture_progress = progress
	_hp_ghost.tint_progress = Color(4.0, 4.0, 4.0)
	_hp_ghost.size = hp_bar.size
	_hp_ghost.show_behind_parent = true
	_hp_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_bar.add_child(_hp_ghost)
	stamina_bar.get_parent().add_child(hp_bar)
	stamina_bar.pivot_offset = stamina_bar.size * Vector2(0.5, 1.0)
	_on_hp_changed(data.hp, data.max_hp)

func _on_hp_changed(current: int, maximum: int) -> void:
	if hp_bar == null:
		return
	hp_bar.tooltip_text = "HP %d / %d" % [current, maximum]
	hp_bar.max_value = maximum
	hp_bar.value = current
	_hp_ghost.max_value = maximum
	if _hp_ghost_tween != null and _hp_ghost_tween.is_valid():
		_hp_ghost_tween.kill()
	# HP turun: bar berkedip merah, bergetar, meneteskan darah, dan bar putih menyusul turun.
	if _hp_shown >= 0 and current < _hp_shown:
		hp_bar.self_modulate = Color(2.0, 0.6, 0.6)
		create_tween().tween_property(hp_bar, "self_modulate", Color.WHITE, 0.3)
		_wobble(hp_bar, 6.0)
		_spray(hp_bar, Color(0.75, 0.05, 0.08), clampi(_hp_shown - current, 4, 14))
		_hp_ghost_tween = create_tween()
		_hp_ghost_tween.tween_interval(0.35)
		_hp_ghost_tween.tween_property(_hp_ghost, "value", float(current), 0.4).set_ease(Tween.EASE_IN)
	else:
		_hp_ghost.value = current
	_hp_shown = current
	_hp_pulse = _set_pulse(hp_bar, _hp_pulse, current > 0 and current <= maximum * LOW_RATIO, Color(1.8, 0.5, 0.5))

## Goyang singkat lewat rotasi (posisi bar diatur _layout_hud, jadi tidak disentuh).
func _wobble(bar: Control, degrees: float) -> void:
	var tw := create_tween()
	for angle in [degrees, -degrees * 0.7, degrees * 0.4, 0.0]:
		tw.tween_property(bar, "rotation_degrees", angle, 0.05)

## Denyut warna terus-menerus selama kondisi rendah; berhenti dan pulih saat tidak lagi.
func _set_pulse(bar: Control, pulse: Tween, active: bool, color: Color) -> Tween:
	if active:
		if pulse != null and pulse.is_valid():
			return pulse
		pulse = create_tween().set_loops()
		pulse.tween_property(bar, "modulate", color, 0.35)
		pulse.tween_property(bar, "modulate", Color.WHITE, 0.35)
		return pulse
	if pulse != null and pulse.is_valid():
		pulse.kill()
	bar.modulate = Color.WHITE
	return null

## Tetesan dari ujung isi bar (darah untuk HP, keringat untuk stamina).
func _spray(bar: TextureProgressBar, color: Color, amount: int) -> void:
	var ratio := bar.value / bar.max_value if bar.max_value > 0 else 0.0
	var size := bar.size * bar.scale
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.amount = amount
	p.lifetime = 0.6
	p.explosiveness = 0.9
	p.direction = Vector2.UP
	p.spread = 60.0
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 110.0
	p.gravity = Vector2(0, 420)
	p.scale_amount_min = 3.0
	p.scale_amount_max = 6.0
	p.color = color
	p.z_index = 5
	add_child(p)
	p.position = bar.position + Vector2(size.x * 0.5, size.y * (1.0 - ratio))
	p.emitting = true
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)

func _on_settings_pressed() -> void:
	var settings = get_parent().get_node_or_null("SettingsMenu")
	if settings:
		settings.toggle()

func _on_time_tick(hour: int, minute: int) -> void:
	_update_time(hour, minute)

func _on_day_passed(day: int) -> void:
	_update_day(day)

func _on_money_changed(amount: int) -> void:
	_update_money(amount)
	
func _on_season_changed(_season: int) -> void:
	_update_clock_face()

## Nama musim pendek supaya muat di kotak hari (lebar 62px).
const SEASON_SHORT := ["Semi", "Panas", "Gugur", "Dingin"]

func _update_day(_day: int) -> void:
	day_label.text = "%s %d" % [SEASON_SHORT[DayCycle.get_season()], DayCycle.get_day_of_season()]
	_update_clock_face()

# ── Jam bergambar (Clock/Others/clock.png) ──────────────────────────
## Sheet 6x3 kotak 32x32. Baris = musim (hijau, gugur, salju),
## kolom = waktu (pagi, siang, sore, malam, tengah malam, subuh).
const CLOCK_SHEET := preload("res://assets/farm_rpg/Clock/Others/clock.png")
const CLOCK_FRAME := 32
## spring & summer sama-sama memakai baris hijau (sheet hanya punya 3 baris).
const SEASON_ROW := [0, 0, 1, 2]

var _clock_atlas: AtlasTexture

func _setup_clock() -> void:
	_clock_atlas = AtlasTexture.new()
	_clock_atlas.atlas = CLOCK_SHEET
	clock_bg.texture = _clock_atlas
	clock_hand.hide() # gambar baru tidak punya piringan jarum
	_update_clock_face()

func _clock_column(h: int) -> int:
	# 06-10 pagi, 10-14 siang, 14-18 sore, 18-22 malam, 22-02 tengah malam, 02-06 subuh
	return int(((h - 6 + 24) % 24) / 4.0)

func _update_clock_face() -> void:
	if _clock_atlas == null:
		return
	var row: int = SEASON_ROW[DayCycle.get_season()]
	var col: int = _clock_column(DayCycle.hour)
	_clock_atlas.region = Rect2(col * CLOCK_FRAME, row * CLOCK_FRAME, CLOCK_FRAME, CLOCK_FRAME)

func _update_time(h: int, m: int) -> void:
	var period := "AM" if h < 12 else "PM"
	var display_hour := h % 12
	if display_hour == 0:
		display_hour = 12
	
	time_label.text = "%02d:%02d %s" % [display_hour, m, period]
	time_label.modulate = Color(1.0, 0.4, 0.35) if h < 6 else Color.WHITE
	
	_update_clock_face()

## Bar koin punya 7 kotak (lebar 5px, jarak 6px pada sprite skala 2x).
## Satu digit per kotak, rata kanan, seperti di Stardew Valley.
const MONEY_CELLS := 7
const MONEY_CELL_PITCH := 12
const MONEY_CELL_SIZE := Vector2(10, 14)
const MONEY_FONT := preload("res://resources/ui/readable_font.tres")
const MONEY_COLOR := Color(0.13333334, 0.06666667, 0.13333334, 1)

var _money_digits: Array[Label] = []

func _build_money_digits() -> void:
	# Share the day's complete style, including its shadow settings.
	var settings: LabelSettings = day_label.label_settings
	for i in MONEY_CELLS:
		var digit := Label.new()
		digit.label_settings = settings
		digit.mouse_filter = Control.MOUSE_FILTER_IGNORE
		digit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		digit.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		# Use the same 16px line box and centering as day/time labels.
		digit.position = Vector2(i * MONEY_CELL_PITCH, -1)
		digit.size = Vector2(MONEY_CELL_SIZE.x, 16)
		money_label.add_child(digit)
		_money_digits.append(digit)

func _update_money(amount: int) -> void:
	if _money_digits.is_empty():
		_build_money_digits()
	var digits := str(clampi(amount, 0, int(pow(10, MONEY_CELLS)) - 1))
	var pad := MONEY_CELLS - digits.length()
	for i in MONEY_CELLS:
		_money_digits[i].text = digits[i - pad] if i >= pad else ""

## 1234567 -> "1.234.567" (dipakai juga oleh UI inventory)
static func format_money(value: int) -> String:
	var digits := str(absi(value))
	var out := ""
	while digits.length() > 3:
		out = "." + digits.substr(digits.length() - 3) + out
		digits = digits.substr(0, digits.length() - 3)
	return ("-" if value < 0 else "") + digits + out
