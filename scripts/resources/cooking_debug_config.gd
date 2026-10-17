class_name CookingDebugConfig
extends Resource

@export var enabled := true
@export var catalog: CookingCatalog
@export_range(1, 99) var default_batches := 3
@export_range(0, 100) var default_stamina_percent := 50
@export_range(0, 1000000) var gold_amount := 1000
