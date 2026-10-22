class_name InputLayout
extends RefCounted

## Tata letak tombol bawaan per konteks (GDD 4.3 "Kontrol & Konteks Input").
## Satu tombol boleh punya arti berbeda di konteks berbeda; PlayerInput hanya mengaktifkan
## binding yang konteksnya cocok, jadi tidak ada dua aksi yang berebut tombol yang sama.
## Lapangan mengikuti Stardew Valley, lompat mengikuti Story of Seasons: Grand Bazaar,
## dan combat (memegang senjata) mengikuti game soulslike (Elden Ring / Dark Souls).
## Pemain bisa mengganti tombol di Pengaturan > Kontrol; perubahan disimpan di OVERRIDE_PATH.

# ── Konteks (bit, boleh digabung) ───────────────────────────────────
## Memegang alat, benih, makanan, atau tangan kosong.
const FIELD := 1
## Sedang melompat.
const AIR := 2
## Berenang (disiapkan; belum ada air yang bisa direnangi di map utama).
const SWIM := 4
## Memegang senjata jarak dekat (pedang).
const MELEE := 8
## Memegang senjata jarak jauh (busur, tongkat sihir).
const RANGED := 16
## Tas, toko, dialog konfirmasi, menu lain.
const MENU := 32
## Bicara dengan NPC.
const DIALOGUE := 64

const EXPLORE := FIELD | AIR | SWIM
const COMBAT := MELEE | RANGED
const WORLD := EXPLORE | COMBAT
const UI := MENU | DIALOGUE
const ALL := WORLD | UI
const NON_COMBAT := ALL & ~COMBAT

const CONTEXT_NAMES := {
	FIELD: "Lapangan", AIR: "Di udara", SWIM: "Berenang", MELEE: "Combat jarak dekat",
	RANGED: "Combat jarak jauh", MENU: "Menu", DIALOGUE: "Dialog",
}

## File tombol pilihan pemain (terpisah dari settings.cfg dan save game).
const OVERRIDE_PATH := "user://input_bindings.cfg"

# ── Spesifikasi tombol ──────────────────────────────────────────────
# "key:<physical keycode>", "mouse:<button>", "joy:<button>", "axis:<axis>:<+1/-1>".

static func key(code: int) -> String:
	return "key:%d" % code

static func mouse(button: int) -> String:
	return "mouse:%d" % button

static func joy(button: int) -> String:
	return "joy:%d" % button

static func axis(a: int, direction: float) -> String:
	return "axis:%d:%d" % [a, 1 if direction > 0.0 else -1]

