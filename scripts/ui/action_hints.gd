class_name ActionHints
extends Control

## Petunjuk tombol di pojok kiri bawah HUD (GDD 4.3): menampilkan arti tombol penting di
## konteks sekarang (lapangan, di udara, combat dekat/jauh) dengan tombol perangkat terakhir
## yang dipakai, mis. "[A] Interaksi / Lompat  [X] Alat". Disembunyikan saat menu/dialog terbuka.
## Bisa dimatikan di Pengaturan > Kontrol (InputLayout opsi "show_hints").

const OPTION := "show_hints"

## [aksi, teks] per konteks.
const ENTRIES := {
	InputLayout.FIELD: [[&"interact", "Interaksi"], [&"jump", "Lompat"], [&"use_tool", "Alat"], [&"run", "Lari"]],
	InputLayout.AIR: [[&"jump", "Lompat ganda"]],
	InputLayout.SWIM: [[&"jump", "Menyelam"], [&"run", "Renang cepat"]],
	InputLayout.MELEE: [[&"use_tool", "Serang"], [&"heavy_attack", "Berat"], [&"dodge", "Roll"], [&"guard", "Tangkis"], [&"weapon_art", "Art"], [&"lock_on", "Kunci"]],
	InputLayout.RANGED: [[&"aim", "Bidik"], [&"use_tool", "Tembak"], [&"dodge", "Roll"], [&"lock_on", "Kunci"]],
}

static var enabled := true
static var _enabled_loaded := false

var player: Player
var _timer := 0.0
var _last_key := ""

static func set_enabled(value: bool) -> void:
	enabled = value
	_enabled_loaded = true
	InputLayout.save_option(OPTION, value)

static func is_enabled() -> bool:
	if not _enabled_loaded:
		enabled = bool(InputLayout.load_option(OPTION, true))
		_enabled_loaded = true
	return enabled

@export var hint_scene: PackedScene = preload("res://scenes/ui/action_hint_badge.tscn")
@export var entries: Dictionary = ENTRIES.duplicate(true)
@export_range(0.05, 1.0) var refresh_interval := 0.15
@export var screen_margin := Vector2(16, 94)
@export var right_reserve := 110.0
var extra_bottom := 0.0
var text := ""
@onready var _flow: HFlowContainer = %Hints

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_viewport().size_changed.connect(layout_for_viewport)
	_flow.resized.connect(layout_for_viewport)
	hide()

func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0:
		return
	_timer = refresh_interval
	var prompts := build_entries()
	var signature := JSON.stringify(prompts)
	if signature != _last_key:
		_last_key = signature
		_rebuild(prompts)
	visible = not prompts.is_empty()
	layout_for_viewport()

func layout_for_viewport() -> void:
	var view := get_viewport().get_visible_rect().size
	var available := maxf(80.0, view.x - screen_margin.x * 2 - minf(right_reserve, view.x * 0.18))
	_flow.size = Vector2(available, 0)
	size = Vector2(available, _flow.size.y)
	position = Vector2(screen_margin.x, maxf(8.0, view.y - screen_margin.y - extra_bottom - _flow.size.y))

func _rebuild(prompts: Array[Dictionary]) -> void:
	for child in _flow.get_children():
		_flow.remove_child(child)
		child.queue_free()
	for prompt in prompts:
		var badge := hint_scene.instantiate()
		_flow.add_child(badge)
		badge.get_node("Layout/Key/KeyText").text = prompt.key
		badge.get_node("Layout/Action").text = prompt.label
	text = build_text()
	layout_for_viewport.call_deferred()

func build_entries() -> Array[Dictionary]:
	var prompts: Array[Dictionary] = []
	if not is_enabled() or not is_instance_valid(player) or player.is_input_locked() or player.is_defeated:
		return prompts
	var context := player.input.context()
	if not entries.has(context):
		return prompts
	var actions: Array = entries[context].duplicate(true)
	if player.is_riding():
		actions = [[&"interact", "Interaksi"], [&"use_tool", "Turun"]]
	if context == InputLayout.AIR and EquipmentContext.is_seed(player.tool_controller.current_item):
		actions.append([&"use_tool", "Tebar benih"])
	for entry in actions:
		var key := InputPrompt.key_text(entry[0], player, context, 1)
		if key.is_empty():
			continue
		var duplicate := -1
		for index in prompts.size():
			if prompts[index].key == key:
				duplicate = index
				break
		if duplicate >= 0:
			prompts[duplicate].label += " / " + str(entry[1])
		else:
			prompts.append({"key": key, "label": str(entry[1])})
	return prompts

func build_text() -> String:
	var parts := PackedStringArray()
	for prompt in build_entries():
		parts.append("[%s] %s" % [prompt.key, prompt.label])
	return "   ".join(parts)
