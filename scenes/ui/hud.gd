extends CanvasLayer

@onready var time_label: Label = %TimeLabel
@onready var clock_hand: Sprite2D = %ClockHand
@onready var day_label: Label = %DayLabel
@onready var money_label: Label = %MoneyLabel
@onready var btn_settings: Button = %BtnSettings
@onready var stamina_bar: TextureProgressBar = %StaminaBar

func _ready() -> void:
	DayCycle.time_tick.connect(_on_time_tick)
	DayCycle.day_passed.connect(_on_day_passed)
	GameState.money_changed.connect(_on_money_changed)
	GameState.stamina_changed.connect(_on_stamina_changed)
	
	if is_instance_valid(btn_settings):
		btn_settings.pressed.connect(_on_settings_pressed)
	
	_update_day(DayCycle.current_day)
	_update_time(DayCycle.hour, DayCycle.minute)
	_update_money(GameState.money)
	_on_stamina_changed(
	GameState.stamina,
	GameState.MAX_STAMINA
)

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
	
func _update_day(day: int) -> void:
	day_label.text = "Hari %d" % day

func _update_time(h: int, m: int) -> void:
	var period := "AM" if h < 12 else "PM"
	var display_hour := h % 12
	if display_hour == 0:
		display_hour = 12
	
	time_label.text = "%02d:%02d %s" % [display_hour, m, period]
	
	var frame_idx = clampi(int((h - 6) / 2.0), 0,7)
	clock_hand.frame = frame_idx

func _update_money(amount: int) -> void:
	money_label.text = "%d G" % amount
	
