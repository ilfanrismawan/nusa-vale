class_name CombatRules
extends Resource

## Aturan combat soulslike (GDD 8.2-A): stamina tempur, Exhausted, dodge roll, block/parry,
## poise, dan serangan berat. File: resources/combat/combat_rules.tres (Combat.RULES).
## Angka per senjata ada di WeaponStyle; angka per musuh di EnemyData.
## Keputusan 2026-10-17: combat memakai bar stamina tempur terpisah yang cepat pulih;
## stamina harian (kerja kebun) dan aturan pingsan saat stamina harian 0 tidak berubah.

@export_group("Stamina tempur")
@export_range(10, 500) var combat_stamina_max: int = 100
## Pulih per detik setelah jeda regen_delay sejak aksi terakhir.
@export_range(0.0, 300.0) var combat_stamina_regen: float = 45.0
@export_range(0.0, 3.0, 0.05) var regen_delay: float = 0.7
## Pengali pulih saat menahan block.
@export_range(0.0, 1.0, 0.05) var guard_regen_scale: float = 0.35
## Berlari sambil memegang senjata menguras stamina per detik.
@export_range(0.0, 60.0) var run_cost_per_second: float = 10.0

@export_group("Exhausted")
## Stamina tempur habis: gerak melambat, tidak bisa menyerang, roll, atau block.
@export_range(0.5, 3.0, 0.05) var exhausted_time: float = 1.2
@export_range(0.1, 1.0, 0.05) var exhausted_speed_scale: float = 0.35

@export_group("Dodge roll")
## Ringan / sedang / berat, ditentukan beban perlengkapan (equip_load_ratio).
@export var roll_distance: PackedFloat32Array = PackedFloat32Array([56.0, 46.0, 30.0])
@export var roll_time: PackedFloat32Array = PackedFloat32Array([0.32, 0.38, 0.5])
## Jendela kebal (i-frames) sejak roll dimulai, detik.
@export var roll_iframes: PackedFloat32Array = PackedFloat32Array([0.22, 0.18, 0.08])
@export var roll_cost: PackedInt32Array = PackedInt32Array([16, 20, 26])
## Shift ditekan singkat (kurang dari ini) sambil memegang senjata = roll, bukan lari.
@export_range(0.05, 0.5, 0.01) var tap_run_roll_time: float = 0.22

@export_group("Beban perlengkapan")
## Batas rasio beban: di bawah light = Fast Roll, di bawah medium = Medium Roll, selebihnya Fat-Roll.
@export_range(0.0, 1.0, 0.05) var light_load: float = 0.3
@export_range(0.0, 1.5, 0.05) var medium_load: float = 0.7
## Kapasitas beban pemain (satuan berat).
@export_range(1.0, 100.0) var load_capacity: float = 16.0
## Berat dasar per slot: helmet, armor, leggings, boots.
@export var slot_weight: Dictionary = {"helmet": 2.0, "armor": 5.0, "leggings": 3.0, "boots": 2.0}
## Pengali berat per tier bahan (Wood..Obsidian, urutan ToolData.ToolTier).
@export var tier_weight: PackedFloat32Array = PackedFloat32Array([0.5, 0.8, 1.0, 0.9, 0.8, 0.9, 0.7, 0.6, 0.35, 1.2])

@export_group("Block dan parry")
## Tekan block tepat sebelum serangan mendarat (detik sejak tombol ditekan) = parry.
@export_range(0.02, 0.4, 0.01) var parry_window: float = 0.12
## Tekan ulang block terlalu cepat setelah parry gagal tidak membuka jendela parry (anti-spam).
@export_range(0.0, 1.5, 0.05) var parry_cooldown: float = 0.45
## Block hanya menahan serangan dari depan (sudut setengah dari arah hadap).
@export_range(10.0, 180.0) var guard_half_angle_deg: float = 75.0
## Stamina yang terkuras per poin damage yang ditahan.
@export_range(0.0, 10.0, 0.1) var guard_stamina_per_damage: float = 2.0
## Gerak saat menahan block.
@export_range(0.1, 1.0, 0.05) var guard_speed_scale: float = 0.5
## Stagger musuh setelah parry sukses (detik).
@export_range(0.2, 4.0, 0.05) var parry_stagger_time: float = 1.6
@export_range(1.0, 6.0, 0.1) var riposte_multiplier: float = 3.0
## Musuh yang terhuyung menerima damage lebih besar dari pukulan biasa.
@export_range(1.0, 3.0, 0.05) var staggered_damage_scale: float = 1.5
## Jarak maksimal (piksel) ke musuh yang terhuyung untuk riposte.
@export_range(8.0, 64.0) var riposte_range: float = 26.0

@export_group("Poise pemain")
@export_range(0.0, 200.0) var player_poise_base: float = 10.0
## Tambahan poise per satuan berat perlengkapan (zirah berat = lebih tahan benturan).
@export_range(0.0, 10.0) var player_poise_per_weight: float = 1.5
@export_range(0.0, 5.0) var poise_regen_delay: float = 2.0
@export_range(0.0, 200.0) var poise_regen_per_second: float = 25.0
## Poise pemain pecah: terhuyung, serangan terputus.
@export_range(0.1, 2.0, 0.05) var player_stagger_time: float = 0.45

@export_group("Serangan")
## Tahan klik kiri selama ini = serangan berat (heavy/charged).
@export_range(0.1, 2.0, 0.05) var heavy_charge_time: float = 0.45
## Klik kanan (bidik) busur/tongkat ditahan selama ini = tarikan penuh: denting, kilau, dan
## tembakan berikutnya lebih terang dan berat terasa (AimFx, hanya rasa).
@export_range(0.1, 2.0, 0.05) var aim_draw_time: float = 0.5
## Serangan dalam detik ini setelah berlari = sprint attack; setelah roll = roll attack.
@export_range(0.0, 1.0, 0.05) var sprint_attack_window: float = 0.15
@export_range(0.0, 1.0, 0.05) var roll_attack_window: float = 0.35

func roll_class(load_ratio: float) -> int:
	if load_ratio < light_load:
		return 0
	if load_ratio < medium_load:
		return 1
	return 2

static func pick(values: Variant, index: int, fallback: float) -> float:
	if values == null or values.size() == 0:
		return fallback
	return float(values[clampi(index, 0, values.size() - 1)])
