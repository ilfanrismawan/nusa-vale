class_name PlayerInput
extends RefCounted

## Input router milik satu pemain (GDD 4.3 "Kontrol & Konteks Input").
## Semua kode gameplay dan UI bertanya lewat sini (is_event / pressed / just_pressed),
## bukan langsung ke Input, supaya satu tombol bisa punya arti berbeda per konteks tanpa bentrok:
## B gamepad = tas di lapangan tetapi roll/lari saat memegang senjata, Spasi = lompat di lapangan
## tetapi roll saat memegang senjata, dan seterusnya (tabel di InputLayout).
##
## Konteks dihitung otomatis dari keadaan pemain (menu terbuka, melompat, memegang senjata
## dekat/jauh, selain itu lapangan). UI boleh mendorong konteks sendiri (push_context), mis.
## dialog NPC. Konteks dihitung per pemain, jadi di co-op menu P2 tidak mengubah tombol P1.
##
## Solo: aksi Input Map memakai nama dasar (use_tool, run, ...) dan menerima keyboard + gamepad
## mana pun. Co-op: tiap pemain mendapat salinan "p<n>_<aksi>" yang hanya berisi event
## perangkatnya. Binding yang hanya aktif di sebagian konteks disimpan di aksi tambahan
## "<aksi>@<konteks>" (dibuat saat runtime; project.godot tidak perlu diubah).

signal device_changed(using_pad: bool)

## P1 di co-op: keyboard + mouse.
const DEVICE_KEYBOARD := -1
## Hanya debug: pemain tambahan di numpad keyboard yang sama, untuk menguji tanpa gamepad.
const DEVICE_NUMPAD := -2
## Gamepad yang diterima aksi solo (set_solo_pad): semua gamepad, atau tidak ada sama sekali.
const SOLO_PAD_ANY := -1
const SOLO_PAD_NONE := -3

const L := preload("res://scripts/player/input_layout.gd")

## Aksi bawaan Godot yang dipakai game: tidak dibangun ulang dari tata letak, hanya ditambah
## tombol gamepad. Spasi pada ui_accept diabaikan di dunia (Spasi = lompat/roll), dan B pada
## ui_cancel diabaikan saat memegang senjata (B = roll/lari), lihat _excluded().
const UI_ACTIONS: Array[StringName] = [&"ui_accept", &"ui_cancel"]
const UI_JOY := {&"ui_accept": JOY_BUTTON_A, &"ui_cancel": JOY_BUTTON_B}

const NUMPAD_KEYS := {
	&"move_left": [KEY_KP_4],
	&"move_right": [KEY_KP_6],
	&"move_up": [KEY_KP_8],
	&"move_down": [KEY_KP_5, KEY_KP_2],
	&"run": [KEY_KP_3],
	&"use_tool": [KEY_KP_0],
	&"interact": [KEY_KP_1],
	&"ui_accept": [KEY_KP_1],
	&"ui_cancel": [KEY_KP_PERIOD],
	&"tool_prev": [KEY_KP_7],
	&"tool_next": [KEY_KP_9],
	&"inventory": [KEY_KP_MULTIPLY],
	&"cycle_hotbar": [KEY_KP_DIVIDE],
	&"jump": [KEY_KP_ADD],
	&"dodge": [KEY_KP_ADD],
}

## Stik kiri selalu menggerakkan pemain (tidak bisa diatur ulang).
const STICK_AXES := {
	&"move_left": [JOY_AXIS_LEFT_X, -1.0],
	&"move_right": [JOY_AXIS_LEFT_X, 1.0],
	&"move_up": [JOY_AXIS_LEFT_Y, -1.0],
	&"move_down": [JOY_AXIS_LEFT_Y, 1.0],
}
const MOVE_DEADZONE := 0.2
const STICK_DEADZONE := 0.35

## 0 = P1
var index: int = 0
var device: int = DEVICE_KEYBOARD
## P1 co-op yang bergabung dari main sendiri: gamepad yang tadi dipakai P1 tetap ikut
## (keyboard + mouse + gamepad ini). -1 = tidak ada.
var extra_pad: int = -1
## "" = aksi dasar (solo), "p2_" dst. di co-op.
var prefix: String = ""
## Pemain pemilik input ini (diisi Player._ready). Kosong = konteks Menu.
var _player_ref: WeakRef
## Konteks yang didorong UI: [[pemilik, konteks], ...]; yang terakhir menang.
var _stack: Array = []
## {aksi dasar: [[nama aksi Input Map, konteks], ...]}
var _variants: Dictionary = {}
## Solo: perangkat terakhir yang dipakai (prompt tombol dan cara membidik).
var _last_pad := false
## Waktu (msec) interaksi terakhir lewat tombol interaksi; dipakai untuk A = interaksi atau lompat.
var interacted_ms := -100000
## Tekanan yang dimulai di hotbar tetap milik UI selama tombol ditahan/di-drag.
var _hotbar_mouse_buttons: Dictionary = {}

