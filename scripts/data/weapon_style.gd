class_name WeaponStyle
extends Resource

## Cara satu jenis senjata menyerang (pedang, busur, tongkat sihir).
## Angka serangan ada di ItemData.attack_bonus; file ini hanya gaya dan jangkauannya.
## File: resources/combat/<jenis>.tres, dipilih Combat.style_for() lewat ItemData.weapon_type.

## Animasi karakter (sword, archer, mage) dari character_catalog.tres.
@export var animation_name: StringName = &"sword"
## Kapan pukulan/proyektil keluar, sebagai bagian dari jumlah frame animasi (0..1).
@export_range(0.0, 1.0, 0.05) var hit_frame_ratio: float = 0.5
## Kecepatan animasi serangan (1 = normal).
@export_range(0.5, 3.0, 0.05) var speed_scale: float = 1.0
## Frame animasi yang ditahan selama klik kanan ditahan (busur ditarik, tongkat terangkat). -1 = tanpa pose bidik.
@export var aim_pose_frame: int = -1

@export_group("Jarak dekat")
## Jari-jari area tebasan dalam piksel. 0 = senjata jarak jauh.
@export_range(0.0, 48.0) var melee_radius: float = 0.0
## Jarak pusat tebasan dari kaki pemain, searah bidikan.
@export_range(0.0, 48.0) var melee_reach: float = 14.0

@export_group("Proyektil")
@export_range(0.0, 600.0) var projectile_speed: float = 180.0
@export_range(1.0, 20.0, 0.5) var projectile_range_tiles: float = 8.0
## Kosong = bola energi digambar dengan warna projectile_color.
@export var projectile_texture: Texture2D
## Putaran gambar agar ujungnya menghadap ke kanan (ikon panah miring = -45).
@export_range(-180.0, 180.0) var projectile_texture_rotation_deg: float = 0.0
@export var projectile_color: Color = Color(0.62, 0.48, 1.0)
## true = butuh anak panah di tas (ItemData.weapon_type ARROW), satu per tembakan.
@export var uses_ammo: bool = false

@export_group("Biaya dan rasa")
## Stamina tempur (bar terpisah, GDD 8.2-A1) untuk serangan ringan dan berat.
@export_range(0, 50) var stamina_cost: int = 0
@export_range(0, 80) var heavy_stamina_cost: int = 0
## Dorongan ke target dalam piksel.
@export_range(0.0, 64.0) var knockback: float = 10.0
## Umpan balik Juice (resources/feedback/<nama>.tres). hit_feedback kosong = hanya suara
## dari musuh yang terkena (EnemyData.hit_feedback); isi untuk efek tambahan, mis. sihir.
@export var swing_feedback: StringName = &"swish"
@export var hit_feedback: StringName = &"weapon_hit"

@export_group("Combo")
## Pengali damage tiap pukulan combo; jumlah isinya = panjang combo. Pukulan terakhir = finisher.
@export var combo_damage: PackedFloat32Array = PackedFloat32Array([1.0])
## Pengali kecepatan animasi tiap pukulan combo (kosong/kurang = 1).
@export var combo_speed: PackedFloat32Array = PackedFloat32Array()
## Detik setelah serangan selesai untuk menyambung pukulan berikutnya. Klik saat menyerang disimpan.
@export_range(0.0, 2.0, 0.05) var combo_window: float = 0.45
@export var finisher_knockback_scale: float = 1.0
## Jari-jari tebasan finisher dikali angka ini (pedang).
@export var finisher_radius_scale: float = 1.0
## Jumlah proyektil finisher (busur: 2 panah, hanya 1 anak panah terpakai) dan sebarannya.
@export_range(1, 5) var finisher_projectiles: int = 1
@export_range(0.0, 45.0) var finisher_spread_deg: float = 10.0
## Ukuran proyektil finisher (tongkat: bola sihir besar).
@export_range(0.5, 4.0, 0.1) var finisher_projectile_scale: float = 1.0
## Umpan balik tambahan saat finisher keluar (kosong = tidak ada).
@export var finisher_feedback: StringName = &""

func combo_length() -> int:
	return maxi(1, combo_damage.size())

func combo_damage_at(step: int) -> float:
	return combo_damage[step] if step >= 0 and step < combo_damage.size() else 1.0

func combo_speed_at(step: int) -> float:
	return combo_speed[step] if step >= 0 and step < combo_speed.size() else 1.0

func is_finisher(step: int) -> bool:
	return combo_length() > 1 and step == combo_length() - 1

@export_group("Frame data")
## Fase serangan (GDD 8.2-A5): startup = 0..hit_frame_ratio, active = sampai active_end_ratio
## (hitbox tebasan aktif tiap frame, tiap musuh kena sekali), sisanya recovery.
@export_range(0.0, 1.0, 0.05) var active_end_ratio: float = 0.7
## Recovery hanya bisa dibatalkan dengan roll setelah bagian animasi ini (1 = tidak bisa).
@export_range(0.0, 1.0, 0.05) var recovery_cancel_ratio: float = 0.85

@export_group("Variasi serangan")
## Serangan berat: tahan klik kiri (CombatRules.heavy_charge_time).
@export_range(1.0, 5.0, 0.05) var heavy_damage: float = 2.0
@export_range(0.2, 2.0, 0.05) var heavy_speed: float = 0.8
@export_range(1.0, 3.0, 0.05) var heavy_radius_scale: float = 1.25
@export_range(1.0, 4.0, 0.1) var heavy_projectile_scale: float = 1.5
@export_range(1.0, 4.0, 0.1) var heavy_knockback_scale: float = 2.0
## Sprint attack (setelah berlari): damage dan dorongan maju (piksel).
@export_range(1.0, 3.0, 0.05) var sprint_damage: float = 1.25
@export_range(0.0, 64.0) var sprint_lunge: float = 22.0
## Roll attack (segera setelah roll): damage dan kecepatan animasi.
@export_range(1.0, 3.0, 0.05) var roll_damage: float = 1.3
@export_range(0.5, 3.0, 0.05) var roll_speed: float = 1.3

@export_group("Poise dan block")
## Kikisan poise musuh per serangan ringan. Berat/finisher/sprint/roll dikali pengalinya.
@export_range(0.0, 100.0) var poise_damage: float = 10.0
## Bagian damage yang ditahan saat block (0..1).
@export_range(0.0, 1.0, 0.05) var block_reduction: float = 0.6
## Frame pose saat block (-1 = tanpa pose khusus).
@export var guard_pose_frame: int = -1

@export_group("Weapon art")
## Satu art per tier bahan (index = ToolData.ToolTier: Wood..Obsidian). Kurang = pakai yang terakhir.
@export var arts: Array[WeaponArt] = []

func art_for(tier: int) -> WeaponArt:
	if arts.is_empty():
		return null
	return arts[clampi(tier, 0, arts.size() - 1)]
