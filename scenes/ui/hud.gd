extends CanvasLayer

@onready var time_label: Label = %TimeLabel
@onready var clock_hand: Sprite2D = %ClockHand
@onready var clock_bg: TextureRect = $HUDAnchor/Sprite2D/ClockDisplay/ClockBg
@onready var day_label: Label = %DayLabel
@onready var money_label: Control = %MoneyLabel
@onready var btn_settings: Button = %BtnSettings
@onready var stamina_bar: TextureProgressBar = %StaminaBar

## Pemain pemilik UI ini (diisi Player). Kosong = P1.
var player: Player
var data: PlayerData:
	get: return player.data if is_instance_valid(player) else GameState.p1()

## Input pemilik UI: co-op hanya bereaksi pada perangkat pemain ini.
func _owner_input() -> PlayerInput:
	return player.input if is_instance_valid(player) else PlayerInput.solo()

func _ready() -> void:
	DayCycle.time_tick.connect(_on_time_tick)
	DayCycle.day_passed.connect(_on_day_passed)
	DayCycle.season_changed.connect(_on_season_changed)
	GameState.money_changed.connect(_on_money_changed)
	data.stamina_changed.connect(_on_stamina_changed)
	
	if is_instance_valid(btn_settings):
		btn_settings.pressed.connect(_on_settings_pressed)
	
	_setup_clock()
	_update_day(DayCycle.current_day)
	_update_time(DayCycle.hour, DayCycle.minute)
	_update_money(GameState.money)
	_on_stamina_changed(data.stamina, GameState.MAX_STAMINA)

func _on_stamina_changed(current: int, maximum: int) -> void:
	if not is_instance_valid(stamina_bar):
		return
	stamina_bar.max_value = maximum
	stamina_bar.value = current
		
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
	
	_update_clock_face()

## Bar koin punya 7 kotak (lebar 5px, jarak 6px pada sprite skala 2x).
## Satu digit per kotak, rata kanan, seperti di Stardew Valley.
const MONEY_CELLS := 7
const MONEY_CELL_PITCH := 12
const MONEY_CELL_SIZE := Vector2(10, 14)
const MONEY_FONT := preload("res://assets/fonts/m5x7.ttf")
const MONEY_COLOR := Color(0.13333334, 0.06666667, 0.13333334, 1)

var _money_digits: Array[Label] = []

func _build_money_digits() -> void:
	var settings := LabelSettings.new()
	settings.font = MONEY_FONT
	settings.font_size = 16 # digit 5x7 di kotak 10x14 -> ada jarak di sekelilingnya
	settings.font_color = MONEY_COLOR
	for i in MONEY_CELLS:
		var digit := Label.new()
		digit.label_settings = settings
		digit.mouse_filter = Control.MOUSE_FILTER_IGNORE
		digit.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		digit.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		# Glyph 5x7 diletakkan di tengah kotak 10x14 (glyph mulai 4px di bawah atas baris)
		digit.position = Vector2(i * MONEY_CELL_PITCH + 3, -4 + 4)
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
	
