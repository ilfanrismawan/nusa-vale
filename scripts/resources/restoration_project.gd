class_name RestorationProject
extends Resource

## Item IDs refer to existing ItemData; no inventory resources are copied into saves.
@export var project_id: String = ""
@export var display_name: String = ""
@export var ui_icon: Texture2D
@export var ui_short_name: String = ""
@export_multiline var description: String = ""
@export var requirements: Dictionary[String, int] = {}
@export var wing_id: String = ""
@export var unlock_id: String = ""
@export var completion_flag: String = ""
@export_multiline var completion_message: String = "Proyek pemulihan selesai."
## Hadiah barang untuk pemain yang menyelesaikan bundel (item_id -> jumlah). Kosong = tanpa hadiah barang.
@export var reward_items: Dictionary[String, int] = {}
