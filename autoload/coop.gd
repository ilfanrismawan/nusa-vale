extends Node

## Autoload "Coop": sesi co-op lokal split screen (2-4 pemain).
## Solo (active = false) semua fungsi di sini jatuh ke perilaku lama, jadi kode lain
## boleh memanggilnya tanpa cek. Layar, area, dan perpindahan pemain diurus CoopRoot.
##
## Drop-in seperti Stardew (GDD 4.14): saat bermain, gamepad yang belum dipakai menekan Start
## -> panel pilih karakter (CoopJoinPane) di petak layar pemain baru, game TIDAK dijeda dan
## pemain lain tetap bermain -> pemain baru dimunculkan: dari main sendiri CoopRoot dibangun
## (fade singkat), saat sudah co-op layarnya ditambahkan langsung tanpa membangun ulang.
## F2 (P1) membatalkan pemain yang sedang bergabung. Pemain tamu keluar dengan menahan
## Start (atau P1 lewat menu pause); sisa P1 saja = kembali ke main sendiri tanpa ke main menu.

signal session_started
signal session_ended

const ROOT_SCENE := "res://scenes/main/coop_root.tscn"
const MAX_PLAYERS := 4
const JOIN_MENU := preload("res://scenes/ui/coop_join_menu.tscn")
const JOIN_PANE := preload("res://scenes/ui/coop_join_pane.tscn")
const DROP_IN := preload("res://scripts/system/coop_drop_in.gd")

var active := false
## Perangkat per pemain, urut bergabung. Index 0 = P1 (keyboard + mouse).
var devices: Array[int] = []
var inputs: Array[PlayerInput] = []
## CoopRoot yang sedang berjalan (null saat solo).
var root: Node
## Gamepad yang dipakai P1 saat main sendiri; tetap milik P1 (bersama keyboard + mouse)
## setelah co-op dimulai dari dalam game. -1 = P1 belum memakai gamepad.
var p1_pad: int = -1
## Untuk CoopRoot berikutnya: index pemain -> {"path": String, "position": Vector2}.
## Kosong = semua pemain mulai di Farm (lobby main menu).
var spawn_plan: Dictionary = {}
## Pesan yang ditampilkan CoopRoot saat dibangun (kosong = pesan mulai co-op biasa).
var start_notice: String = ""
## Simpan game saat pemain tamu keluar (tes mematikannya supaya tidak menulis slot save).
var save_on_leave := true
var _drop_in: Node
## Panel pemain yang sedang bergabung (null = tidak ada).
var _join_pane = null
var _switching := false


func _ready() -> void:
	_drop_in = DROP_IN.new()
	_drop_in.name = "CoopDropIn"
	get_tree().root.add_child.call_deferred(_drop_in)


## Mulai (atau bangun ulang) sesi. Pemain P2-P4 sudah disusun di GameState.players
## (seat_players); yang belum ada dibuat baru.
func start(p_devices: Array[int], plan: Dictionary = {}) -> void:
	devices = p_devices.duplicate()
	spawn_plan = plan.duplicate(true)
	inputs.clear()
	for i in devices.size():
		inputs.append(PlayerInput.create(i, devices[i], p1_pad if i == 0 else -1))
		GameState.ensure_player(i)
	GameState.players.resize(devices.size())
	GameState.use_player(GameState.p1())
	PlayerInput.set_solo_pad(PlayerInput.SOLO_PAD_ANY)
	active = true
	session_started.emit()
	DayCycle.is_running = true
	get_tree().change_scene_to_file(ROOT_SCENE)

## Kembali ke mode solo (dipanggil main menu, atau saat pemain tamu terakhir keluar).
func stop() -> void:
	if not active and root == null:
		return
	active = false
	root = null
	devices.clear()
	inputs.clear()
	spawn_plan.clear()
	GameState.players.resize(1)
	GameState.use_player(GameState.p1())
	session_ended.emit()


# ── Drop-in / keluar di tengah permainan ────────────────────────────

## true bila sedang di dalam game (bukan main menu).
func in_game() -> bool:
	if has_root():
		return true
	var scene := get_tree().current_scene
	return scene != null and get_tree().get_first_node_in_group("player") != null

## Perangkat ini sudah dipakai pemain (P1 atau tamu).
func device_in_use(device: int) -> bool:
	if device >= 0 and device == p1_pad:
		return true
	return active and devices.has(device)

