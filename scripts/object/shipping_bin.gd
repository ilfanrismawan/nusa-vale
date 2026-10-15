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
## Frame di "shipping box.png" (16x20, tutup terbuka menjulang 3 px di atas kotak).
const REGION_CLOSED := Rect2(0, 12, 16, 20)
const REGION_OPEN := Rect2(0, 44, 16, 20)
## Menjaga dasar kotak tetap di posisi lama (region asli 16x16).
const SPRITE_OFFSET := Vector2(0, -2)
## Jangan bunyi saat area baru dimuat dengan pemain sudah berdiri di dekat kotak.
const QUIET_AFTER_READY_MS := 400

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")

var player_in_range: bool:
	get: return not _players.is_empty()
var _players: Array[Player] = []
var _prompt: Label
var is_open := false
var _quiet_until_ms := 0
var _lid_tween: Tween

func _ready() -> void:
	add_to_group("shipping_bin")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_quiet_until_ms = Time.get_ticks_msec() + QUIET_AFTER_READY_MS
	if sprite != null:
		sprite.region_enabled = true
		sprite.offset = SPRITE_OFFSET
		sprite.region_rect = REGION_CLOSED
	_build_prompt()

func _on_body_entered(body: Node2D) -> void:
	if body is Player and not _players.has(body):
		_players.append(body)
	_update_lid()

func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		_players.erase(body)
	_update_lid()

## Tutup terbuka selama ada pemain di dekat kotak, tertutup lagi saat semua menjauh.
func _update_lid() -> void:
	# body_exited juga dikirim saat scene dibuang; jangan mulai suara/tween baru.
	var ancestor: Node = self
	while ancestor != null:
		if ancestor.is_queued_for_deletion():
			return
		ancestor = ancestor.get_parent()
	for i in range(_players.size() - 1, -1, -1):
		if not is_instance_valid(_players[i]):
			_players.remove_at(i)
	var want_open := not _players.is_empty()
	if want_open == is_open:
		return
	is_open = want_open
	if sprite == null:
		return
	sprite.region_rect = REGION_OPEN if is_open else REGION_CLOSED
	if Time.get_ticks_msec() >= _quiet_until_ms:
		Juice.play_sound(&"bin_open" if is_open else &"bin_close")
	# Sedikit "pantulan" agar tutupnya terasa bergerak.
	if _lid_tween != null and _lid_tween.is_valid():
		_lid_tween.kill()
	sprite.scale = Vector2(0.9, 1.12) if is_open else Vector2(1.12, 0.88)
	_lid_tween = create_tween()
	_lid_tween.tween_property(sprite, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

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

func deposit_selected(player: Player) -> bool:
	if not _players.has(player) or not is_facing(player) or player.is_input_locked():
		return false
	var slot_index: int = player.data.hotbar_page * 8 + player.tool_controller.current_index
	var slot: Variant = player.data.inventory[slot_index]
	if slot == null:
		return false
	var item: ItemData = slot.item
	if item.sell_price <= 0 or item.is_tool():
		return false
	# Consume the exact selected stack, preserving other stacks and co-op ownership.
	slot.count -= 1
	if slot.count <= 0:
		player.data.inventory[slot_index] = null
	GameState.shipping.deposit(item, 1)
	GameState.inventory_changed.emit()
	player.play_item_gesture(false)
	Juice.play_sound(&"bin_close")
	if item.icon != null:
		var flying := Sprite2D.new()
		flying.texture = item.icon
		flying.scale = Vector2.ONE * 0.65
		flying.z_index = 30
		add_child(flying)
		flying.global_position = player.global_position + Vector2(0, -16)
		var tween := create_tween()
		tween.tween_property(flying, "global_position", global_position + Vector2(0, -12), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(flying, "scale", Vector2.ZERO, 0.12)
		tween.tween_callback(flying.queue_free)
	if sprite != null:
		if _lid_tween != null and _lid_tween.is_valid():
			_lid_tween.kill()
		sprite.scale = Vector2(1.15, 0.85)
		_lid_tween = create_tween()
		_lid_tween.tween_property(sprite, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return true

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
	_prompt.position = Vector2(-24, -28)
	_prompt.hide()
	add_child(_prompt)

func _update_prompt() -> void:
	var player := _ready_player()
	var show_prompt := player != null

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
		if item.sell_price <= 0 or item.is_tool():
			continue
		items[item.item_id] = item
		totals[item.item_id] = totals.get(item.item_id, 0) + slot["count"]
	
	var earned := 0
	for id in totals:
		if GameState.remove_item(id, totals[id]):
			GameState.shipping.deposit(items[id], totals[id])
			earned += items[id].sell_price * totals[id]
		
	if earned > 0:
		Notify.say("Dititipkan senilai %d G. Dibayar setelah tidur." % earned)
	else:
		Notify.say("Tidak ada yang bisa dijual")
