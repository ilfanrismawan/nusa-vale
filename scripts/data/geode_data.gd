extends Resource

## Satu jenis geoda (GDD 9): dipecahkan Pandai Besi dengan biaya, isinya diundi dari tabel ini.
## File per jenis ada di resources/cave/geodes/<item_id>.tres. Tanpa class_name: pakai
## preload("res://scripts/data/geode_data.gd").

@export var item_id: String = "geode"
@export_range(0, 9999) var crack_price: int = 25
## Isi yang mungkin keluar (item_id).
@export var result_ids: PackedStringArray = []
## Bobot acak, sejajar dengan result_ids.
@export var result_weights: PackedFloat32Array = []
## Jumlah minimum dan maksimum tiap isi, sejajar dengan result_ids (kosong = 1).
@export var result_min: PackedInt32Array = []
@export var result_max: PackedInt32Array = []

## Undi isi geoda: {"item_id": String, "amount": int}.
func roll(rng: RandomNumberGenerator) -> Dictionary:
	if result_ids.is_empty():
		return {"item_id": "stone", "amount": 1}
	var total := 0.0
	for i in result_ids.size():
		total += _weight(i)
	var pick := rng.randf() * total
	var index := result_ids.size() - 1
	for i in result_ids.size():
		pick -= _weight(i)
		if pick <= 0.0:
			index = i
			break
	var low := result_min[index] if index < result_min.size() else 1
	var high := result_max[index] if index < result_max.size() else low
	return {"item_id": result_ids[index], "amount": rng.randi_range(maxi(low, 1), maxi(low, high))}

func _weight(index: int) -> float:
	return maxf(result_weights[index], 0.0) if index < result_weights.size() else 1.0

## Semua geoda di resources/cave/geodes, dimuat sekali.
static func all() -> Array:
	var list := []
	for id in ["geode", "frozen_geode", "magma_geode", "omni_geode"]:
		var data := find(id)
		if data != null:
			list.append(data)
	return list

static func find(id: String) -> Resource:
	var path := "res://resources/cave/geodes/%s.tres" % id
	return load(path) if ResourceLoader.exists(path) else null