## Baris yang bisa diatur pemain. kb/pad = [[spesifikasi, konteks], ...].
## Satu aksi boleh punya beberapa baris (mis. lari di lapangan RT, lari di combat B).
## show = false: tetap aktif tetapi tidak tampil di halaman Kontrol.
static func default_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	# Lapangan (Stardew Valley)
	rows.append(_row("move_up", "Jalan ke atas", "Lapangan", [[key(KEY_W), ALL]], [[joy(JOY_BUTTON_DPAD_UP), ALL]]))
	rows.append(_row("move_down", "Jalan ke bawah", "Lapangan", [[key(KEY_S), ALL]], [[joy(JOY_BUTTON_DPAD_DOWN), ALL]]))
	rows.append(_row("move_left", "Jalan ke kiri", "Lapangan", [[key(KEY_A), ALL]], [[joy(JOY_BUTTON_DPAD_LEFT), NON_COMBAT]]))
	rows.append(_row("move_right", "Jalan ke kanan", "Lapangan", [[key(KEY_D), ALL]], [[joy(JOY_BUTTON_DPAD_RIGHT), NON_COMBAT]]))
	rows.append(_row("use_tool", "Pakai alat / serang", "Lapangan", [[mouse(MOUSE_BUTTON_LEFT), WORLD], [key(KEY_C), WORLD]], [[joy(JOY_BUTTON_X), EXPLORE]]))
	rows.append(_row("interact", "Interaksi / bicara / periksa", "Lapangan", [[key(KEY_E), ALL], [key(KEY_X), ALL], [mouse(MOUSE_BUTTON_RIGHT), EXPLORE | UI]], [[joy(JOY_BUTTON_A), ALL]]))
	rows.append(_row("run", "Lari (tahan)", "Lapangan", [[key(KEY_SHIFT), WORLD]], [[axis(JOY_AXIS_TRIGGER_RIGHT, 1.0), EXPLORE]]))
	rows.append(_row("inventory", "Tas / menu", "Lapangan", [[key(KEY_I), ALL], [key(KEY_ESCAPE), ALL]], [[joy(JOY_BUTTON_B), EXPLORE | MENU], [joy(JOY_BUTTON_START), ALL]]))
	rows.append(_row("crafting_menu", "Tas tab Crafting / beri hadiah", "Lapangan", [], [[joy(JOY_BUTTON_Y), ALL]]))
	rows.append(_row("tool_prev", "Slot sebelumnya", "Lapangan", [[mouse(MOUSE_BUTTON_WHEEL_UP), WORLD], [key(KEY_LEFT), WORLD]], [[joy(JOY_BUTTON_LEFT_SHOULDER), EXPLORE | MENU], [joy(JOY_BUTTON_DPAD_LEFT), COMBAT]]))
	rows.append(_row("tool_next", "Slot berikutnya", "Lapangan", [[mouse(MOUSE_BUTTON_WHEEL_DOWN), WORLD], [key(KEY_RIGHT), WORLD]], [[joy(JOY_BUTTON_RIGHT_SHOULDER), EXPLORE | MENU], [joy(JOY_BUTTON_DPAD_RIGHT), COMBAT]]))
	rows.append(_row("cycle_hotbar", "Halaman hotbar", "Lapangan", [[key(KEY_TAB), WORLD]], [[joy(JOY_BUTTON_BACK), WORLD]]))
	rows.append(_row("sort_inventory", "Rapikan tas", "Lapangan", [[key(KEY_R), WORLD | MENU]], [[joy(JOY_BUTTON_RIGHT_STICK), EXPLORE | MENU]]))
	for i in 8:
		rows.append(_row("slot_%d" % (i + 1), "Slot %d" % (i + 1), "Lapangan", [[key(KEY_1 + i), WORLD]], [], false))
	# Lompat (Story of Seasons: Grand Bazaar). Gamepad A juga interaksi: bila ada yang bisa
	# diajak interaksi, A = interaksi; selain itu A = lompat.
	rows.append(_row("jump", "Lompat (di udara: lompat ganda)", "Lompat", [[key(KEY_SPACE), EXPLORE]], [[joy(JOY_BUTTON_A), EXPLORE]]))
	# Combat (soulslike): aktif hanya saat memegang senjata.
	rows.append(_row("use_tool", "Serang ringan (tahan = berat)", "Combat", [], [[joy(JOY_BUTTON_RIGHT_SHOULDER), COMBAT], [joy(JOY_BUTTON_X), COMBAT]]))
	rows.append(_row("heavy_attack", "Serangan berat", "Combat", [], [[axis(JOY_AXIS_TRIGGER_RIGHT, 1.0), COMBAT]]))
	rows.append(_row("dodge", "Roll", "Combat", [[key(KEY_SPACE), COMBAT]], []))
	rows.append(_row("run", "Lari (tahan) / roll (tekan singkat)", "Combat", [], [[joy(JOY_BUTTON_B), COMBAT]]))
	rows.append(_row("guard", "Tangkis (tahan) / parry (tepat waktu)", "Combat", [[mouse(MOUSE_BUTTON_RIGHT), MELEE]], [[joy(JOY_BUTTON_LEFT_SHOULDER), COMBAT]]))
	rows.append(_row("aim", "Bidik busur / tongkat (tahan)", "Combat", [[mouse(MOUSE_BUTTON_RIGHT), RANGED]], [[axis(JOY_AXIS_TRIGGER_LEFT, 1.0), RANGED]]))
	rows.append(_row("weapon_art", "Weapon Art", "Combat", [[key(KEY_F), COMBAT]], [[axis(JOY_AXIS_TRIGGER_LEFT, 1.0), MELEE], [joy(JOY_BUTTON_LEFT_STICK), COMBAT]]))
	rows.append(_row("lock_on", "Kunci target (lock-on)", "Combat", [[key(KEY_Q), COMBAT], [mouse(MOUSE_BUTTON_MIDDLE), COMBAT]], [[joy(JOY_BUTTON_RIGHT_STICK), COMBAT]]))
	for i in rows.size():
		rows[i]["id"] = "%s#%d" % [rows[i]["action"], _nth_row_of(rows, i)]
	return rows

