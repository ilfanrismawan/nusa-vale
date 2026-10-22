class_name EquipmentContext
extends RefCounted

## Equipment context (GDD 4.3): barang yang dipegang di hotbar menentukan arti tombol.
## Alat/benih/makanan/tangan kosong = Lapangan (tata letak Stardew Valley); pedang = combat
## jarak dekat (klik kanan/LB tangkis, LT weapon art); busur dan tongkat = combat jarak jauh
## (klik kanan/LT bidik). Satu tempat untuk keputusan ini, dipakai PlayerInput dan prompt tombol.

enum Kind { EMPTY, TOOL, SEED, FOOD, PLACEABLE, ITEM, MELEE, RANGED }

static func kind_of(item: ItemData) -> Kind:
	if item == null:
		return Kind.EMPTY
	var style := Combat.style_for(item)
	if style != null:
		return Kind.RANGED if style.melee_radius <= 0.0 else Kind.MELEE
	if is_seed(item):
		return Kind.SEED
	if item.is_tool():
		return Kind.TOOL
	if item.category == ItemData.Category.FOOD:
		return Kind.FOOD
	if item.placeable:
		return Kind.PLACEABLE
	return Kind.ITEM

## Konteks input (bit InputLayout) untuk barang yang dipegang.
static func input_context(item: ItemData) -> int:
	match kind_of(item):
		Kind.MELEE:
			return InputLayout.MELEE
		Kind.RANGED:
			return InputLayout.RANGED
	return InputLayout.FIELD

## Benih tanaman (SeedEffect): bisa ditebar sambil melompat, seperti Grand Bazaar.
static func is_seed(item: ItemData) -> bool:
	return item != null and item.action_data != null and item.action_data.effect is SeedEffect
