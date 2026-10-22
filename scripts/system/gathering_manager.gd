extends Node
## GameState.gathering: tapper yang terpasang di pohon (GDD 7, fase 4A-3). Save v18 key "gathering".
## Pohon dikenali dari scene area + posisi akarnya ("forest@512,300"), jadi pohon scene, pohon liar
## dari TreeSpawner, dan pohon yang ditanam pemain (PlantedTreeSpawner) memakai aturan yang sama.

signal tapper_changed(key: String)

const TAPPER_ITEM := "tapper"
const TAPPER_NODE := preload("res://scripts/world/tapper_node.gd")
## Jenis pohon -> [hasil, hari sampai siap]. Pohon ek belum ada di game, jadi resin dari birch dan mahoni.
const PRODUCTS := {
	"maple": ["maple_syrup", 4],
	"pine": ["pine_tar", 3],
	"birch": ["resin", 3],
	"mahogany": ["resin", 2],
}
## Biji yang kadang jatuh saat pohon besar ditebang, untuk ditanam di farm.
const SEEDS := {
	"maple": "maple_seed",
	"pine": "pine_cone",
	"birch": "birch_seed",
	"mahogany": "mahogany_seed",
}
const SEED_CHANCE := 0.3

## key -> {"kind": String, "day": int (hari tapper dipasang / terakhir dipanen)}
var tappers: Dictionary = {}


func reset() -> void:
	tappers.clear()


## "maple" dari res://scenes/objects/maple_tree.tscn. Pohon kecil (small_*) dan objek lain = "".
static func tree_kind(tree: Node) -> String:
	var base := tree.scene_file_path.get_file().get_basename()
	if base.begins_with("small_") or not base.ends_with("_tree"):
		return ""
	return base.trim_suffix("_tree")


static func tree_key(tree: Node2D) -> String:
	var area := ""
	var node: Node = tree.get_parent()
	while node != null:
		if node.scene_file_path.begins_with("res://scenes/world/"):
			area = node.scene_file_path.get_file().get_basename().to_lower()
			break
		node = node.get_parent()
	return "%s@%d,%d" % [area, roundi(tree.global_position.x), roundi(tree.global_position.y)]


func has_tapper(key: String) -> bool:
	return tappers.has(key)


func kind_of(key: String) -> String:
	return str(tappers.get(key, {}).get("kind", ""))


func product_id(key: String) -> String:
	var info: Array = PRODUCTS.get(kind_of(key), [])
	return str(info[0]) if not info.is_empty() else ""


func days_left(key: String) -> int:
	var info: Array = PRODUCTS.get(kind_of(key), [])
	if info.is_empty():
		return 0
	return maxi(0, int(tappers[key].day) + int(info[1]) - DayCycle.current_day)


func is_ready(key: String) -> bool:
	return tappers.has(key) and days_left(key) == 0


## Pasang satu tapper dari tas `donor` di pohon besar. false + pesan bila tidak bisa.
func place(tree: Node2D, donor: PlayerData) -> bool:
	var kind := tree_kind(tree)
	if not PRODUCTS.has(kind):
		Notify.say("Tapper hanya bisa dipasang di pohon besar: maple, pinus, birch, atau mahoni.")
		return false
	var key := tree_key(tree)
	if tappers.has(key):
		Notify.say("Pohon ini sudah punya tapper.")
		return false
	if donor == null or not donor.remove_item(TAPPER_ITEM, 1):
		return false
	tappers[key] = {"kind": kind, "day": DayCycle.current_day}
	attach_visual(tree)
	tapper_changed.emit(key)
	var product := GameState._resolve_item(product_id(key))
	Notify.say("Tapper terpasang. %s siap dalam %d hari." % [product.display_name if product else "Hasil", days_left(key)])
	return true


## Ambil hasil tapper yang sudah siap; tapper langsung mulai mengisi lagi.
func collect(key: String, donor: PlayerData) -> bool:
	if not tappers.has(key) or donor == null:
		return false
	var product := GameState._resolve_item(product_id(key))
	if product == null:
		return false
	if not is_ready(key):
		Notify.say("%s belum siap. Tunggu %d hari lagi." % [product.display_name, days_left(key)])
		return false
	if donor.add_item(product, 1) > 0:
		Notify.say("Tas penuh!")
		return false
	tappers[key].day = DayCycle.current_day
	Notify.say("+1 %s" % product.display_name)
	tapper_changed.emit(key)
	return true


## Dipanggil Choppable setelah pohon masuk scene (deferred, setelah posisinya diatur spawner).
func on_tree_ready(tree: Node2D) -> void:
	if is_instance_valid(tree) and tree.is_inside_tree() and tappers.has(tree_key(tree)):
		attach_visual(tree)


## Pohon bertapper ditebang: tapper (dan hasil yang sudah siap) jatuh ke tanah.
func on_tree_destroyed(tree: Node2D) -> void:
	var key := tree_key(tree)
	if not tappers.has(key):
		return
	var parent := tree.get_parent()
	var at := tree.global_position + Vector2(0, 6)
	if is_ready(key):
		ItemPickup.spawn(parent, at + Vector2(6, 0), product_id(key), 1)
	tappers.erase(key)
	ItemPickup.spawn(parent, at, TAPPER_ITEM, 1)
	tapper_changed.emit(key)


func attach_visual(tree: Node2D) -> void:
	if tree.get_node_or_null(^"Tapper") != null:
		return
	var node: Area2D = TAPPER_NODE.new()
	node.name = "Tapper"
	node.key = tree_key(tree)
	tree.add_child(node)


## Biji pohon yang jatuh saat pohon besar ini ditebang ("" = tidak ada / gagal undian).
func roll_seed_drop(tree: Node) -> String:
	var kind := tree_kind(tree)
	if not SEEDS.has(kind) or randf() >= SEED_CHANCE:
		return ""
	return SEEDS[kind]


# ── Save ─────────────────────────────────────────────────────────────

func to_save() -> Dictionary:
	return {"tappers": tappers.duplicate(true)}


static func valid_save(data: Variant) -> bool:
	if not data is Dictionary:
		return false
	var entries: Variant = data.get("tappers", {})
	if not entries is Dictionary:
		return false
	for key in entries:
		var entry: Variant = entries[key]
		if not entry is Dictionary or not entry.get("kind", null) is String:
			return false
		var day: Variant = entry.get("day", null)
		if not (day is int or day is float) or not is_finite(float(day)):
			return false
	return true


## Save lama (tanpa key "gathering") = belum ada tapper.
func load_save(data: Variant) -> void:
	reset()
	if not valid_save(data):
		return
	for key in data.get("tappers", {}):
		var entry: Dictionary = data.tappers[key]
		if PRODUCTS.has(str(entry.kind)):
			tappers[str(key)] = {"kind": str(entry.kind), "day": int(entry.day)}
