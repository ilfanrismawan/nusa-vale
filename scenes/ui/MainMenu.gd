extends Control

@export var design_size := Vector2(1280, 720)

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
var btn_coop: Button


func _ready() -> void:
	DayCycle.is_running = false
	Coop.stop()
	_add_coop_button()
	get_viewport().size_changed.connect(_resize)
	_resize()
	btn_new.pressed.connect(_on_new_game_pressed)
	btn_continue.pressed.connect(_on_continue_pressed)
	btn_settings.pressed.connect(_on_settings_pressed)
	btn_quit.pressed.connect(_on_quit_pressed)
	# Konfirmasi timpa save sekarang ada di SaveSlotMenu; ConfirmDialog tidak dipakai lagi.

	# Tombol Lanjutkan membuka daftar slot; aktif jika ada minimal satu slot terisi.
	btn_continue.text = "Muat Game"
	btn_continue.disabled = not SaveManager.has_any_save()
	if settings_menu and settings_menu.has_method("set_save_buttons_visible"):
		settings_menu.set_save_buttons_visible(false)

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
	btn_coop = %BtnCoop
	btn_coop.pressed.connect(_on_coop_pressed)

func _resize() -> void:
	var view := get_viewport().get_visible_rect().size
	var fit := minf(view.x / design_size.x, view.y / design_size.y)
	$Design.scale = Vector2.ONE * fit
	$Design.position = (view - design_size * fit) * 0.5

## Co-op: pilih slot dulu (kosong = game baru, terisi = lanjutkan), lalu lobby.
func _on_coop_pressed() -> void:
	_open_slot_menu(SaveSlotMenu.Mode.PLAY, func(_slot: int): _open_coop_lobby())


func _open_coop_lobby() -> void:
	var lobby := CoopLobby.new()
	lobby.start_requested.connect(_start_coop)
	add_child(lobby)


## Co-op memakai save di slot terpilih (P1 = pemilik save). Slot kosong: game baru, penampilan
## bawaan (bisa diganti di lemari rumah) dan langsung disimpan supaya slot terisi.
func _start_coop(devices: Array[int]) -> void:
	if SaveManager.has_save():
		if not SaveManager.load_game():
			Notify.say("Gagal memuat save.")
			return
	else:
		_reset_world()
		_open_character_creator(func(): _launch_coop(devices))
		return
	_launch_coop(devices)

func _launch_coop(devices: Array[int]) -> void:
	var fade_tween := create_tween()
	fade_tween.tween_property(self, "modulate:a", 0.0, 0.4)
	fade_tween.tween_callback(func(): Coop.start(devices))


func _on_new_game_pressed() -> void:
	_open_slot_menu(SaveSlotMenu.Mode.NEW_GAME, func(_slot: int): _start_new_game())


func _on_continue_pressed() -> void:
	_open_slot_menu(SaveSlotMenu.Mode.LOAD, func(_slot: int): _continue_game())


func _open_slot_menu(slot_mode: SaveSlotMenu.Mode, on_chosen: Callable) -> void:
	var menu := load("res://scenes/ui/save_slot_menu.tscn").instantiate() as SaveSlotMenu
	menu.mode = slot_mode
	menu.slot_chosen.connect(on_chosen)
	# Slot bisa dihapus dari menu ini: perbarui tombol Muat Game setelah ditutup.
	menu.closed.connect(func(): btn_continue.disabled = not SaveManager.has_any_save())
	add_child(menu)


## Slot sudah dipilih lewat SaveSlotMenu (SaveManager.current_slot).
func _continue_game() -> void:
	if not SaveManager.load_game():
		Notify.say("Gagal memuat save.")
		return

	GameState.next_spawn_position = Vector2(304.0, 147.0)
	GameState.has_spawn_point = true
	DayCycle.is_running = true

	var fade_tween := create_tween()
	fade_tween.tween_property(self, "modulate:a", 0.0, 0.4)
	fade_tween.tween_callback(func():
		get_tree().change_scene_to_file(
			"res://scenes/world/interior/interior_house.tscn"
		)
	)


func _on_settings_pressed() -> void:
	if settings_menu:
		settings_menu.toggle()


func _on_quit_pressed() -> void:
	get_tree().quit()


func _start_new_game() -> void:
	if not SaveManager.delete_save():
		Notify.say("Gagal menghapus save lama.")
		return
	
	GameState.next_spawn_position = Vector2(1114.0, 290.0)
	GameState.has_spawn_point = true
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
	GameState.p1().player_name = ""

	FarmManager.farm_data.clear()
	ForageManager.reset()


func _open_character_creator(on_completed: Callable = Callable()) -> void:
	# Pemain memilih penampilan sebelum masuk ke Farm.
	var creator := load("res://scenes/ui/character_creator_ui.tscn").instantiate() as CharacterCreatorUI
	creator.allow_cancel = false
	creator.pause_game = false
	creator.ask_name = true
	creator.finished.connect(func(_appearance: CharacterAppearance):
		# Simpan langsung supaya slot yang dipilih terisi (nama + hari 1) sebelum masuk Farm.
		if SaveManager.save_game():
			if on_completed.is_valid():
				on_completed.call()
			else:
				_transition_to_game()
		else:
			Notify.say("Gagal menyimpan profil. Silakan coba lagi.")
			_open_character_creator(on_completed))
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
