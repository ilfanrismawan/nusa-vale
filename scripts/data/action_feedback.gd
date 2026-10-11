class_name ActionFeedback
extends Resource
## Satu paket umpan balik untuk sebuah aksi (suara, partikel, guncangan, hitstop).
## Dipakai lewat Juice.play(&"<nama>", posisi) yang memuat resources/feedback/<nama>.tres.

@export_group("Suara")
@export var sound: AudioStream
@export_range(-24.0, 12.0, 0.5) var volume_db: float = 0.0
## Variasi pitch acak (0.08 = ±8%), supaya suara berulang tidak membosankan.
@export_range(0.0, 0.5, 0.01) var pitch_variation: float = 0.08

@export_group("Partikel")
@export_range(0, 64) var particle_count: int = 0
@export var particle_color: Color = Color.WHITE
## Warna kedua; tiap partikel mengambil warna acak di antara keduanya.
@export var particle_color_alt: Color = Color.WHITE
@export var particle_speed: float = 40.0
@export var particle_gravity: float = 160.0
@export var particle_lifetime: float = 0.45
## 0 = semburan ke atas (kipas sempit), 180 = ke segala arah.
@export_range(0.0, 180.0) var particle_spread: float = 60.0
## Ukuran maksimum partikel dalam piksel (minimum 1).
@export_range(1, 4) var particle_size: int = 2
## Gambar riak air (cincin melebar) di titik aksi.
@export var ripple: bool = false

@export_group("Kamera dan waktu")
## Kekuatan guncangan kamera dalam piksel dunia. 0 = tanpa guncangan.
@export_range(0.0, 6.0, 0.5) var shake: float = 0.0
@export_range(0.0, 1.0, 0.01) var shake_duration: float = 0.15
## Jeda singkat (milidetik) saat kena, membuat pukulan terasa berat. 0 = mati.
@export_range(0, 200) var hitstop_ms: int = 0