static func _row(action: String, label: String, group: String, kb: Array, pad: Array, show: bool = true) -> Dictionary:
	return {"action": action, "label": label, "group": group, "kb": kb, "pad": pad, "show": show}

static func _nth_row_of(rows: Array[Dictionary], index: int) -> int:
	var n := 0
	for i in index:
		if rows[i]["action"] == rows[index]["action"]:
			n += 1
	return n

## Semua aksi yang diatur tata letak ini (urut, tanpa duplikat).
static func actions() -> Array[StringName]:
	var out: Array[StringName] = []
	for row in default_rows():
		var a := StringName(row["action"])
		if not out.has(a):
			out.append(a)
	return out

# ── Override pilihan pemain ─────────────────────────────────────────

## {row_id: {"kb": [spec...], "pad": [spec...]}} dari OVERRIDE_PATH.
static func load_overrides() -> Dictionary:
	var cfg := ConfigFile.new()
	var out := {}
	if cfg.load(OVERRIDE_PATH) != OK:
		return out
	if not cfg.has_section("bindings"):
		return out
	for k in cfg.get_section_keys("bindings"):
		var parts := String(k).rsplit("|", true, 1)
		if parts.size() != 2 or not (parts[1] in ["kb", "pad"]):
			continue
		var value: Variant = cfg.get_value("bindings", k, [])
		if not value is Array:
			continue
		var specs: Array[String] = []
		for s in value:
			if s is String and spec_valid(s):
				specs.append(s)
		if not out.has(parts[0]):
			out[parts[0]] = {}
		out[parts[0]][parts[1]] = specs
	return out

static func save_overrides(overrides: Dictionary) -> void:
	var cfg := ConfigFile.new()
	cfg.load(OVERRIDE_PATH)
	if cfg.has_section("bindings"):
		cfg.erase_section("bindings")
	for row_id in overrides:
		for kind in overrides[row_id]:
			cfg.set_value("bindings", "%s|%s" % [row_id, kind], overrides[row_id][kind])
	cfg.save(OVERRIDE_PATH)

static func load_option(option: String, default: Variant) -> Variant:
	var cfg := ConfigFile.new()
	if cfg.load(OVERRIDE_PATH) != OK:
		return default
	return cfg.get_value("options", option, default)

static func save_option(option: String, value: Variant) -> void:
	var cfg := ConfigFile.new()
	cfg.load(OVERRIDE_PATH)
	cfg.set_value("options", option, value)
	cfg.save(OVERRIDE_PATH)

## Baris bawaan dengan override pemain diterapkan. Konteks setiap baris tetap; override hanya
## mengganti tombolnya (semua tombol baris itu memakai konteks binding pertamanya).
static func rows_with(overrides: Dictionary) -> Array[Dictionary]:
	var rows := default_rows()
	for row in rows:
		var o: Dictionary = overrides.get(row["id"], {})
		for kind in ["kb", "pad"]:
			if not o.has(kind):
				continue
			var mask: int = row[kind][0][1] if not row[kind].is_empty() else _default_mask(row)
			var replaced: Array = []
			for s in o[kind]:
				replaced.append([s, mask])
			row[kind] = replaced
	return rows

static func _default_mask(row: Dictionary) -> int:
	for kind in ["kb", "pad"]:
		if not row[kind].is_empty():
			return row[kind][0][1]
	return ALL

