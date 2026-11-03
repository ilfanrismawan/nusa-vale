extends Resource

## Pesona senjata dari Altar Enchant (Menara Penyihir). Menimpa grup "Efek status" WeaponTierFx
## senjata itu (visual tier tetap). Disimpan per pemain di PlayerData.enchants {item_id: id}.
## File: resources/witch/enchants/<id>.tres, dimuat lewat Enchanting.load_enchant().

@export var id := ""
@export var display_name := ""
@export_multiline var description := ""
@export var color := Color(1, 1, 1)
## Bahan (item_id -> jumlah) dan biaya gold sekali pasang.
@export var ingredients: Dictionary = {}
@export_range(0, 100000) var fee := 0
## Panjang urutan Urutan Mantra.
@export_range(3, 9) var sequence_length := 5

@export_group("Efek status")
@export var status: WeaponTierFx.Status = WeaponTierFx.Status.NONE
@export_range(0.0, 1.0, 0.05) var status_chance := 0.0
@export_range(0.0, 10.0, 0.1) var status_duration := 0.0
@export_range(0.0, 1.0, 0.01) var burn_tick_ratio := 0.1
@export_range(0.1, 2.0, 0.05) var burn_interval := 0.5
@export_range(0.1, 1.0, 0.05) var slow_scale := 1.0
@export_range(0.0, 1.0, 0.01) var lifesteal_ratio := 0.0
@export_range(0, 50) var stamina_gain := 0
@export_range(0.0, 1.0, 0.05) var defense_scale := 1.0


## Salinan fx tier dengan efek status pesona ini.
func apply_to(fx: WeaponTierFx) -> WeaponTierFx:
	var result: WeaponTierFx = fx.duplicate() if fx != null else WeaponTierFx.new()
	for field in ["status", "status_chance", "status_duration", "burn_tick_ratio", "burn_interval", "slow_scale", "lifesteal_ratio", "stamina_gain", "defense_scale"]:
		result.set(field, get(field))
	return result
