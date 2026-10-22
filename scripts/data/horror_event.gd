class_name HorrorEvent
extends Resource

## Satu "kejadian ganjil" malam hari (GDD 4.1, Horor Tengah Malam).
## Buat file baru di resources/horror/events/ lalu masukkan ke daftar `events`
## pada scenes/effects/night_horror.tscn.

enum Kind {
	SHADOW_GLIMPSE, ## Siluet diam sekilas di tepi layar.
	SHADOW_DASH, ## Siluet melesat melintasi layar.
	WHISPER, ## Bisikan dari kiri atau kanan pemain.
	FOOTSTEPS, ## Langkah kaki di belakang; ikut berhenti saat pemain berhenti.
	LAMP_FLICKER, ## Lampu/api terdekat berkedip (tanpa lampu: layar berkedip).
	RED_EYES, ## Sepasang mata merah di kegelapan, hilang bila didekati.
	CROWS, ## Sekawanan gagak terbang mendadak sambil berkoak.
}

@export var id: StringName
@export var kind: Kind = Kind.WHISPER
## Peluang relatif dipilih dibanding kejadian lain.
@export_range(0.0, 10.0, 0.1) var weight: float = 1.0
## Rasa takut minimal (0..1) agar kejadian ini bisa muncul.
@export_range(0.0, 1.0, 0.01) var min_fear: float = 0.0
## Kegelapan minimal (DayCycle.night_intensity): 0,7 = mulai 00.00.
@export_range(0.0, 1.0, 0.01) var min_night: float = 0.7
## Jeda minimal sebelum kejadian yang sama boleh muncul lagi (detik nyata).
@export var cooldown_seconds: float = 40.0
## Kosong = suara sintesis bawaan untuk jenis ini.
@export var sound: AudioStream
@export_range(-40.0, 12.0, 0.5) var volume_db: float = -8.0
## Tambahan rasa takut saat kejadian dimulai.
@export_range(0.0, 1.0, 0.01) var fear_add: float = 0.08
## Glitch layar + dengung rendah sesaat.
@export var glitch: bool = false
## Guncangan kamera (0 = tidak ada). Co-op: dilewati.
@export_range(0.0, 6.0, 0.1) var shake: float = 0.0
## Lama kejadian (detik): kedip lampu, mata merah, bisikan.
@export var duration: float = 2.0
## Jumlah langkah / gagak / kedipan.
@export_range(1, 20) var count: int = 4
## Jarak dari pemain (piksel dunia).
@export_range(16.0, 240.0, 1.0) var distance: float = 90.0
## Teks Notify opsional (bahasa Indonesia). Kosong = tanpa teks.
@export_multiline var notify_text: String = ""
