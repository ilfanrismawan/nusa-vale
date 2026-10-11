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
