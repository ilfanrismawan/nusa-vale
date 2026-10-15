extends Node

signal time_tick(hour: int, minute: int)
signal day_passed(day_number: int)
signal player_passed_out
signal season_changed(season: int)

enum Season { SPRING, SUMMER, FALL, WINTER }

@export var real_seconds_per_10_game_minutes: float = 6.0

var current_day: int = 1
var hour: int = 6
var minute: int = 0

const DAYS_PER_SEASON := 28
const SEASONS: Array[String] = ["spring", "summer", "fall", "winter"]


func apply_scene_lighting() -> void:
	var scene := get_tree().current_scene
	
	if scene == null:
		return
	
	for node in scene.find_children("*", "CanvasModulate", true, false):
		var light := node as CanvasModulate
		
		if light != null:
			light.color = _lighting_color(hour)
	
## 0 = Semi, 1 = Panas, 2 = Gugur, 3 = Dingin. Dihitung dari current_day,
## jadi tidak perlu disimpan di save.
@warning_ignore("integer_division")
func get_season() -> int:
	return ((current_day - 1) / DAYS_PER_SEASON) % SEASONS.size()

## "spring" / "summer" / "fall" / "winter" (cocok dengan CropData.season).
func get_current_season() -> String:
	return SEASONS[get_season()]

## Hari ke-berapa di musim ini, 1..DAYS_PER_SEASON.
func get_day_of_season() -> int:
	return ((current_day - 1) % DAYS_PER_SEASON) + 1

@warning_ignore("integer_division")
func get_year() -> int:
	return ((current_day - 1) / (DAYS_PER_SEASON * SEASONS.size())) + 1

func get_season_display_name() -> String:
	match get_season():
		1: return "Musim Panas"
		2: return "Musim Gugur"
		3: return "Musim Dingin"
	return "Musim Semi"

var is_running: bool = false
const TICK_INTERVAL := 0.7
var _timer: float = TICK_INTERVAL
var _is_passing_out: bool = false
var is_sleep_transition: bool = false

const LAST_SAFE_HOUR := 5
const PASS_OUT_MINUTE := 10

func night_intensity() -> float:
	if hour >= 18:
		return lerpf(0.25, 0.65, float(hour - 18) / 5.0)
	if hour < 6:
		return lerpf(0.7, 1.0, float(hour * 60 + minute) / 360.0)
	return 0.0

func is_past_night_limit() -> bool:
	return hour == LAST_SAFE_HOUR and minute >= PASS_OUT_MINUTE

func _process(delta: float) -> void:
	apply_scene_lighting()
	
	if not is_running or get_tree().paused or _is_passing_out or is_sleep_transition:
		return
	_timer += delta
	
	if _timer >= real_seconds_per_10_game_minutes:
		_timer -= real_seconds_per_10_game_minutes
		advance_minute(10)
		
func advance_minute(amount: int) -> void:
	if _is_passing_out or is_sleep_transition:
		return
	# Walk every minute so large debug skips cannot jump over the deadline.
	for step in maxi(0, amount):
		minute += 1
		if minute >= 60:
			minute = 0
			hour = (hour + 1) % 24
		if is_past_night_limit():
			time_tick.emit(hour, minute)
			trigger_pass_out()
			return
		if minute == 0:
			if hour == 18:
				Notify.say("Malam tiba. Di luar mulai terasa ganjil. Tidurlah sebelum lewat 05.00.")
			elif hour == 0:
				Notify.say("Tengah malam. Kabut menebal dan sesuatu bergerak di kegelapan.")
			elif hour == 4:
				Notify.say("04.00 — satu jam lagi untuk pulang dan tidur.")
			elif hour == 5:
				Notify.say("05.00 — segera tidur! Pada 05.10 kamu pingsan dan energi besok hanya 50%.")
	time_tick.emit(hour, minute)
	apply_scene_lighting()
		
func trigger_pass_out() -> void:
	if _is_passing_out or is_sleep_transition:
		return
	_is_passing_out = true
	for body in get_tree().get_nodes_in_group("night_players"):
		body.set_input_locked(&"pass_out", true)
	player_passed_out.emit()		
	
	var layer := CanvasLayer.new()
	layer.layer = 100
	var fade := ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(fade)
	add_child(layer)
	
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 1.2)
	tw.tween_callback(func():
		advance_day()
		hour = 8
		minute = 0
		time_tick.emit(hour, minute)
		
		if Coop.has_root():
			# Co-op: semua pemain bangun di rumah, scene utama tetap CoopRoot.
			Coop.pass_out_all(Vector2(317, 151), "res://scenes/world/interior/interior_house.tscn")
		else:
			GameState.stamina = int(GameState.current.max_stamina * 0.5)
			GameState.stamina_changed.emit(GameState.stamina, GameState.current.max_stamina)
			
			GameState.next_spawn_position = Vector2(317, 151)
			GameState.has_spawn_point = true
			get_tree().change_scene_to_file("res://scenes/world/interior/interior_house.tscn")
		SaveManager.save_game()
		Notify.say("Melewati 05.00: kamu ditemukan tak sadarkan diri. Bangun 08.00 dengan energi 50%. Pemain yang sudah tidur tetap pulih.")
		)
	tw.tween_interval(1.0)
	tw.tween_property(fade, "color:a", 0.0, 1.0)
	tw.tween_callback(func ():
		layer.queue_free()
		for body in get_tree().get_nodes_in_group("night_players"):
			body.set_input_locked(&"pass_out", false)
		_is_passing_out = false)
	
func advance_day() -> void:
	# Co-op: tanaman tumbuh di layer Farm walau pemain sedang di area lain.
	Coop.bind_farm()
	var old_season := get_season()
	hour = 6
	minute = 0
	_timer = 0.0
	current_day += 1
	GameState.shipping.settle(current_day)
	get_tree().create_timer(2.0).timeout.connect(GameState.shipping.show_report)
	day_passed.emit(current_day)
	if get_season() != old_season:
		season_changed.emit(get_season())
		Notify.say("%s dimulai!" % get_season_display_name())
	GameState.weather.advance_day(current_day)
	time_tick.emit(hour, minute)
	
func _lighting_color(current_hour: int) -> Color:
	if current_hour >= 6 and current_hour < 16:
		return Color(1.0, 1.0, 1.0)
	
	if current_hour >= 16 and current_hour < 18:
		return Color(1.0, 0.75, 0.5)
	
	return Color(0.3, 0.35, 0.6)
