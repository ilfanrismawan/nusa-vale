extends Node

## Autoload "Coop": sesi co-op lokal split screen (2-4 pemain).
## Solo (active = false) semua fungsi di sini jatuh ke perilaku lama, jadi kode lain
## boleh memanggilnya tanpa cek. Layar, area, dan perpindahan pemain diurus CoopRoot.

signal session_started
signal session_ended

const ROOT_SCENE := "res://scenes/main/coop_root.tscn"
const MAX_PLAYERS := 4

var active := false
## Perangkat per pemain, urut bergabung. Index 0 = P1 (keyboard + mouse).
var devices: Array[int] = []
var inputs: Array[PlayerInput] = []
## CoopRoot yang sedang berjalan (null saat solo).
var root: Node


## Mulai sesi dari lobby. Save sudah dimuat / game baru sudah disiapkan oleh pemanggil.
func start(p_devices: Array[int]) -> void:
	devices = p_devices.duplicate()
	inputs.clear()
	for i in devices.size():
		inputs.append(PlayerInput.create(i, devices[i]))
		GameState.ensure_player(i)
	GameState.use_player(GameState.p1())
	active = true
	session_started.emit()
	DayCycle.is_running = true
	get_tree().change_scene_to_file(ROOT_SCENE)

## Kembali ke mode solo (dipanggil main menu).
func stop() -> void:
	if not active and root == null:
		return
	active = false
	root = null
	devices.clear()
	inputs.clear()
	GameState.use_player(GameState.p1())
	session_ended.emit()

func player_count() -> int:
	return inputs.size() if active else 1

func get_input(index: int) -> PlayerInput:
	if active and index >= 0 and index < inputs.size():
		return inputs[index]
	return PlayerInput.solo()


# ── Dipakai sistem lain (aman saat solo) ────────────────────────────

func has_root() -> bool:
	return active and is_instance_valid(root)

## Tempat UI milik pemain (toko, lemari, mini-game) ditambahkan.
func ui_parent(player: Player) -> Node:
	if has_root() and player != null:
		var view: Node = root.view_of(player.player_index)
		if view != null:
			return view
	return get_tree().current_scene

## Tempat efek dunia (partikel, item jatuh) untuk pemain yang sedang beraksi.
func world_parent() -> Node:
	if has_root():
		var p := current_player()
		if p != null:
			return p.world_root()
	return get_tree().current_scene

## Player yang datanya = GameState.current.
func current_player() -> Player:
	if not has_root():
		return null
	return root.body_of(GameState.current.index)

func view_of(player: Player) -> Viewport:
	if has_root() and player != null:
		return root.view_of(player.player_index)
	return null

func camera_of(player: Player) -> Camera2D:
	if has_root() and player != null:
		return root.camera_of(player.player_index)
	return null

func hotbar_of(player: Player) -> Node:
	if player == null:
		return null
	return player.hotbar_ui

## Layer UI di layar pemain untuk efek Juice (ikon terbang, teks melayang).
func juice_layer_of(player: Player) -> CanvasLayer:
	if has_root() and player != null:
		return root.juice_layer_of(player.player_index)
	return null

## Buka/tutup menu (tas, toko, lemari). Solo: pause seperti biasa.
## Co-op: hanya pemain itu yang berhenti; waktu dan pemain lain tetap jalan.
func set_menu_open(player: Player, open: bool) -> void:
	if not active:
		get_tree().paused = open
		return
	if player != null:
		player.set_input_locked(&"menu", open)

## true jika event GUI ini boleh diproses UI milik `player` (event dari perangkat lain diabaikan).
func accepts_event(player: Player, event: InputEvent) -> bool:
	if not active or player == null:
		return true
	return player.input.owns_event(event)

## Hanya P1 yang mengontrol menu utama/pengaturan.
func is_p1_event(event: InputEvent) -> bool:
	if not active:
		return true
	return get_input(0).owns_event(event)

## Pindah area. Mengembalikan true jika ditangani co-op (pemanggil tidak perlu ganti scene).
func request_transition(body: Node, path: String) -> bool:
	if not has_root():
		return false
	if not (body is Player):
		return true
	var spawn: Variant = null
	if GameState.has_spawn_point:
		spawn = GameState.next_spawn_position
		GameState.has_spawn_point = false
	root.move_player(body, path, spawn)
	return true

## Sebelum hari berganti: FarmManager memakai layer Farm (atau tidak ada layer bila Farm
## sedang tidak dimuat; tile dipulihkan dari farm_data saat Farm dimuat lagi).
func bind_farm() -> void:
	if not has_root():
		return
	var farm: Node = root.world_of(root.START_AREA)
	if farm != null:
		FarmManager.bind_world(farm)
	else:
		FarmManager.clear_references()

## Pingsan jam 2 malam: semua pemain bangun di rumah.
func pass_out_all(spawn: Vector2, house_scene: String) -> void:
	if not has_root():
		return
	clear_sleeping()
	for p in GameState.players.slice(0, player_count()):
		p.stamina = int(PlayerData.MAX_STAMINA * 0.5)
	root.move_all(house_scene, spawn)

## Pemain berbaring/bangun di kasur. Mengembalikan jumlah pemain yang sedang tidur.
func set_sleeping(player: Player, sleeping: bool) -> int:
	if not has_root():
		return 0
	return root.set_sleeping(player, sleeping)

func is_sleeping(player: Player) -> bool:
	return has_root() and root.is_sleeping(player)

func clear_sleeping() -> void:
	if has_root():
		root.clear_sleeping()