## CoopRoot sedang dibangun ulang, atau ada pemain yang sedang bergabung.
func is_switching() -> bool:
	return _switching or has_pending_join()

## Ada pemain yang sedang memilih/membuat karakter atau menunggu dimunculkan.
func has_pending_join() -> bool:
	return is_instance_valid(_join_pane)

## Alasan pemain belum bisa bergabung/keluar sekarang; "" = boleh.
func block_reason(joining: bool) -> String:
	if not in_game():
		return "Mulai atau muat game dulu."
	if joining and player_count() >= MAX_PLAYERS:
		return "Co-op sudah penuh (4 pemain)."
	if not joining and has_pending_join():
		return "Tunggu pemain yang sedang bergabung selesai dulu."
	if _switching or Transition.on_transition:
		return "Tunggu sebentar, lalu coba lagi."
	if has_root():
		if root.has_busy_player() or root.sleeping_count() > 0:
			return "Tunggu pemain selesai pindah area atau bangun tidur."
	elif get_tree().paused:
		return "Menunggu P1 menutup menu."
	for plan in current_plan().values():
		if str(plan.get("path", "")).contains("/cave/"):
			return "Tidak bisa bergabung atau keluar saat ada pemain di gua."
	return ""

## Gamepad/numpad `device` ingin ikut: buka panel pilih karakter di petak layarnya.
## Game tidak dijeda; P1 dan pemain lain tetap bermain selama pemain baru memilih.
func request_join(device: int) -> void:
	if has_pending_join():
		Notify.say("Tunggu P%d selesai bergabung (F2 = batal)." % _join_pane.player_number)
		return
	if _switching:
		return
	if not in_game():
		Notify.say("Mulai atau muat game dulu.")
		return
	if player_count() >= MAX_PLAYERS:
		Notify.say("Co-op sudah penuh (4 pemain).")
		return
	var pane = JOIN_PANE.instantiate()
	pane.device = device
	pane.player_number = player_count() + 1
	pane.closed.connect(_on_join_pane_closed)
	_join_pane = pane
	if not active:
		# Main sendiri: aksi solo menerima semua gamepad, jadi kunci ke gamepad P1 supaya
		# stik/tombol pemain baru tidak ikut menggerakkan P1.
		PlayerInput.set_solo_pad(p1_pad if p1_pad >= 0 else PlayerInput.SOLO_PAD_NONE)
	get_tree().root.add_child(pane)

## Batalkan pemain yang sedang bergabung (F2 dari P1).
func cancel_join() -> void:
	if has_pending_join():
		_join_pane.cancel()

## Teruskan event milik perangkat pemain yang sedang bergabung ke panelnya.
## true = event sudah dipakai panel (jangan sampai ke game/menu pemain lain).
func forward_join_event(event: InputEvent) -> bool:
	if not has_pending_join() or not _join_pane.owns_event(event):
		return false
	_join_pane.forward(event)
	return true

## Gamepad pertama yang dipakai P1 saat main sendiri menjadi milik P1.
func claim_p1_pad(device: int) -> void:
	p1_pad = device
	if has_pending_join() and not active:
		PlayerInput.set_solo_pad(device)

func _on_join_pane_closed(joined: bool) -> void:
	_join_pane = null
	if not joined and not active:
		PlayerInput.set_solo_pad(PlayerInput.SOLO_PAD_ANY)

## Pemain yang sudah memilih karakter dimunculkan sekarang bila bisa.
## "" = berhasil; selain itu alasan menunggu (panel mencoba lagi sebentar kemudian).
func try_join(device: int, data: PlayerData) -> String:
	if _switching:
		return "Tunggu sebentar..."
	var reason := block_reason(true)
	if not reason.is_empty():
		return reason
	var plan := current_plan()
	# Pemain baru muncul di samping P1.
	var p1_plan: Dictionary = plan.get(0, {})
	var spawn := {"path": p1_plan.get("path", ""), "position": p1_plan.get("position", Vector2.ZERO) + Vector2(16, 0)}
	var guests: Array[PlayerData] = []
	for i in range(1, GameState.players.size()):
		guests.append(GameState.players[i])
	guests.append(data)
	if has_root():
		_hot_join(device, guests, spawn)
		return ""
	var new_devices: Array[int] = [PlayerInput.DEVICE_KEYBOARD, device]
	plan[1] = spawn
	GameState.seat_players(guests)
	start_notice = _join_notice(data, new_devices.size())
	_relaunch(new_devices, plan)
	return ""

