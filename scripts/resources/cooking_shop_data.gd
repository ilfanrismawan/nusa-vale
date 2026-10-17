class_name CookingShopData
extends Resource

@export var display_name := "Dapur Nusantara"
@export var keeper_name := "Penjaga Toko"
@export_multiline var greeting := "Renovasi ruang dapur rumah dahulu, lalu pilih peralatan dan kitchen set."
@export var offers: Array[CookingShopOffer] = []

func installed_equipment() -> Array[CookingEquipmentData]:
	var result: Array[CookingEquipmentData] = []
	for offer in offers:
		if offer != null and offer.equipment != null and WorldState.has_flag(offer.owned_flag):
			result.append(offer.equipment)
	return result
