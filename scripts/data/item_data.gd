class_name ItemData
extends Resource

enum Category { ALL, SEED, CROP, TOOL, MATERIAL, FISH, FORAGE, EQUIPMENT, BUILDING }
@export_category("Placement")
@export var placeable: bool = false
@export var placement_size: Vector2i = Vector2i.ONE
@export_range(0, 60) var storage_slots: int = 0
@export var chest_tier: ToolData.ToolTier = ToolData.ToolTier.WOOD
## Hanya boleh ditambah di akhir (angkanya tersimpan di .tres). ARMOR = pelindung badan (chestplate).
enum EquipmentSlot { NONE, WEAPON, ARMOR, HELMET, LEGGINGS, BOOTS }
## Jenis senjata untuk combat nanti. ARROW = amunisi busur (tidak dipasang ke slot).
enum WeaponType { NONE, SWORD, BOW, STAFF, ARROW }

@export_category("Equipment")
@export var equipment_slot: EquipmentSlot = EquipmentSlot.NONE
@export_range(0, 999) var attack_bonus: int = 0
@export_range(0, 999) var defense_bonus: int = 0
@export var weapon_type: WeaponType = WeaponType.NONE
## Tier bahan, urutannya sama dengan alat (Wood -> Obsidian).
@export var equipment_tier: ToolData.ToolTier = ToolData.ToolTier.WOOD

enum Rarity {
	COMMON,
	UNCOMMON,
	RARE,
	EPIC,
	LEGENDARY
}

@export_category("Pickup")

@export var category: Category = Category.MATERIAL
@export var item_id: String = ""
@export var display_name: String = ""
@export var icon: Texture2D
@export var description: String = ""
@export var stackable: bool = true
@export var max_stack: int = 99

@export var action_data: ActionData

@export var season: String = "" # "spring", "summer", "fall", "winter"

@export var buy_price: int = 0  
@export var sell_price: int = 0   

@export var rarity: Rarity = Rarity.COMMON
@export var pickup_sound: AudioStream
@export var pickup_amount_text :=true
@export var magnet_radius := 48.0
@export var auto_pickup := false

func is_tool() -> bool:
	return action_data != null
