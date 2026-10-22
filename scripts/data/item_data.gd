class_name ItemData
extends Resource

enum Category { ALL, SEED, CROP, TOOL, MATERIAL, FISH, FORAGE, EQUIPMENT, BUILDING, FOOD }
@export_category("Food")
@export_range(0, 200) var stamina_restore: int = 0
@export_range(0, 120) var speed_buff_seconds: float = 0.0
@export_range(1.0, 3.0, 0.01) var speed_buff_multiplier: float = 1.15
@export var food_effects: Array[FoodEffectData] = []
## HP yang pulih saat dimakan. -1 = setengah dari stamina_restore (GDD 8.1: makanan bergizi memulihkan HP).
@export_range(-1, 200) var hp_restore: int = -1
@export_category("Placement")
@export var placeable: bool = false
## Assign a seat preset to make this item placeable, rotatable seating.
@export var seat_definition: SeatDefinition
@export var placement_size: Vector2i = Vector2i.ONE
@export_range(0, 240) var storage_slots: int = 0
@export var chest_tier: ToolData.ToolTier = ToolData.ToolTier.WOOD
@export_group("Chest Visuals")
## Independent textures (including AtlasTexture regions) for this tier only.
@export var chest_closed_texture: Texture2D
@export var chest_open_texture: Texture2D
## Distance from player feet to the chest center, in world pixels.
@export_range(0, 256, 1) var chest_open_distance: float = 34.0
@export_group("")
## Hanya boleh ditambah di akhir (angkanya tersimpan di .tres). ARMOR = pelindung badan (chestplate).
enum EquipmentSlot { NONE, WEAPON, ARMOR, HELMET, LEGGINGS, BOOTS, NECKLACE, RING, ACCESSORY }
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

enum Quality {
	NORMAL,
	SILVER,
	GOLD
}

@export_category("Pickup")

@export var category: Category = Category.MATERIAL
@export var quality: Quality = Quality.NORMAL
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

@export_category("Gathering")
## Toko hanya menjual barang ini bila tas sudah berisi item ini (mis. jaring tier sebelumnya).
## Saat dibeli, item itu ditukar dengan barang baru di slot yang sama (GDD 7).
@export var requires_item_id: String = ""
## Lebih dari 0 = bisa dipakai sebagai umpan pancing: waktu tunggu gigitan berkurang sebanyak ini
## (0.25 = 25% lebih cepat). Umpan termurah di tas dipakai otomatis saat kail jatuh di air.
@export_range(0.0, 0.8, 0.05) var bait_bonus: float = 0.0

@export_category("Skill")
## Buku riset (GDD 13.1): role_id yang mendapat EXP saat buku dibaca (kosong = bukan buku).
@export var skill_book_role: String = ""
@export_range(0, 5000) var skill_book_exp: int = 0

func is_tool() -> bool:
	return action_data != null

func hp_restore_amount() -> int:
	@warning_ignore("integer_division")
	return hp_restore if hp_restore >= 0 else stamina_restore / 2

func food_summary() -> String:
	var parts: PackedStringArray = ["%+d stamina" % stamina_restore]
	if hp_restore_amount() > 0:
		parts.append("%+d HP" % hp_restore_amount())
	for effect in food_effects:
		if effect != null and effect.is_valid_effect():
			parts.append(effect.summary())
	if food_effects.is_empty() and speed_buff_seconds > 0.0:
		parts.append("gerak %+.0f%% · %s dtk" % [(speed_buff_multiplier - 1.0) * 100.0, str(speed_buff_seconds)])
	return " • ".join(parts)
