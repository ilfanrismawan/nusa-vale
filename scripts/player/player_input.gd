class_name PlayerInput
extends RefCounted

## Input milik satu pemain.
## Solo: memakai aksi Input Map apa adanya (move_left, use_tool, ...), plus tombol gamepad bawaan.
## Co-op: setiap pemain mendapat salinan aksi "p<n>_<aksi>" yang hanya berisi event perangkatnya,
## jadi gamepad P2 tidak menggerakkan P1. Dibuat saat runtime; project.godot tidak perlu diubah.

## P1 di co-op: keyboard + mouse.
const DEVICE_KEYBOARD := -1
## Hanya debug: pemain tambahan di numpad keyboard yang sama, untuk menguji tanpa gamepad.
const DEVICE_NUMPAD := -2

const ACTIONS: Array[StringName] = [
	&"move_left", &"move_right", &"move_up", &"move_down", &"run",
	&"use_tool", &"interact", &"aim", &"tool_next", &"tool_prev",
	&"slot_1", &"slot_2", &"slot_3", &"slot_4", &"slot_5", &"slot_6", &"slot_7", &"slot_8",
	&"inventory", &"cycle_hotbar", &"sort_inventory", &"ui_accept", &"ui_cancel",
]

## Tombol gamepad bawaan (A = interaksi, X = pakai alat, B = lari/batal, LB/RB = ganti slot,
## Y = tas, Back = halaman hotbar, klik stik kanan = rapikan tas).
const JOY_BUTTONS := {
	&"move_left": [JOY_BUTTON_DPAD_LEFT],
	&"move_right": [JOY_BUTTON_DPAD_RIGHT],
	&"move_up": [JOY_BUTTON_DPAD_UP],
	&"move_down": [JOY_BUTTON_DPAD_DOWN],
	&"run": [JOY_BUTTON_B],
	&"use_tool": [JOY_BUTTON_X],
	&"interact": [JOY_BUTTON_A],
	&"ui_accept": [JOY_BUTTON_A],
	&"ui_cancel": [JOY_BUTTON_B],
	&"tool_prev": [JOY_BUTTON_LEFT_SHOULDER],
	&"tool_next": [JOY_BUTTON_RIGHT_SHOULDER],
	&"inventory": [JOY_BUTTON_Y],
	&"cycle_hotbar": [JOY_BUTTON_BACK],
	&"sort_inventory": [JOY_BUTTON_RIGHT_STICK],
}
## [sumbu, arah]
const JOY_AXES := {
	&"move_left": [JOY_AXIS_LEFT_X, -1.0],
	&"move_right": [JOY_AXIS_LEFT_X, 1.0],
	&"move_up": [JOY_AXIS_LEFT_Y, -1.0],
	&"move_down": [JOY_AXIS_LEFT_Y, 1.0],
	&"run": [JOY_AXIS_TRIGGER_LEFT, 1.0],
	&"use_tool": [JOY_AXIS_TRIGGER_RIGHT, 1.0],
}
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
}

## 0 = P1
var index: int = 0
var device: int = DEVICE_KEYBOARD
## "" = aksi dasar (solo), "p2_" dst. di co-op.
var prefix: String = ""

static var _solo: PlayerInput


## Input P1 saat main sendiri.
static func solo() -> PlayerInput:
	if _solo == null:
		_solo = PlayerInput.new()
		_solo._add_joy_defaults_to_base()
	return _solo

## Input pemain co-op; membuat ulang aksi "p<n>_*" untuk perangkat ini.
static func create(p_index: int, p_device: int) -> PlayerInput:
	var input := PlayerInput.new()
	input.index = p_index
	input.device = p_device
	input.prefix = "p%d_" % (p_index + 1)
	input._register_actions()
	return input


func action(base: StringName) -> StringName:
	if prefix.is_empty():
		return base
	return StringName(prefix + String(base))

