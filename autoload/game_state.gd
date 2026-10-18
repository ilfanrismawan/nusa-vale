extends Node

## State permainan. Uang, pohon/batu yang sudah habis, dan titik spawn bersama;
## tas, stamina, halaman hotbar, dan penampilan ada di PlayerData per pemain (co-op lokal).
## Properti/fungsi per pemain di sini (inventory, stamina, add_item, ...) meneruskan ke
## `current`, yaitu pemain yang sedang beraksi. Solo: selalu P1.

## stamina_changed dan appearance_changed hanya untuk P1 (kompatibel dengan kode lama);
## UI per pemain memakai signal milik PlayerData-nya.
signal stamina_changed(current: int, maximum: int)
## Dipancarkan saat tas pemain mana pun berubah. UI menyegarkan diri dengan data pemainnya.
signal inventory_changed
signal money_changed(new_amount: int)
signal bag_upgraded(new_size: int)
signal appearance_changed(appearance: CharacterAppearance)

const MAX_STAMINA: int = PlayerData.MAX_STAMINA
## Ukuran maksimal absolut array inventory (tidak pernah berubah)
const INVENTORY_SIZE := PlayerData.INVENTORY_SIZE
## Level tas: 0=Tas Kecil(12), 1=Ransel(24), 2=Ransel Besar(36)
const BAG_SIZES := PlayerData.BAG_SIZES
const MAX_PLAYERS := 4

var money: int = 100
var farm_name: String = ""
var chopped_trees: Array[String] = []
var mined_rocks: Array[String] = []
## Persistent community projects share the lifetime of GameState, without another autoload.
var balai_nadi: BalaiNadiManager
var shipping: ShippingManager
var daya: DayaManager
var weather: DailyWeather
## Progres Gua Tambang (lift checkpoint), GDD 9.
var cave: CaveManager
## Tingkat rumah + pesanan upgrade di Wira (GDD 4.12, save v17).
var house: HouseManager

## Index 0 = P1. Pemain lain dibuat saat bergabung di co-op dan ikut tersimpan di save.
var players: Array[PlayerData] = [PlayerData.new(0)]
## Pemain yang sedang beraksi. Diisi Player sebelum memproses input/aksi (use_player()).
var current: PlayerData = players[0]

var stamina: int:
	get: return current.stamina
	set(value): current.stamina = value

var bag_level: int:
	get: return current.bag_level
	set(value): current.bag_level = value

## Jumlah slot yang aktif/terlihat saat ini
var bag_size: int:
	get: return current.bag_size

var inventory: Array:
	get: return current.inventory
	set(value): current.inventory = value

var hotbar_page: int:
	get: return current.hotbar_page
	set(value): current.hotbar_page = value

## Penampilan karakter pemain (lihat CharacterCreatorUI). Default = Josh.
var appearance: CharacterAppearance:
	get: return current.appearance
	set(value): current.appearance = value

var next_spawn_position: Vector2 = Vector2.ZERO
var has_spawn_point: bool = false

const SHOP_PRICES := {
	"seed_strawberry": 15,
	"seed_carrot": 25,
}

func _ready() -> void:
	weather = DailyWeather.new()
	weather.name = "Weather"
	add_child(weather)
	shipping = ShippingManager.new()
	shipping.name = "Shipping"
	add_child(shipping)
	balai_nadi = BalaiNadiManager.new()
	balai_nadi.name = "BalaiNadi"
	add_child(balai_nadi)
	daya = DayaManager.new()
	add_child(daya)
	cave = CaveManager.new()
	cave.name = "Cave"
	add_child(cave)
	house = HouseManager.new()
	house.name = "House"
	add_child(house)
	players[0].stamina_changed.connect(func(value: int, maximum: int): stamina_changed.emit(value, maximum))
	players[0].appearance_changed.connect(func(look: CharacterAppearance): appearance_changed.emit(look))


# ── Pemain ──────────────────────────────────────────────────────────

func get_player(index: int) -> PlayerData:
	return ensure_player(index)

## Buat data pemain ke-index bila belum ada (pemain baru mendapat alat awal).
func ensure_player(index: int) -> PlayerData:
	index = clampi(index, 0, MAX_PLAYERS - 1)
	while players.size() <= index:
		var data := PlayerData.new(players.size())
		data.reset_to_starter()
		players.append(data)
	return players[index]

## Jadikan pemain ini `current` supaya GameState.add_item/stamina/... mengenai tasnya.
func use_player(player_or_data: Variant) -> void:
	if player_or_data is PlayerData:
		current = player_or_data
	elif player_or_data is Player:
		current = player_or_data.data

