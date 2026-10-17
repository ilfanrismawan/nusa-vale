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
@export_range(0, 50) var stamina_cost: int = 0
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
