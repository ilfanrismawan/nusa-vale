extends VBoxContainer

@onready var icon: TextureRect = %EquipmentIcon
@onready var title: Label = %EquipmentName
@onready var status: Label = %EquipmentStatus

func setup(equipment: CookingEquipmentData, available: bool) -> void:
	icon.texture = equipment.display_icon()
	title.text = equipment.item.display_name if equipment.item != null else str(equipment.id)
	status.text = "Tersedia" if available else "Belum tersedia"
	tooltip_text = equipment.item.description if equipment.item != null else ""
