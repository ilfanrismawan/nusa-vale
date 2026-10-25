class_name VehicleData
extends Resource

## Data satu kendaraan (GDD 10): sepeda, sapu terbang, kendaraan lanjutan Modern City.
## Dipasang di ItemData.vehicle. Pegang itemnya di hotbar lalu tekan tombol Alat untuk naik;
## tombol Alat lagi = turun. Kendaraan tidak perlu menahan tombol lari.

@export var vehicle_id: String = ""
@export var display_name: String = ""
## Pengali kecepatan jalan Player.speed. Lari (Shift) = 3.0, jadi 3.3 = lari +10%.
@export_range(1.0, 8.0, 0.05) var speed_multiplier: float = 3.3
## Terbang melintasi air (tile air, kolam, sungai).
@export var crosses_water: bool = false
## Terbang melintasi jurang pendek (node/tile bertanda "vehicle_gap").
@export var crosses_gaps: bool = false
## Badan pemain dan kendaraan diangkat setinggi ini (piksel) di atas bayangan. 0 = di tanah.
@export_range(0.0, 24.0, 0.5) var hover_height: float = 0.0
## Ayunan naik-turun saat melayang (piksel).
@export_range(0.0, 6.0, 0.5) var hover_bob: float = 0.0
## Sembunyikan sprite pemain (mis. duduk di dalam kabin mobil).
@export var hide_rider: bool = false
## Animasi karakter berlayer saat menumpang (CharacterSheet di character_catalog, mis. "bicycle_idle").
## Kendaraan sudah tergambar di animasi itu (sepeda: PNG/15. Bicycle, sapu: PNG/25. Broomstick).
## Kosong = pakai Idle/Walk biasa + visual_scene.
@export var rider_idle_animation: StringName
@export var rider_move_animation: StringName
## Scene tampilan kendaraan terpisah (Node2D dengan vehicle_visual.gd) untuk kendaraan tanpa
## animasi karakter (skuter, mobil bak). Kosong = tidak ada.
@export var visual_scene: PackedScene
## Kendaraan baru bisa dibeli setelah area ini terbuka di UnlockManager (kosong = selalu).
## Contoh: "modern_city" untuk skuter dan mobil bak.
@export var required_unlock: String = ""
## Suara Juice saat naik/turun.
@export var mount_sound: StringName = &"swish"
