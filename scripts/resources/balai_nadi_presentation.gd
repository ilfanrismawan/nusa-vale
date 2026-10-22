extends Resource

@export var wing_order := PackedStringArray(["all", "", "alam", "karya", "niaga", "pengetahuan"])
@export var wing_labels: Dictionary[String, String] = {"all": "Semua Paket", "": "Balai Utama", "alam": "Sayap Alam", "karya": "Sayap Karya", "niaga": "Sayap Niaga", "pengetahuan": "Sayap Pengetahuan"}
@export var default_icon: Texture2D = preload("res://resources/balai_nadi/v3/icon_bale.tres")
@export var money_icon: Texture2D = preload("res://resources/ui/balai_money_icon.tres")
@export_multiline var empty_message := "Belum ada paket kontribusi yang tersedia di sayap ini."
@export var complete_label := "PAKET LENGKAP"
@export var ready_label := "SIAP DISELESAIKAN"