## Sudah co-op: layar pemain baru ditambahkan ke CoopRoot yang berjalan, tanpa fade dan
## tanpa memuat ulang area; pemain lain tidak terganggu.
func _hot_join(device: int, guests: Array[PlayerData], spawn: Dictionary) -> void:
	var index := devices.size()
	GameState.seat_players(guests)
	devices.append(device)
	inputs.append(PlayerInput.create(index, device))
	GameState.use_player(GameState.p1())
	root.add_player(index, spawn)
	Notify.say(_join_notice(GameState.players[index], index + 1))

func _join_notice(data: PlayerData, number: int) -> String:
	return "%s bergabung sebagai P%d! Tahan Start untuk keluar." % [_display_name(data), number]

## Pemain tamu ke-index keluar. Datanya disimpan ke save; layar lain digabung ulang.
## Sisa P1 saja = kembali main sendiri di area dan posisinya.
func leave(index: int) -> void:
	if not has_root() or index <= 0 or index >= player_count() or _switching:
		return
	var reason := block_reason(false)
	if not reason.is_empty():
		Notify.say(reason)
		return
	var plan := current_plan()
	var leaving := GameState.get_player(index)
	var new_devices: Array[int] = []
	var guests: Array[PlayerData] = []
	var new_plan := {}
	for i in player_count():
		if i == index:
			continue
		if i > 0:
			guests.append(GameState.players[i])
		new_plan[new_devices.size()] = plan.get(i, {})
		new_devices.append(devices[i])
	var notice := "%s keluar dari co-op. Datanya tersimpan." % _display_name(leaving)
	if save_on_leave and not SaveManager.save_game():
		notice = "%s keluar dari co-op, tetapi game gagal disimpan." % _display_name(leaving)
	if guests.is_empty():
		_to_solo(new_plan.get(0, {}), notice)
		return
	GameState.seat_players(guests)
	start_notice = notice
	_relaunch(new_devices, new_plan)

## Area dan posisi tiap pemain sekarang: index -> {"path", "position"}.
func current_plan() -> Dictionary:
	var plan := {}
	if has_root():
		for i in player_count():
			plan[i] = {"path": root.area_path_of(i), "position": root.position_of(i)}
		return plan
	var scene := get_tree().current_scene
	var body := get_tree().get_first_node_in_group("player") as Node2D
	if scene == null or body == null:
		return plan
	var path := scene.scene_file_path
	if path.ends_with("coop_interior.tscn") or path.ends_with("barn_interior.tscn"):
		path += "#ranch=%d" % StructureManager.solo_ranch_uid
	plan[0] = {"path": path, "position": body.global_position}
	return plan

func _relaunch(new_devices: Array[int], plan: Dictionary) -> void:
	_switching = true
	var rebuild := func() -> void:
		start(new_devices, plan)
	await Transition.fade_action(rebuild, 0.2)
	_switching = false

func _to_solo(p1_plan: Dictionary, notice: String) -> void:
	_switching = true
	var path: String = p1_plan.get("path", "res://scenes/world/farm.tscn")
	if path.contains("#ranch="):
		StructureManager.solo_ranch_uid = int(path.get_slice("#ranch=", 1))
		path = path.get_slice("#ranch=", 0)
	var go_solo := func() -> void:
		stop()
		if p1_plan.has("position"):
			GameState.next_spawn_position = p1_plan["position"]
			GameState.has_spawn_point = true
		get_tree().change_scene_to_file(path)
		Notify.say(notice)
	await Transition.fade_action(go_solo, 0.2)
	_switching = false

func _display_name(data: PlayerData) -> String:
	if data == null or data.player_name.strip_edges().is_empty():
		return "Pemain baru"
	return data.player_name

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
		PauseManager.set_requested(open)
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

## Lewat 05.00: pemain terjaga pingsan; yang sudah tidur pulih penuh.
func pass_out_all(spawn: Vector2, house_scene: String) -> void:
	if not has_root():
		return
	for i in player_count():
		var p := GameState.get_player(i)
		var body: Player = root.body_of(i)
		p.stamina = p.max_stamina if is_sleeping(body) else int(p.max_stamina * 0.5)
		p.stamina_changed.emit(p.stamina, p.max_stamina)
	clear_sleeping()
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
