extends Resource

@export var pet_id := ""
@export var display_name := ""
@export var icon: Texture2D
## Sheet animasi peliharaan di dunia (assets/farm_rpg/animals/Pets): sel 32x32, baris 0-2 jalan
## samping/bawah/atas, baris 4 duduk menghadap depan.
@export var sheet: Texture2D
@export_multiline var description := "Teman kecil untuk kehidupan barumu di farm."
