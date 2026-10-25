extends Resource

@export var title := "Ranch"
@export var vendor_name := "Rian"
@export_multiline var greeting := "Halo! Pilih teman baru untuk peternakanmu."
@export var vendor_art: Texture2D
@export var species_order: PackedStringArray = []
## Jenis yang tidak dijual di toko ini (mis. kuda hanya dijual Eep).
@export var excluded_species: PackedStringArray = []
@export var descriptions: Dictionary[String, String] = {}
@export var home_labels: Dictionary[String, String] = {}
@export var icon_overrides: Dictionary[String, Texture2D] = {}
@export var variants: Dictionary[String, PackedStringArray] = {}
@export var variant_labels: Dictionary[String, String] = {}
@export var variant_colors: Dictionary[String, Color] = {}
@export_range(0, 40) var display_slots := 16
