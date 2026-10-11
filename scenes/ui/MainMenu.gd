extends Control

@onready var btn_new: Button = %BtnNew
@onready var btn_continue: Button = %BtnContinue
@onready var btn_settings: Button = %BtnSettings
@onready var btn_quit: Button = %BtnQuit
@onready var confirm_dialog: ConfirmationDialog = %ConfirmDialog
@onready var settings_menu: CanvasLayer = %SettingsMenu
@onready var title_label: Label = %TitleLabel
@onready var version_label: Label = %VersionLabel

const GAME_SCENE := "res://scenes/world/farm.tscn"
const CoopLobby := preload("res://scripts/ui/coop_lobby.gd")

var _tween: Tween
## Tombol "Co-op Lokal" (dibuat dari BtnNew lewat kode supaya main_menu.tscn tidak diubah).
var btn_coop: Button


func _ready() -> void:
	DayCycle.is_running = false
	Coop.stop()
	_add_coop_button()
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
	btn_coop.modulate.a = 0.0
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
	_tween.tween_property(btn_coop, "modulate:a", 1.0, 0.3)
	_tween.tween_property(btn_settings, "modulate:a", 1.0, 0.3)
	_tween.tween_property(btn_quit, "modulate:a", 1.0, 0.3)
	_tween.tween_property(version_label, "modulate:a", 0.6, 0.3)


func _add_coop_button() -> void:
	btn_coop = btn_new.duplicate() as Button
	btn_coop.name = "BtnCoop"
	btn_coop.unique_name_in_owner = false
	btn_coop.text = "Co-op Lokal"
	btn_new.get_parent().add_child(btn_coop)
	btn_new.get_parent().move_child(btn_coop, btn_continue.get_index() + 1)
	btn_coop.pressed.connect(_on_coop_pressed)


func _on_coop_pressed() -> void:
	var lobby := CoopLobby.new()
	lobby.start_requested.connect(_start_coop)
	add_child(lobby)


## Co-op memakai save yang ada (P1 = pemilik save). Tanpa save: game baru, penampilan bawaan
## (bisa diganti di lemari rumah).
func _start_coop(devices: Array[int]) -> void:
	if SaveManager.has_save():
		if not SaveManager.load_game():
			Notify.say("Gagal memuat save.")
			return
	else:
		_reset_world()
	var fade_tween := create_tween()
	fade_tween.tween_property(self, "modulate:a", 0.0, 0.4)
	fade_tween.tween_callback(func(): Coop.start(devices))


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
	if not SaveManager.delete_save():
		Notify.say("Gagal menghapus save lama.")
		return

	_reset_world()
	_open_character_creator()


func _reset_world() -> void:
	# GameState.new_game() menangani semua reset: money, stamina, inventory, flags
	GameState.new_game()
	WorldState.reset()
	DiscoveryManager.reset()
	UnlockManager.reset()

	DayCycle.current_day = 1
	DayCycle.hour = 6
	DayCycle.minute = 0

	FarmManager.farm_data.clear()
	ForageManager.reset()


func _open_character_creator() -> void:
	# Pemain memilih penampilan sebelum masuk ke Farm.
	var creator := CharacterCreatorUI.new()
	creator.allow_cancel = false
	creator.pause_game = false
	creator.finished.connect(func(_appearance: CharacterAppearance): _transition_to_game())
	add_child(creator)



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
