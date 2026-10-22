class_name EnemyData
extends Resource

## Data satu jenis musuh. File: resources/enemies/<id>.tres.
## AI: Behavior Tree (GDD 8.2-B, lihat EnemyBrain) dengan kerucut pandang, pendengaran,
## status waspada, token serang, feint, dan mundur. Semua angka di bawah bisa diatur per musuh.

@export var id: StringName
@export var display_name: String = ""

@export_group("Scene")
## Kosong = enemy.tscn (atau boss.tscn untuk BossData). Gunakan inherited scene untuk varian.
@export var scene: PackedScene

@export_group("Gambar")
## Folder berisi Idle.png, Walk.png, Attack.png, Damage.png, Dead.png
## (res://assets/farm_rpg/Enemy/..., huruf E besar). Sheet yang tidak ada dilewati.
@export_dir var sprite_folder: String = ""
## Ukuran satu frame di sheet. Baris sheet: bawah, atas, kanan, kiri (sheet 1 baris = semua arah sama).
@export var frame_size: Vector2i = Vector2i(32, 32)
@export_range(1.0, 24.0) var animation_fps: float = 8.0
## Geser gambar supaya kaki musuh berada di titik asal node.
@export var sprite_offset: Vector2 = Vector2(0, -8)

@export_group("Statistik")
@export_range(1, 9999) var max_hp: int = 20
## Serangan musuh; pemain menerima max(1, attack - total DEF).
@export_range(0, 999) var attack: int = 5
@export_range(0, 999) var defense: int = 0
## true = melukai pemain yang menyentuhnya.
@export var contact_damage: bool = true
@export_range(2.0, 32.0) var body_radius: float = 6.0
## 0 = terdorong penuh, 1 = tidak bergeser saat kena.
@export_range(0.0, 1.0, 0.05) var knockback_resist: float = 0.0

@export_group("AI")
enum AttackStyle { LUNGE, SWING, RANGED }
## false = musuh target yang diam (seperti Phase 4B-1).
@export var ai_enabled: bool = true
## LUNGE = melompat menerjang ke pemain (slime). SWING = memainkan Attack.png lalu memukul di depan (myconid).
@export var attack_style: AttackStyle = AttackStyle.LUNGE
## Kecepatan (piksel/detik) saat patroli dan saat mengejar.
@export_range(0.0, 200.0) var patrol_speed: float = 18.0
@export_range(0.0, 300.0) var chase_speed: float = 38.0
## Jarak pandang: pemain di dalam kerucut pandang dan lebih dekat dari ini ketahuan (1 tile = 16 piksel).
@export_range(16.0, 400.0) var aggro_radius: float = 80.0
## Berhenti mengejar dan pulang bila pemain lebih jauh dari ini, atau musuh terlalu jauh dari titik asal.
@export_range(16.0, 600.0) var give_up_radius: float = 150.0
## Patroli acak di sekitar titik muncul.
@export_range(0.0, 200.0) var patrol_radius: float = 40.0
@export_range(0.0, 10.0) var idle_time_min: float = 1.0
@export_range(0.0, 10.0) var idle_time_max: float = 2.5
## Mulai menyerang bila jarak ke pemain di bawah ini.
@export_range(4.0, 120.0) var attack_range: float = 18.0
## Ancang-ancang (musuh berkedip) sebelum serangan; ini jendela pemain untuk menghindar.
@export_range(0.0, 3.0) var attack_windup: float = 0.45
## Jeda setelah menyerang sebelum bisa menyerang lagi.
@export_range(0.0, 5.0) var attack_cooldown: float = 1.2
## LUNGE: kecepatan dan lama terjangan.
@export_range(0.0, 400.0) var lunge_speed: float = 120.0
@export_range(0.05, 1.0) var lunge_time: float = 0.25
## SWING: frame Attack.png yang memberi damage.
@export_range(0, 16) var attack_hit_frame: int = 3
## Lama musuh tertegun (berhenti) setelah terkena pukulan.
@export_range(0.0, 2.0) var hurt_stun: float = 0.35