func pressed(base: StringName) -> bool:
	var a := action(base)
	return InputMap.has_action(a) and Input.is_action_pressed(a)

func just_pressed(base: StringName) -> bool:
	var a := action(base)
	return InputMap.has_action(a) and Input.is_action_just_pressed(a)

func get_vector() -> Vector2:
	return Input.get_vector(action(&"move_left"), action(&"move_right"), action(&"move_up"), action(&"move_down"))

## true jika event ini menekan aksi `base` milik pemain ini.
func is_event(event: InputEvent, base: StringName, allow_echo: bool = false) -> bool:
	var a := action(base)
	return InputMap.has_action(a) and event.is_action_pressed(a, allow_echo)

## Hanya P1 (keyboard) yang memakai mouse untuk membidik.
func uses_mouse() -> bool:
	return device == DEVICE_KEYBOARD

func is_gamepad() -> bool:
	return device >= 0

## true jika event berasal dari perangkat pemain ini (dipakai untuk menyaring event GUI).
func owns_event(event: InputEvent) -> bool:
	if prefix.is_empty():
		return true
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		return device >= 0 and event.device == device
	if event is InputEventMouse:
		return device == DEVICE_KEYBOARD
	if event is InputEventKey:
		return device < 0
	return false

func device_name() -> String:
	match device:
		DEVICE_KEYBOARD:
			return "Keyboard + Mouse"
		DEVICE_NUMPAD:
			return "Numpad (uji)"
	var joy := Input.get_joy_name(device)
	return joy if not joy.is_empty() else "Gamepad %d" % (device + 1)


## Pemain pertama di `players` yang menekan salah satu aksi `bases` lewat event ini.
static func find_presser(event: InputEvent, players: Array, bases: Array = [&"interact", &"ui_accept"]) -> Player:
	for p in players:
		if not is_instance_valid(p) or not (p is Player) or p.is_input_locked():
			continue
		for base in bases:
			if p.input.is_event(event, base):
				return p
	return null


# ── Pembuatan aksi ──────────────────────────────────────────────────

func _register_actions() -> void:
	for base in ACTIONS:
		var name := action(base)
		if InputMap.has_action(name):
			InputMap.erase_action(name)
		var deadzone := InputMap.action_get_deadzone(base) if InputMap.has_action(base) else 0.2
		InputMap.add_action(name, deadzone)
		match device:
			DEVICE_KEYBOARD:
				if InputMap.has_action(base):
					for e in InputMap.action_get_events(base):
						if e is InputEventKey or e is InputEventMouseButton:
							InputMap.action_add_event(name, e)
			DEVICE_NUMPAD:
				for key in NUMPAD_KEYS.get(base, []):
					var k := InputEventKey.new()
					k.physical_keycode = key
					InputMap.action_add_event(name, k)
			_:
				for e in _joy_events(base, device):
					InputMap.action_add_event(name, e)

## Solo: gamepad (perangkat mana pun) ikut bisa dipakai P1.
func _add_joy_defaults_to_base() -> void:
	for base in ACTIONS:
		if not InputMap.has_action(base):
			continue
		var has_joy := false
		for e in InputMap.action_get_events(base):
			if e is InputEventJoypadButton or e is InputEventJoypadMotion:
				has_joy = true
				break
		if has_joy:
			continue
		for e in _joy_events(base, -1):
			InputMap.action_add_event(base, e)

static func _joy_events(base: StringName, joy_device: int) -> Array[InputEvent]:
	var events: Array[InputEvent] = []
	for button in JOY_BUTTONS.get(base, []):
		var b := InputEventJoypadButton.new()
		b.button_index = button
		b.device = joy_device
		events.append(b)
	if JOY_AXES.has(base):
		var m := InputEventJoypadMotion.new()
		m.axis = JOY_AXES[base][0]
		m.axis_value = JOY_AXES[base][1]
		m.device = joy_device
		events.append(m)
	return events
