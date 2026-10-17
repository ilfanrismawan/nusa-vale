extends KitchenStation

@export_file("*.tres") var store_path := "res://resources/cooking/shop/cooking_shop.tres"
@export var required_flag := "home_kitchen_installed"

func interact(player: Player) -> void:
	if not WorldState.has_flag(required_flag):
		Notify.say("Beli kitchen set di toko peralatan masak setelah renovasi rumah.")
		return
	var store := load(store_path) as CookingShopData
	installed_equipment = store.installed_equipment() if store != null else []
	super.interact(player)
