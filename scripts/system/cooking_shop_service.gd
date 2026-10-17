class_name CookingShopService
extends RefCounted

static func status(offer: CookingShopOffer, data: PlayerData) -> String:
	if offer == null or not offer.is_valid() or data == null:
		return "Data penawaran belum lengkap."
	for flag in offer.required_flags:
		if not WorldState.has_flag(flag):
			return offer.locked_message if not offer.locked_message.is_empty() else "Persyaratan progres belum terpenuhi."
	if WorldState.has_flag(offer.owned_flag):
		return "Pasang kitchen set" if not offer.selection_group.is_empty() else "Sudah dimiliki"
	if GameState.money < offer.price:
		return "Uang belum cukup."
	for item_id in offer.materials:
		if data.get_item_count(item_id) < offer.materials[item_id]:
			return "Bahan renovasi belum cukup."
	return ""

static func can_purchase(offer: CookingShopOffer, data: PlayerData) -> bool:
	if offer == null or not offer.is_valid() or data == null:
		return false
	for flag in offer.required_flags:
		if not WorldState.has_flag(flag):
			return false
	if WorldState.has_flag(offer.owned_flag):
		return not offer.selection_group.is_empty()
	if GameState.money < offer.price:
		return false
	for item_id in offer.materials:
		if data.get_item_count(item_id) < offer.materials[item_id]:
			return false
	return true

static func purchase(store: CookingShopData, offer: CookingShopOffer, data: PlayerData) -> Dictionary:
	if store == null or not store.offers.has(offer):
		return {"ok": false, "message": "Penawaran tidak tersedia di toko ini."}
	var reason := status(offer, data)
	var owned := offer != null and WorldState.has_flag(offer.owned_flag)
	if not can_purchase(offer, data):
		return {"ok": false, "message": reason}
	if not owned:
		for item_id in offer.materials:
			data.remove_item(item_id, offer.materials[item_id])
		GameState.spend_money(offer.price)
		WorldState.set_flag(offer.owned_flag)
		for flag in offer.grants_flags:
			WorldState.set_flag(flag)
	if not offer.selection_group.is_empty():
		for other in store.offers:
			if other != null and other.selection_group == offer.selection_group:
				WorldState.set_flag("active_" + str(other.id), other == offer)
	return {"ok": true, "message": offer.purchase_message if not offer.purchase_message.is_empty() else "%s sudah dipasang di rumah. Kepemilikan berlaku untuk seluruh rumah tangga." % offer.display_name}
