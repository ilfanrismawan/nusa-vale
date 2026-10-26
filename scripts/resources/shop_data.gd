class_name ShopData
extends Resource

## Data satu toko: identitas penjaga + daftar barang yang dijual.
## Harga selalu diambil dari ItemData.buy_price / sell_price.

@export var shop_id: String = ""
@export var shop_name: String = "Toko"
@export var keeper_name: String = "Penjaga Toko"
## Kosongkan untuk memakai siluet sementara.
@export var portrait: Texture2D
@export_multiline var greeting: String = "Selamat datang!"

## Barang yang dijual (urutan = urutan tampil). Item dengan buy_price <= 0 disembunyikan.
@export var stock: Array[ItemData] = []

## Jika true, pemain bisa menjual barang dari tas langsung di toko (harga sell_price).
@export var buys_items: bool = true

@export_group("Katalog perk")
## Katalog tambahan yang ikut tampil bila pemain punya stat perk-nya (perk Merchant).
## Bertipe Resource (isinya ShopData): tipe diri sendiri membuat referensi script melingkar.
@export var perk_catalogs: Array[Resource] = []
## Dipakai saat toko ini menjadi katalog perk: stat SkillSystem yang harus > 0.
@export var perk_stat: StringName = &""
## Katalog perk yang hanya buka akhir pekan (hari ke-6 dan ke-7 tiap pekan).
@export var weekend_only: bool = false

static func is_weekend(day: int) -> bool:
	return (day - 1) % 7 >= 5