func p1() -> PlayerData:
	return players[0]


# ── Game baru ───────────────────────────────────────────────────────

func new_game() -> void:
	WorldState.reset()
	daya.reset()
	weather.reset()
	shipping.reset()
	balai_nadi.reset()
	cave.reset()
	house.reset()
	StructureManager.reset()
	money = 100
	farm_name = ""
	players[0].player_name = ""
	players[0].birthday_season = ""
	players[0].birthday_day = 0
	players[0].pet_id = ""
	players[0].pet_name = ""
	chopped_trees.clear()
	mined_rocks.clear()
	has_spawn_point = false
	next_spawn_position = Vector2.ZERO
	players.resize(1)
	current = players[0]
	set_appearance(CharacterAppearance.new())
	players[0].reset_to_starter()

	money_changed.emit(money)
	inventory_changed.emit()
	print("[GameState] new_game: state direset ke default.")

func reset_game_state() -> void:
	current.reset_to_starter()

func set_appearance(new_appearance: CharacterAppearance) -> void:
	current.set_appearance(new_appearance)


# ── Diteruskan ke pemain yang sedang beraksi ────────────────────────

func spend_stamina(amount: int) -> bool:
	return current.spend_stamina(amount)

func restore_stamina(amount: int = -1) -> void:
	current.restore_stamina(amount)

func _setup_tools() -> void:
	current.setup_tools()

func ensure_starter_tools() -> void:
	current.ensure_starter_tools()

func swap_slots(from_slot: int, to_slot: int) -> bool:
	return current.swap_slots(from_slot, to_slot)

func _add_item_silent(item_or_id: Variant, amount: int = 1) -> void:
	current.add_item_silent(item_or_id, amount)

func get_hotbar_item(slot: int) -> ItemData:
	return current.get_hotbar_item(slot)

## Helper untuk hotbar: kembalikan jumlah item di slot tertentu, atau 0
func get_hotbar_count(slot: int) -> int:
	return current.get_hotbar_count(slot)

func buy_item(item_id: String, amount: int = 1) -> bool:
	return current.buy_item(item_id, amount)

## Tambah item ke slot inventory (mendukung ItemData atau String item_id)
func add_item(item_or_id: Variant, amount: int = 1) -> int:
	return current.add_item(item_or_id, amount)

## Hapus item di slot tertentu
func remove_item_at(slot: int, amount: int = 1) -> bool:
	return current.remove_item_at(slot, amount)

## Hapus item berdasarkan item_id
func remove_item(item_id: String, amount: int = 1) -> bool:
	return current.remove_item(item_id, amount)

func replace_tool(old_tool_id: String, new_tool_id: String) -> bool:
	return current.replace_tool(old_tool_id, new_tool_id)

## Cek apakah ada item sebanyak jumlah tertentu
func has_item(item_id: String, amount: int = 1) -> bool:
	return current.has_item(item_id, amount)

## Hitung total item berdasarkan item_id
func get_item_count(item_id: String) -> int:
	return current.get_item_count(item_id)

func _find_empty_slot() -> int:
	return current.find_empty_slot()

## Upgrade tas ke level berikutnya
func upgrade_bag() -> bool:
	return current.upgrade_bag()

## Menggeser view hotbar ke halaman selanjutnya (tanpa mengacak isi array tas)
func cycle_hotbar() -> void:
	current.cycle_hotbar()

## Gabungkan tumpukan dan sortir item — slot kosong ke belakang, dalam bag_size aktif
func sort_inventory() -> void:
	current.sort_inventory()


# ── Bersama ─────────────────────────────────────────────────────────

func _resolve_item(item_or_id: Variant) -> ItemData:
	if item_or_id is ItemData:
		return item_or_id

	if not item_or_id is String:
		return null

	var item_id: String = item_or_id

	if item_id.is_empty():
		return null

	var path: String = "res://resources/item_data/%s.tres" % item_or_id

	if not ResourceLoader.exists(path):
		push_error("ItemData tidak ditemukan: %s" % path)
		return null

	var resource: Resource = load(path)

	if resource == null:
		push_error("Gagal load ItemData: %s" % path )
		return null

	if not resource is ItemData:
		push_error("Resource bukan ItemData: %s" % path)
		return null

	return resource as ItemData

func add_money(amount: int) -> void:
	money += amount
	money_changed.emit(money)

func spend_money(amount: int) -> bool:
	if amount < 0:
		return false
	if money >= amount:
		money -= amount
		money_changed.emit(money)
		return true
	return false
