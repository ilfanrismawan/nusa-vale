extends Resource

@export var vendor_name := "Pak Damar"
@export_multiline var greeting := "Mau membangun sesuatu? Pilih bangunan, lalu tentukan lokasinya di ladang. Rumahmu juga bisa kuperbesar."
@export var vendor_art: Texture2D
@export var building_order := PackedStringArray(["chicken_coop", "barn", "silo"])
@export_multiline var ready_message := "Bahan lengkap. Ayo pilih lokasi!"
@export_multiline var missing_message := "Uang atau bahan bangunan belum lengkap."
@export_multiline var house_ready_message := "Bahan lengkap. Bayar sekarang, rumah selesai setelah beberapa hari."
@export var enough_color := Color(0.35, 0.48, 0.27)
@export var missing_color := Color(0.82, 0.32, 0.31)
