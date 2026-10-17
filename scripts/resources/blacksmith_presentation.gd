extends Resource

@export var vendor_name := "Empu Bima"
@export_multiline var greeting := "Bawa alat dan bahan kemari. Aku akan menempanya menjadi lebih kuat!"
@export var vendor_art: Texture2D
@export var tool_order: PackedStringArray = []
@export var tier_labels: Dictionary[String, String] = {}
@export var descriptions: Dictionary[String, String] = {}
@export var enough_material_color := Color("79816b")
@export var missing_material_color := Color("ce756b")
@export_range(1, 9) var tiers_per_page := 4