# ── Konversi ────────────────────────────────────────────────────────

static func spec_valid(spec: String) -> bool:
	return to_event(spec, -1) != null

static func is_pad_spec(spec: String) -> bool:
	return spec.begins_with("joy:") or spec.begins_with("axis:")

## Event Input Map dari spesifikasi. device -1 = semua perangkat.
static func to_event(spec: String, device: int) -> InputEvent:
	var parts := spec.split(":")
	if parts.size() < 2 or not parts[1].is_valid_int():
		return null
	var code := int(parts[1])
	match parts[0]:
		"key":
			var k := InputEventKey.new()
			k.physical_keycode = code as Key
			k.device = -1
			return k
		"mouse":
			var m := InputEventMouseButton.new()
			m.button_index = code as MouseButton
			m.device = -1
			return m
		"joy":
			var b := InputEventJoypadButton.new()
			b.button_index = code as JoyButton
			b.device = device
			return b
		"axis":
			if parts.size() < 3:
				return null
			var a := InputEventJoypadMotion.new()
			a.axis = code as JoyAxis
			a.axis_value = 1.0 if int(parts[2]) > 0 else -1.0
			a.device = device
			return a
	return null

## Spesifikasi dari event yang baru ditekan (halaman Kontrol). "" bila tidak bisa dipakai.
static func from_event(event: InputEvent) -> String:
	if event is InputEventKey and event.pressed and not event.echo:
		var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		return key(code) if code != 0 else ""
	if event is InputEventMouseButton and event.pressed:
		return mouse(event.button_index)
	if event is InputEventJoypadButton and event.pressed:
		return joy(event.button_index)
	if event is InputEventJoypadMotion and absf(event.axis_value) >= 0.6 \
			and event.axis in [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]:
		return axis(event.axis, event.axis_value)
	return ""

const MOUSE_NAMES := {
	MOUSE_BUTTON_LEFT: "Klik kiri", MOUSE_BUTTON_RIGHT: "Klik kanan", MOUSE_BUTTON_MIDDLE: "Klik tengah",
	MOUSE_BUTTON_WHEEL_UP: "Scroll atas", MOUSE_BUTTON_WHEEL_DOWN: "Scroll bawah",
	MOUSE_BUTTON_XBUTTON1: "Mouse 4", MOUSE_BUTTON_XBUTTON2: "Mouse 5",
}
## Nama tombol gamepad (tata letak Xbox).
const JOY_NAMES := {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_BACK: "Back", JOY_BUTTON_START: "Start",
	JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_DPAD_UP: "D-pad ↑", JOY_BUTTON_DPAD_DOWN: "D-pad ↓",
	JOY_BUTTON_DPAD_LEFT: "D-pad ←", JOY_BUTTON_DPAD_RIGHT: "D-pad →",
}
const AXIS_NAMES := {JOY_AXIS_TRIGGER_LEFT: "LT", JOY_AXIS_TRIGGER_RIGHT: "RT"}
const KEY_NAMES := {
	KEY_SPACE: "Spasi", KEY_SHIFT: "Shift", KEY_ESCAPE: "Esc", KEY_TAB: "Tab", KEY_ENTER: "Enter",
	KEY_LEFT: "←", KEY_RIGHT: "→", KEY_UP: "↑", KEY_DOWN: "↓", KEY_CTRL: "Ctrl", KEY_ALT: "Alt",
}

## Teks pendek untuk satu spesifikasi ("Spasi", "Klik kanan", "A", "RT").
static func spec_label(spec: String) -> String:
	var parts := spec.split(":")
	if parts.size() < 2:
		return "?"
	var code := int(parts[1])
	match parts[0]:
		"key":
			return KEY_NAMES.get(code, OS.get_keycode_string(code as Key))
		"mouse":
			return MOUSE_NAMES.get(code, "Mouse %d" % code)
		"joy":
			return JOY_NAMES.get(code, "Tombol %d" % code)
		"axis":
			return AXIS_NAMES.get(code, "Stik")
	return "?"