static var _solo: PlayerInput
## Main sendiri: gamepad yang menggerakkan P1. Bawaan semua gamepad; saat pemain lain sedang
## bergabung (drop-in, game tidak dijeda) dibatasi ke gamepad P1 atau keyboard saja.
static var solo_pad: int = SOLO_PAD_ANY
static var _overrides: Dictionary = {}
static var _overrides_loaded := false
static var _rows_cache: Array[Dictionary] = []


## Input P1 saat main sendiri.
static func solo() -> PlayerInput:
	if _solo == null:
		_solo = PlayerInput.new()
		_solo._build()
	return _solo

## Batasi gamepad aksi solo (SOLO_PAD_ANY, SOLO_PAD_NONE, atau nomor gamepad P1).
static func set_solo_pad(pad: int) -> void:
	if solo_pad == pad:
		return
	solo_pad = pad
	if _solo != null:
		_solo._build()

## Input pemain co-op; membuat ulang aksi "p<n>_*" untuk perangkat ini.
static func create(p_index: int, p_device: int, p_extra_pad: int = -1) -> PlayerInput:
	var input := PlayerInput.new()
	input.index = p_index
	input.device = p_device
	input.extra_pad = p_extra_pad if p_device == DEVICE_KEYBOARD else -1
	input.prefix = "p%d_" % (p_index + 1)
	input._build()
	return input

## Kompatibilitas lama: aksi combat kini dibangun bersama tata letak.
static func ensure_combat_actions() -> void:
	solo()


# ── Tata letak & override ───────────────────────────────────────────

## Baris tata letak aktif (bawaan + pilihan pemain).
static func rows() -> Array[Dictionary]:
	if not _overrides_loaded:
		_overrides = L.load_overrides()
		_overrides_loaded = true
		_rows_cache.clear()
	if _rows_cache.is_empty():
		_rows_cache = L.rows_with(_overrides)
	return _rows_cache

## Ganti tombol satu baris ("kb" atau "pad"), simpan, lalu bangun ulang semua input.
static func set_binding(row_id: String, kind: String, specs: Array[String]) -> void:
	rows()
	if not _overrides.has(row_id):
		_overrides[row_id] = {}
	_overrides[row_id][kind] = specs
	_apply_overrides()

static func reset_bindings() -> void:
	rows()
	_overrides.clear()
	_apply_overrides()

static func _apply_overrides() -> void:
	L.save_overrides(_overrides)
	_rows_cache.clear()
	rebuild_all()

## Bangun ulang aksi solo dan semua pemain co-op (setelah tombol diganti).
static func rebuild_all() -> void:
	if _solo != null:
		_solo._build()
	var coop: Node = Engine.get_main_loop().root.get_node_or_null("Coop") if Engine.get_main_loop() is SceneTree else null
	if coop != null:
		for input in coop.inputs:
			input._build()

