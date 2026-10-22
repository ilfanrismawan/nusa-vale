class_name InputPrompt
extends RefCounted

## Dynamic button prompt (GDD 4.3): teks tombol mengikuti perangkat terakhir yang dipakai
## pemain (keyboard/mouse atau gamepad) dan konteks sekarang, jadi "[E] Masuk" berubah jadi
## "[A] Masuk" begitu pemain memegang gamepad, dan ikut berubah bila tombol diatur ulang.

## Aksi bawaan Godot (tidak ada di InputLayout): [keyboard, gamepad].
const UI_KEYS := {&"ui_accept": ["Enter", "A"], &"ui_cancel": ["Esc", "B"]}

## Nama tombol untuk aksi `action` milik `player` (null = P1/solo), mis. "E" atau "A".
## ctx -1 = konteks sekarang. Beberapa tombol digabung dengan " / ".
static func key_text(action: StringName, player: Player = null, ctx: int = -1, max_keys: int = 2) -> String:
	var input := _input_of(player)
	var pad := input.prefers_pad()
	var specs := input.bindings(action, pad, ctx)
	if specs.is_empty() and action == &"dodge" and pad:
		# Gamepad: roll = tombol lari (B) ditekan singkat saat memegang senjata.
		var run := input.bindings(&"run", true, ctx)
		return (InputLayout.spec_label(run[0]) + " singkat") if not run.is_empty() else ""
	if specs.is_empty() and UI_KEYS.has(action):
		return UI_KEYS[action][1 if pad else 0]
	if specs.is_empty():
		return ""
	var labels: Array[String] = []
	for s in specs:
		if labels.size() >= max_keys:
			break
		labels.append(InputLayout.spec_label(s))
	return " / ".join(labels)

## "[E] teks" atau hanya teks bila aksi tidak punya tombol.
static func format(action: StringName, text: String, player: Player = null, ctx: int = -1) -> String:
	var k := key_text(action, player, ctx, 1)
	return "[%s] %s" % [k, text] if not k.is_empty() else text

static func _input_of(player: Player) -> PlayerInput:
	if is_instance_valid(player):
		return player.input
	return PlayerInput.solo()