@export_group("Jarak jauh")
@export var projectile_speed: float = 150.0
@export_range(16.0, 600.0) var projectile_range: float = 240.0
@export var projectile_color: Color = Color(1, 0.7, 0.3)
@export var preferred_distance: float = 70.0

@export_group("Poise")
## Ketahanan benturan tersembunyi (GDD 8.2-A4). Serangan pemain mengikisnya; habis = terhuyung
## (stagger) dan bisa diriposte.
@export_range(1.0, 999.0) var poise: float = 20.0
## Poise pulih penuh-bertahap setelah tidak dipukul selama ini.
@export_range(0.0, 10.0) var poise_regen_delay: float = 2.0
@export_range(0.0, 200.0) var poise_regen: float = 12.0
## Lama terhuyung saat poise pecah.
@export_range(0.2, 5.0) var stagger_time: float = 1.4
## Kikisan poise pemain per serangan. 0 = 1,5 x attack.
@export_range(0.0, 200.0) var poise_damage: float = 0.0
## false = serangan musuh ini tidak bisa di-parry (hanya block/roll).
@export var parryable: bool = true

@export_group("Persepsi")
## Behavior Tree AI (GDD 8.2-B). Jarak pandang = aggro_radius, dikali cahaya (gua/malam).
## Sudut kerucut pandang ke arah hadap (derajat penuh).
@export_range(10.0, 360.0) var vision_angle_deg: float = 110.0
## Pemain sedekat ini selalu ketahuan walau di belakang musuh (piksel).
@export_range(0.0, 64.0) var close_sense_radius: float = 22.0
## Pengali jarak pandang di area gelap (gua) dan saat malam paling gelap.
@export_range(0.1, 1.0, 0.05) var dark_vision_scale: float = 0.6
@export_range(0.1, 1.0, 0.05) var night_vision_scale: float = 0.6
## Di dalam kerucut tapi sedikit di luar jarak pandang = siluet sekilas (curiga, bukan aggro).
@export_range(1.0, 3.0, 0.05) var glimpse_range_scale: float = 1.4
## Pengali radius suara yang terdengar (1 = normal).
@export_range(0.0, 3.0, 0.05) var hearing_scale: float = 1.0
## Lama memeriksa lokasi mencurigakan sambil menoleh sebelum kembali tenang.
@export_range(0.0, 15.0, 0.5) var investigate_time: float = 3.0
## Target hilang dari pandangan selama ini = musuh mencari di posisi terakhir pemain terlihat.
@export_range(0.0, 15.0, 0.5) var memory_time: float = 3.0

@export_group("Taktik")
## Peluang (0-1) memakai serangan pancingan (feint) alih-alih serangan sungguhan.
@export_range(0.0, 1.0, 0.05) var feint_chance: float = 0.15
## Feint tidak dicoba lagi selama ini (detik).
@export_range(0.0, 20.0, 0.5) var feint_cooldown: float = 4.0
## HP di bawah rasio ini = mundur ke belakang kawan dan memanggil bantuan (0 = tidak pernah).
@export_range(0.0, 0.9, 0.05) var retreat_hp_ratio: float = 0.3
@export_range(0.5, 10.0, 0.5) var retreat_time: float = 2.5
@export var calls_for_help: bool = true
## Setelah mundur musuh nekat (desperation): ancang-ancang dan jeda serangan lebih singkat.
@export_range(0.2, 1.0, 0.05) var desperate_speed_scale: float = 0.65

@export_group("Suara")
## Preset Juice (resources/feedback/<key>.tres) saat musuh terkena dan saat mati.
@export var hit_feedback: StringName = &"creature_hit"
@export var death_feedback: StringName = &"enemy_death"

@export_group("Hadiah")
## item_id yang jatuh saat mati. Kosong = tidak ada.
@export var drop_item_id: String = ""
@export_range(0.0, 1.0, 0.05) var drop_chance: float = 0.5
@export_range(1, 10) var drop_min: int = 1
@export_range(1, 10) var drop_max: int = 1