## Baris lain yang konteksnya bertabrakan dengan `spec` (untuk halaman Kontrol). Pasangan
## yang memang berbagi tombol (A = interaksi atau lompat) tidak dihitung bentrok.
static func conflicts(row_id: String, spec: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var me: Dictionary
	for row in rows():
		if row["id"] == row_id:
			me = row
	if me.is_empty():
		return out
	var kind := "pad" if L.is_pad_spec(spec) else "kb"
	var my_mask: int = me[kind][0][1] if not me[kind].is_empty() else L._default_mask(me)
	for row in rows():
		if row["id"] == row_id or _shares_by_design(me["action"], row["action"]):
			continue
		for b in row[kind]:
			if b[0] == spec and (int(b[1]) & my_mask) != 0:
				out.append(row)
				break
	return out

static func _shares_by_design(a: String, b: String) -> bool:
	return a == b or (a in ["interact", "jump"] and b in ["interact", "jump"])


# ── Pembuatan aksi ──────────────────────────────────────────────────

func _build() -> void:
	_variants.clear()
	var by_name := {}
	for base in L.actions():
		by_name[_name(base, L.ALL)] = []
		_variants[base] = [[_name(base, L.ALL), L.ALL]]
	for row in rows():
		var base := StringName(row["action"])
		for kind in ["kb", "pad"]:
			if not _device_accepts(kind):
				continue
			for b in row[kind]:
				var event := L.to_event(b[0], _joy_device())
				if event == null:
					continue
				var mask: int = b[1]
				var action_name := _name(base, mask)
				if not by_name.has(action_name):
					by_name[action_name] = []
					_variants[base].append([action_name, mask])
				by_name[action_name].append(event)
	if device != DEVICE_NUMPAD:
		var joy_ok := _device_accepts("pad")
		for base in STICK_AXES:
			if joy_ok:
				var m := InputEventJoypadMotion.new()
				m.axis = STICK_AXES[base][0]
				m.axis_value = STICK_AXES[base][1]
				m.device = _joy_device()
				by_name[_name(base, L.ALL)].append(m)
	else:
		for base in NUMPAD_KEYS:
			if not _variants.has(base):
				continue
			var action_name := _name(base, L.ALL)
			# Numpad uji: tombol tetap, tanpa konteks.
			by_name[action_name] = []
			for code in NUMPAD_KEYS[base]:
				var k := InputEventKey.new()
				k.physical_keycode = code
				k.device = -1
				by_name[action_name].append(k)
	for action_name in by_name:
		if InputMap.has_action(action_name):
			InputMap.action_erase_events(action_name)
		else:
			InputMap.add_action(action_name, MOVE_DEADZONE)
		InputMap.action_set_deadzone(action_name, 0.5 if String(action_name).contains("heavy_attack") or String(action_name).contains("weapon_art") or String(action_name).contains("aim") else MOVE_DEADZONE)
		for e in by_name[action_name]:
			InputMap.action_add_event(action_name, e)
	_build_ui_actions()

func _build_ui_actions() -> void:
	for base in UI_ACTIONS:
		_variants[base] = [[_name(base, L.ALL), L.ALL]]
		if prefix.is_empty():
			# Solo: aksi bawaan Godot (dipakai GUI) cukup ditambah tombol gamepad bila belum ada.
			if not InputMap.has_action(base):
				InputMap.add_action(base)
			if not _has_joy_button(base, UI_JOY[base]):
				var b := InputEventJoypadButton.new()
				b.button_index = UI_JOY[base]
				b.device = -1
				InputMap.action_add_event(base, b)
			continue
		var action_name := _name(base, L.ALL)
		if InputMap.has_action(action_name):
			InputMap.erase_action(action_name)
		InputMap.add_action(action_name, MOVE_DEADZONE)
		match device:
			DEVICE_KEYBOARD:
				for e in InputMap.action_get_events(base):
					if e is InputEventKey or e is InputEventMouseButton:
						InputMap.action_add_event(action_name, e)
				if extra_pad >= 0:
					var pb := InputEventJoypadButton.new()
					pb.button_index = UI_JOY[base]
					pb.device = extra_pad
					InputMap.action_add_event(action_name, pb)
			DEVICE_NUMPAD:
				for code in NUMPAD_KEYS.get(base, []):
					var k := InputEventKey.new()
					k.physical_keycode = code
					k.device = -1
					InputMap.action_add_event(action_name, k)
			_:
				var b := InputEventJoypadButton.new()
				b.button_index = UI_JOY[base]
				b.device = device
				InputMap.action_add_event(action_name, b)

func _has_joy_button(action: StringName, button: int) -> bool:
	for e in InputMap.action_get_events(action):
		if e is InputEventJoypadButton and e.button_index == button:
			return true
	return false

## Nama aksi Input Map untuk aksi dasar + konteks.
func _name(base: StringName, mask: int) -> StringName:
	var n := prefix + String(base)
	if mask != L.ALL:
		n += "@%d" % mask
	return StringName(n)

func _device_accepts(kind: String) -> bool:
	if prefix.is_empty():
		return kind == "kb" or solo_pad != SOLO_PAD_NONE
	if kind == "kb":
		return device == DEVICE_KEYBOARD
	return device >= 0 or extra_pad >= 0

func _joy_device() -> int:
	if device >= 0:
		return device
	if extra_pad >= 0:
		return extra_pad
	return solo_pad if prefix.is_empty() and solo_pad >= 0 else -1

func _is_pad() -> bool:
	return device >= 0


# ── Konteks ─────────────────────────────────────────────────────────

func bind_player(player: Node) -> void:
	_player_ref = weakref(player) if player != null else null

func player() -> Node:
	return _player_ref.get_ref() if _player_ref != null else null

## Dorong konteks (mis. InputLayout.DIALOGUE) selama `owner` hidup.
func push_context(owner: Object, context: int) -> void:
	pop_context(owner)
	_stack.append([weakref(owner), context])

func pop_context(owner: Object) -> void:
	for i in range(_stack.size() - 1, -1, -1):
		var o: Object = _stack[i][0].get_ref()
		if o == null or o == owner:
			_stack.remove_at(i)

## Konteks aktif pemain ini (satu bit InputLayout).
func context() -> int:
	for i in range(_stack.size() - 1, -1, -1):
		if _stack[i][0].get_ref() != null:
			return _stack[i][1]
		_stack.remove_at(i)
	var p := player() as Player
	if p == null or not p.is_inside_tree():
		return L.MENU
	if p.get_tree().paused or p.has_menu_open():
		return L.MENU
	if p.is_jumping():
		return L.AIR
	if p.is_swimming():
		return L.SWIM
	if p.is_riding():
		# Menumpang kendaraan: tata letak Lapangan apa pun yang dipegang (tombol Alat = turun).
		return L.FIELD
	return EquipmentContext.input_context(p.tool_controller.current_item if p.tool_controller != null else null)

func in_context(mask: int) -> bool:
	return (context() & mask) != 0


# ── Pertanyaan input ────────────────────────────────────────────────

## Nama aksi Input Map dasar (tanpa konteks). Dipakai tes/kode lama untuk action_press.
func action(base: StringName) -> StringName:
	return _name(base, L.ALL)

## Nama aksi Input Map yang aktif untuk `base` di konteks sekarang.
func active_actions(base: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	var ctx := context()
	for v in _variants.get(base, [[_name(base, L.ALL), L.ALL]]):
		if (int(v[1]) & ctx) != 0 and InputMap.has_action(v[0]):
			out.append(v[0])
	return out

func pressed(base: StringName) -> bool:
	for a in active_actions(base):
		if Input.is_action_pressed(a) and not _hotbar_blocks_action(a):
			return true
	return false

func just_pressed(base: StringName) -> bool:
	for a in active_actions(base):
		if Input.is_action_just_pressed(a) and not _hotbar_blocks_action(a):
			return true
	return false

func strength(base: StringName) -> float:
	var s := 0.0
	for a in active_actions(base):
		s = maxf(s, Input.get_action_raw_strength(a))
	return s

func get_vector() -> Vector2:
	var v := Vector2(strength(&"move_right") - strength(&"move_left"), strength(&"move_down") - strength(&"move_up"))
	var length := v.length()
	if length <= MOVE_DEADZONE:
		return Vector2.ZERO
	return v.normalized() * clampf(inverse_lerp(MOVE_DEADZONE, 1.0, length), 0.0, 1.0) if length < 1.0 else v.normalized()

## true jika event ini menekan aksi `base` milik pemain ini di konteks sekarang.
func is_event(event: InputEvent, base: StringName, allow_echo: bool = false) -> bool:
	if event == null:
		return false
	if event is InputEventMouseButton and _pointer_on_hotbar(event.position):
		return false
	for a in active_actions(base):
		if event.is_action_pressed(a, allow_echo):
			return not _excluded(event, base)
	return false

func _pointer_on_hotbar(position: Vector2) -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return false
	for hotbar in tree.get_nodes_in_group(&"hotbar_ui"):
		if hotbar.contains_pointer(position):
			return true
	return false

func _hotbar_blocks_action(action_name: StringName) -> bool:
	for binding in InputMap.action_get_events(action_name):
		if binding is InputEventMouseButton and _hotbar_mouse_buttons.has(binding.button_index):
			if Input.is_mouse_button_pressed(binding.button_index):
				return true
	return false

## Pengecualian untuk aksi bawaan Godot yang dipakai GUI (tidak bisa dipecah per konteks).
func _excluded(event: InputEvent, base: StringName) -> bool:
	var ctx := context()
	if base == &"ui_accept" and event is InputEventKey and (ctx & L.WORLD) != 0:
		return event.physical_keycode == KEY_SPACE or event.keycode == KEY_SPACE
	if base == &"ui_cancel" and event is InputEventJoypadButton and (ctx & L.COMBAT) != 0:
		return event.button_index == JOY_BUTTON_B
	return false

## Stik kanan (arah bidik gamepad). Vector2.ZERO bila tidak digerakkan.
func right_stick() -> Vector2:
	var best := Vector2.ZERO
	var pads: Array[int] = []
	if device >= 0:
		pads.append(device)
	elif extra_pad >= 0:
		pads.append(extra_pad)
	elif prefix.is_empty() and solo_pad >= 0:
		pads.append(solo_pad)
	elif prefix.is_empty() and solo_pad == SOLO_PAD_ANY:
		pads = Input.get_connected_joypads()
	for pad in pads:
		var v := Vector2(Input.get_joy_axis(pad, JOY_AXIS_RIGHT_X), Input.get_joy_axis(pad, JOY_AXIS_RIGHT_Y))
		if v.length() > best.length():
			best = v
	return best if best.length() >= STICK_DEADZONE else Vector2.ZERO


# ── Perangkat ───────────────────────────────────────────────────────

## Hanya P1 (keyboard) yang memakai mouse untuk membidik.
func uses_mouse() -> bool:
	return device == DEVICE_KEYBOARD

func is_gamepad() -> bool:
	return device >= 0

## true bila prompt dan bidikan sebaiknya memakai gamepad (perangkat terakhir yang dipakai).
func prefers_pad() -> bool:
	if device >= 0:
		return true
	if device == DEVICE_NUMPAD:
		return false
	return _last_pad

## Catat perangkat terakhir (dipanggil Player._input untuk setiap event).
func note_event(event: InputEvent) -> void:
	if event is InputEventMouseButton and owns_event(event) and event.pressed:
		if _pointer_on_hotbar(event.position):
			_hotbar_mouse_buttons[event.button_index] = true
		else:
			_hotbar_mouse_buttons.erase(event.button_index)
	if device != DEVICE_KEYBOARD:
		return
	var pad := _last_pad
	if event is InputEventJoypadButton:
		pad = true
	elif event is InputEventJoypadMotion:
		if absf(event.axis_value) > 0.5:
			pad = true
	elif event is InputEventKey or event is InputEventMouseButton:
		pad = false
	elif event is InputEventMouseMotion and event.relative.length() > 4.0:
		pad = false
	if pad != _last_pad:
		_last_pad = pad
		device_changed.emit(pad)

## true jika event berasal dari perangkat pemain ini (dipakai untuk menyaring event GUI).
func owns_event(event: InputEvent) -> bool:
	if prefix.is_empty():
		return true
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		var pad := device if device >= 0 else extra_pad
		return pad >= 0 and event.device == pad
	if event is InputEventMouse:
		return device == DEVICE_KEYBOARD
	if event is InputEventKey:
		return device < 0
	return false

func device_name() -> String:
	match device:
		DEVICE_KEYBOARD:
			return "Keyboard + Mouse" if extra_pad < 0 else "Keyboard + Mouse + Gamepad %d" % (extra_pad + 1)
		DEVICE_NUMPAD:
			return "Numpad (uji)"
	var joy := Input.get_joy_name(device)
	return joy if not joy.is_empty() else "Gamepad %d" % (device + 1)

## Tombol yang aktif untuk `base` di konteks `ctx` (-1 = sekarang), sebagai spesifikasi
## InputLayout. pad = true untuk tombol gamepad.
func bindings(base: StringName, pad: bool, ctx: int = -1) -> Array[String]:
	if ctx < 0:
		ctx = context()
	var out: Array[String] = []
	if device == DEVICE_NUMPAD:
		for code in NUMPAD_KEYS.get(base, []):
			out.append(L.key(code))
		return out
	for row in rows():
		if row["action"] != String(base):
			continue
		for b in row["pad" if pad else "kb"]:
			if (int(b[1]) & ctx) != 0 and not out.has(b[0]):
				out.append(b[0])
	return out


## Pemain pertama di `players` yang menekan salah satu aksi `bases` lewat event ini.
## Dicatat sebagai interaksi (gamepad A tidak lagi dianggap lompat).
static func find_presser(event: InputEvent, players: Array, bases: Array = [&"interact", &"ui_accept"]) -> Player:
	for p in players:
		if not is_instance_valid(p) or not (p is Player) or p.is_input_locked():
			continue
		for base in bases:
			if p.input.is_event(event, base):
				p.mark_interacted()
				return p
	return null
