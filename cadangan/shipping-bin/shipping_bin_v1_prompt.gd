class_name ShippingBin
extends Area2D

## Kotak jual. Pemain mendekat, menghadap kotak, lalu menekan interact (E / X / klik kanan,
## A di gamepad) untuk membuka tas dalam mode jual. Bisa juga lewat Player._try_interact.

const PROMPT_FONT := preload("res://assets/fonts/m5x7.ttf")
const FEET_OFFSET := Vector2(0, 8)
## Pemain yang berdiri sedekat ini dianggap menghadap kotak dari arah mana pun.
const CLOSE_DISTANCE := 10.0
## Batas dot(arah hadap, arah ke kotak) agar dianggap menghadap.
const FACING_DOT := 0.3
const HIGHLIGHT := Color(1.25, 1.25, 1.25)

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")

var player_in_range: bool:
	get: return not _players.is_empty()
var _players: Array[Player] = []
var _prompt: Label

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_build_prompt()

func _on_body_entered(body: Node2D) -> void:
	if body is Player and not _players.has(body):
		_players.append(body)

func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		_players.erase(body)

func _process(_delta: float) -> void:
	_update_prompt()

func _unhandled_input(event: InputEvent) -> void:
	var player := PlayerInput.find_presser(event, _players)
	if player == null or not is_facing(player):
		return
	get_viewport().set_input_as_handled()
	interact(player)

## `player` kosong = pemain yang sedang beraksi (dipanggil dari Player._try_interact).
func interact(player: Player = null) -> void:
	if player == null:
		player = Coop.current_player()
	if player == null and not _players.is_empty():
		player = _players[0]
	if player == null or player.is_input_locked():
		return
	var bag: Node = player.ui_inventory
	if bag != null and bag.visible:
		return
	# Co-op: yang dijual isi tas pemain yang menekan; uangnya masuk ke uang bersama.
	GameState.use_player(player)
	# Buka tas dalam mode jual: pemain memilih item dan jumlahnya (lihat ui_inventory.gd).
	if bag != null and bag.has_method("open_sell_mode"):
		bag.open_sell_mode()
	else:
		sell_harvested_items()

## true jika pemain berada di area kotak dan menghadap ke arahnya.
func is_facing(player: Player) -> bool:
	var to_bin := global_position - (player.global_position + FEET_OFFSET)
	if to_bin.length() <= CLOSE_DISTANCE:
		return true
	return player.facing_direction.dot(to_bin.normalized()) >= FACING_DOT

## Pemain pertama yang bisa membuka kotak sekarang (dekat, menghadap, tidak sedang di menu).
func _ready_player() -> Player:
	for p in _players:
		if not is_instance_valid(p) or p.is_input_locked():
			continue
		if p.ui_inventory != null and p.ui_inventory.visible:
			continue
		if is_facing(p):
			return p
	return null

func _build_prompt() -> void:
	var settings := LabelSettings.new()
	settings.font = PROMPT_FONT
	settings.font_size = 16
	settings.font_color = Color(1, 0.96, 0.85)
	settings.outline_size = 4
	settings.outline_color = Color(0.12, 0.08, 0.06)
	_prompt = Label.new()
	_prompt.name = "Prompt"
	_prompt.label_settings = settings
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt.z_index = 20
	_prompt.size = Vector2(48, 14)
	_prompt.position = Vector2(-24, -24)
	_prompt.hide()
	add_child(_prompt)

func _update_prompt() -> void:
	var player := _ready_player()
	var show_prompt := player != null
	if show_prompt:
		_prompt.text = ("A" if player.input.is_gamepad() else "E") + " Jual"
	_prompt.visible = show_prompt
	if sprite != null:
		sprite.modulate = HIGHLIGHT if show_prompt else Color.WHITE

## Jual semua barang yang bisa dijual sekaligus (cadangan bila UI tas tidak ada).
func sell_harvested_items() -> void:
	var totals := {}
	var items := {}
	
	for i in GameState.bag_size:
		var slot: Variant = GameState.inventory[i]
		if slot == null:
			continue
			
		var item: ItemData = slot["item"]
		if item.sell_price <= 0:
			continue
		items[item.item_id] = item
		totals[item.item_id] = totals.get(item.item_id, 0) + slot["count"]
	
	var earned := 0
	for id in totals:
		if GameState.remove_item(id, totals[id]):
			earned += items[id].sell_price * totals[id]
		
	if earned > 0:
		GameState.add_money(earned)
		Notify.say("Terjual +%d G" % earned)
	else:
		Notify.say("Tidak ada yang bisa dijual")
