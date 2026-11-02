class_name AnimalSpeciesData
extends Resource
## Satu jenis ternak (GDD 4.10). File: resources/animals/<species_id>.tres, dimuat RanchHusbandry.
## Hanya definisi jenis; data tiap hewan (nama, kasih sayang, hari makan, hamil) tetap di save
## kandang. Ubah angka di Inspector untuk balancing; save tidak berubah karena hanya menyimpan id.

## Kunci yang disimpan di save ("cow", "chicken", ...). Jangan diganti setelah rilis.
@export var species_id := ""
@export var display_name := ""
## Urutan di toko ternak Eep dan daftar hewan (kecil dulu).
@export var sort_order := 0
## Harga beli di Eep (G).
@export_range(0, 100000, 50) var price := 1000
## Kandang tempat tinggal.
@export_enum("chicken_coop", "barn") var home := "barn"
## Hari terawat per hasil; 0 = tidak menghasilkan komoditas harian (kapibara, kuda).
@export_range(0, 14) var interval := 1
## item_id hasil; kosong bila interval 0.
@export var product := ""
## item_id alat pengambil hasil (milk_pail, shears). Kosong = diambil tangan (Barn) atau
## masuk stok kandang (Kandang Unggas).
@export var tool := ""
## Hasil bisa berukuran besar saat terawat dan kasih sayang tinggi.
@export var large_product := true
## Lama hamil dalam hari terawat (GDD 4.10.9). 0 = tidak bisa dibiakkan.
@export_range(0, 28) var breed_days := 0
## Telur (item_id) yang menetaskan jenis ini di Inkubator, dan lama inkubasinya (hari).
@export var hatch_egg := ""
@export_range(0, 28) var hatch_days := 0
## Teks untuk pemain (daftar hewan / toko).
@export_multiline var description := ""

## Bentuk lama RanchHusbandry.SPECIES[kind] yang dipakai kode kandang, toko, dan save.
func to_info() -> Dictionary:
	return {"name": display_name, "price": price, "interval": interval, "product": product, "tool": tool, "home": home, "large": large_product}
