class_name HorrorWard
extends Node2D

## Asap Kemenyan (GDD 4.1, Progres Horor Tahap 3): zona aman portabel yang mengikuti pemain.
## Di dalam radiusnya rasa takut turun seperti di dekat cahaya, dan makhluk malam yang masuk
## (termasuk Banaspati dan Genderuwo) mundur. Bukan cahaya: Banaspati tidak tertarik ke asap ini.
## Angka (lama, radius) dari ItemData.horror_ward_seconds / horror_ward_radius.

const GROUP := &"horror_incense"
const NODE_NAME := &"HorrorWard"

var radius := 80.0
var remaining := 60.0
var _puffs: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


## Bakar kemenyan dari slot tas. Membakar lagi saat masih menyala = memperpanjang ke lama penuh.
static func ignite(player: Player, slot: int) -> bool:
	var data := player.data
	if slot < 0 or slot >= data.bag_size or data.inventory[slot] == null:
		return false
	var item: ItemData = data.inventory[slot].item
	if item == null or item.horror_ward_seconds <= 0.0:
		return false
	var ward := player.get_node_or_null(NodePath(NODE_NAME)) as HorrorWard
	if ward != null and ward.remaining > item.horror_ward_seconds * 0.5:
		Notify.say("Kemenyan masih mengepul.")
		return false
	data.remove_item_at(slot, 1)
	if ward == null:
		ward = HorrorWard.new()
		ward.name = NODE_NAME
		player.add_child(ward)
	ward.radius = item.horror_ward_radius
	ward.remaining = item.horror_ward_seconds
	Notify.say("%s dibakar. Asapnya melindungimu %d detik." % [item.display_name, roundi(item.horror_ward_seconds)])
	return true


func _ready() -> void:
	add_to_group(GROUP)
	_rng.randomize()
	z_index = 40
	position = Player.FEET_OFFSET


func _process(delta: float) -> void:
	remaining -= delta
	if remaining <= 0.0:
		queue_free()
		return
	if _rng.randf() < delta * 6.0:
		_puffs.append({"pos": Vector2(_rng.randf_range(-6, 6), -4), "life": 1.6, "drift": _rng.randf_range(-6, 6)})
	for p in _puffs:
		p.life -= delta
		p.pos += Vector2(p.drift, -14.0) * delta
	_puffs.assign(_puffs.filter(func(p: Dictionary) -> bool: return p.life > 0.0))
	queue_redraw()


func covers(world_pos: Vector2) -> bool:
	return remaining > 0.0 and global_position.distance_to(world_pos) <= radius


func _draw() -> void:
	# Lingkar asap tipis di tanah + kepulan naik. Warna di atas 1 agar tetap terlihat di malam hari.
	var fade := clampf(remaining / 3.0, 0.0, 1.0)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(1.6, 1.5, 1.4, 0.10 * fade), 2.0)
	for p in _puffs:
		var a: float = clampf(float(p.life) / 1.6, 0.0, 1.0) * 0.35 * fade
		draw_circle(p.pos, 2.0 + (1.6 - float(p.life)) * 2.5, Color(1.5, 1.45, 1.4, a))
