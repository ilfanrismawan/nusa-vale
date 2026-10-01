extends CanvasLayer

@onready var time_label: Label = $Sprite2D/TimeLabel
@onready var clock_hand: Sprite2D = $Sprite2D/ClockDisplay/ClockBg/ClockHand
@onready var day_label: Label = $Sprite2D/DayLabel
@onready var money_label: Label = $Sprite2D/MoneyLabel


func _ready() -> void:
	DayCycle.time_tick.connect(_on_time_tick)
	DayCycle.day_passed.connect(_on_day_passed)
	GameState.money_changed.connect(_on_money_changed)
	
	_update_day(DayCycle.current_day)
	_update_time(DayCycle.hour, DayCycle.minute)
	_update_money(GameState.money)

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
	
