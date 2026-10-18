class_name WeaponArt
extends Resource

## Weapon Art / skill khusus senjata (GDD 8.2-A6). Tombol F (gamepad: klik stik kiri).
## File: resources/combat/arts/<id>.tres. Dipilih per tier lewat WeaponStyle.arts.

enum Kind {
	## Beberapa tebasan beruntun ke depan.
	MULTI_SLASH,
	## Tebasan berputar mengenai semua musuh di sekeliling pemain.
	SPIN,
	## Beberapa proyektil menyebar sekaligus.
	VOLLEY,
	## Satu proyektil yang menembus semua musuh di jalurnya.
	PIERCE_SHOT,
	## Ledakan cincin di sekeliling pemain.
	BURST,
	## Lingkaran penyembuh: memulihkan HP pemain di dalamnya dan melukai musuh.
	HEAL_CIRCLE,
}

@export var id: StringName
@export var display_name: String = ""
@export var kind: Kind = Kind.MULTI_SLASH
@export_range(0, 100) var stamina_cost: int = 30
## Detik sebelum art bisa dipakai lagi.
@export_range(0.0, 30.0, 0.5) var cooldown: float = 4.0
## Pengali damage per pukulan/proyektil (dari ATK senjata).
@export_range(0.1, 10.0, 0.05) var damage_scale: float = 1.0
@export_range(0.0, 10.0, 0.1) var poise_scale: float = 1.5
## Jumlah tebasan atau proyektil.
@export_range(1, 12) var count: int = 2
## Jeda antar tebasan (MULTI_SLASH) dalam detik.
@export_range(0.02, 1.0, 0.01) var interval: float = 0.12
## Jari-jari area (SPIN, BURST, HEAL_CIRCLE) dalam piksel.
@export_range(4.0, 128.0) var radius: float = 26.0
@export_range(0.0, 90.0) var spread_deg: float = 12.0
## true = DEF musuh diabaikan (penembus zirah).
@export var ignore_defense: bool = false
## HEAL_CIRCLE: HP yang dipulihkan.
@export_range(0, 200) var heal_amount: int = 0
@export var color: Color = Color(1.0, 0.85, 0.4)
## Umpan balik Juice saat art keluar.
@export var feedback: StringName = &"combo_finisher"
