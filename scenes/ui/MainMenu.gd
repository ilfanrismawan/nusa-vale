extends Control

@onready var btn_new: Button = %BtnNew
@onready var btn_continue: Button = %BtnContinue
@onready var btn_settings: Button = %BtnSettings
@onready var btn_quit: Button = %BtnQuit
@onready var confirm_dialog: ConfirmationDialog = %ConfirmDialog
@onready var settings_menu: CanvasLayer = %SettingsMenu
@onready var title_label: Label = %TitleLabel
@onready var version_label: Label = %VersionLabel

const GAME_SCENE := "res://scenes/world/Farm.tscn"

var _tween: Tween


func _ready() -> void:
	DayCycle.is_running = false
	btn_new.pressed.connect(_on_new_game_pressed)
	btn_continue.pressed.connect(_on_continue_pressed)
	btn_settings.pressed.connect(_on_settings_pressed)
	btn_quit.pressed.connect(_on_quit_pressed)
	confirm_dialog.confirmed.connect(_start_new_game)

	# Aktifkan tombol Lanjutkan hanya jika ada save
	btn_continue.disabled = not SaveManager.has_save()

	# Animasi masuk
	_play_intro_animation()


func _play_intro_animation() -> void:
	# Fade-in title
	title_label.modulate.a = 0.0
	btn_new.modulate.a = 0.0
	btn_continue.modulate.a = 0.0
	btn_settings.modulate.a = 0.0
	btn_quit.modulate.a = 0.0
	version_label.modulate.a = 0.0

	_tween = create_tween()
	_tween.set_ease(Tween.EASE_OUT)
	_tween.set_trans(Tween.TRANS_CUBIC)

	# Title muncul duluan
	_tween.tween_property(title_label, "modulate:a", 1.0, 0.6)
	_tween.tween_interval(0.15)

	# Tombol-tombol muncul secara berurutan
	_tween.tween_property(btn_new, "modulate:a", 1.0, 0.3)
	_tween.tween_property(btn_continue, "modulate:a", 1.0, 0.3)
	_tween.tween_property(btn_settings, "modulate:a", 1.0, 0.3)
	_tween.tween_property(btn_quit, "modulate:a", 1.0, 0.3)
	_tween.tween_property(version_label, "modulate:a", 0.6, 0.3)


func _on_new_game_pressed() -> void:
	if SaveManager.has_save():
		confirm_dialog.popup_centered()
	else:
		_start_new_game()


func _on_continue_pressed() -> void:
	if SaveManager.load_game():
		_transition_to_game()
	else:
		Notify.say("Gagal memuat save.")


func _on_settings_pressed() -> void:
	if settings_menu:
		settings_menu.toggle()


func _on_quit_pressed() -> void:
	get_tree().quit()


func _start_new_game() -> void:
	# Hapus file save lama
	if FileAccess.file_exists(SaveManager.SAVE_PATH):
		DirAccess.remove_absolute(SaveManager.SAVE_PATH)

	# GameState.new_game() menangani semua reset: money, stamina, inventory, flags
	GameState.new_game()
	WorldState.reset()
	DiscoveryManager.reset()
	UnlockManager.reset()

	DayCycle.current_day = 1
	DayCycle.hour = 6
	DayCycle.minute = 0

	FarmManager.farm_data.clear()

	_transition_to_game()



func _transition_to_game() -> void:
	DayCycle.is_running = true
	# Fade-out sebelum pindah scene
	var fade_tween := create_tween()
	fade_tween.set_ease(Tween.EASE_IN)
	fade_tween.set_trans(Tween.TRANS_CUBIC)
	fade_tween.tween_property(self, "modulate:a", 0.0, 0.4)
	fade_tween.tween_callback(func():
		get_tree().change_scene_to_file(GAME_SCENE)
	)
