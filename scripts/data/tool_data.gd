class_name ToolData
extends Resource

enum ToolType {
	AXE,
	HOE,
	PICKAXE,
	SHOVEL,
	WATERING_CAN,
	SICKLE,
	FISHING_ROD,
	## Jaring serangga (GDD 7). Hanya boleh menambah di akhir: angkanya tersimpan di .tres.
	BUG_NET
}

enum ToolTier {
	WOOD,
	COPPER,
	IRON,
	GOLD,
	PLATINUM,
	CRIMSON,
	FROST,
	SHADOW,
	FAIRY,
	OBSIDIAN
}

@export_category("Identity")
@export var tool_id: String = ""
@export var display_name: String = ""

@export var tool_type: ToolType
@export var tier: ToolTier = ToolTier.WOOD

## Jangkauan ayunan jaring serangga per tier (px dari titik ayun), Kayu..Emas.
const BUG_NET_REACH: Array[float] = [20.0, 28.0, 36.0, 48.0]

@export_category("Stats")
@export var damage: int = 1
@export var stamina_cost: int = 6
@export var action_speed: float = 1.0
@export var area_size: int = 1
@export var reach_tiles: float = 1.5
@export var area_width: int = 1
@export var area_depth: int = 1
@export var water_capacity: int = 0
@export_range(0.0, 1.0) var dig_bonus_chance: float = 0.0

## Persegi panjang di depan pemain, dimulai dari sel yang dibidik.
func get_cells(origin: Vector2i, facing: Vector2) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var forward := Vector2i(facing)
	if forward == Vector2i.ZERO:
		forward = Vector2i.DOWN
	var side := Vector2i(forward.y, -forward.x)
	for depth in maxi(area_depth, 1):
		for width in maxi(area_width, 1):
			result.append(origin + forward * depth + side * (width - int(area_width / 2)))
	return result

func ability_text() -> String:
	var text := "Jarak %.1f petak | Area %dx%d\nStamina %d/aksi | Kecepatan %.2fx" % [reach_tiles, area_width, area_depth, stamina_cost, action_speed]
	match tool_type:
		ToolType.AXE, ToolType.PICKAXE:
			text += "\nKekuatan %d: lebih sedikit pukulan." % damage
			text += "\nObjek: " + ("kecil" if tier == ToolTier.WOOD else "kecil/normal" if tier == ToolTier.COPPER else "kecil/normal/besar")
		ToolType.HOE:
			text += "\nCangkul hingga %d petak sekaligus." % area_size
		ToolType.WATERING_CAN:
			text += "\nKapasitas %d air; 1 air/petak.\nIsi ulang di sungai/kolam: %d stamina." % [water_capacity, maxi(stamina_cost, 1)]
		ToolType.SHOVEL:
			text += "\nGali hingga %d petak; peluang +1 hasil %d%%." % [area_size, roundi(dig_bonus_chance * 100)]
		ToolType.SICKLE:
			text += "\nPanen massal; tebas rumput radius %d px.\nKekuatan %d." % [12 + 4 * int(tier), damage]
		ToolType.BUG_NET:
			text = "Jangkauan ayun %d px | Stamina %d/ayun\nKecepatan %.2fx" % [int(BUG_NET_REACH[mini(int(tier), BUG_NET_REACH.size() - 1)]), stamina_cost, action_speed]
	return text

@export_category("Upgrade")
@export var upgrade_cost_money: int = 0
@export var required_items: Dictionary = {}

func can_upgrade() -> bool:
	return tier != ToolTier.OBSIDIAN
