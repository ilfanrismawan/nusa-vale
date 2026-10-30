class_name EatFeedback
extends Resource
## Umpan balik saat pemain makan (FoodEating). Semua angka di sini, atur lewat Inspector di
## resources/feedback/eat.tres.

@export_group("Animasi")
## Nama animasi karakter (SpriteFrames "<nama>_down" dst.). Bila belum ada, tubuh pemain
## dianggukkan dengan tween sebagai pengganti.
@export var animation_name: StringName = &"eat"
@export_range(0.1, 4.0, 0.05) var animation_speed := 1.0
## Pemain menghadap ke bawah saat makan, seperti memperlihatkan makanan ke kamera.
@export var face_camera := true
@export var lock_input := true

@export_group("Gigitan")
@export_range(1, 8) var bites := 3
@export_range(0.05, 1.0, 0.01) var bite_interval := 0.24
## Jeda sebelum gigitan pertama (makanan diangkat ke mulut).
@export_range(0.0, 1.0, 0.01) var lift_time := 0.16
## Posisi ikon makanan relatif ke pemain (depan mulut).
@export var mouth_offset := Vector2(0, -3)
@export_range(0.2, 2.0, 0.05) var icon_scale := 0.85
## Sisa ukuran ikon setelah tiap gigitan (0.8 = mengecil 20%).
@export_range(0.2, 1.0, 0.05) var shrink_per_bite := 0.8
## Tubuh mengangguk saat menggigit (dipakai juga bila animasi makan belum ada).
@export var bite_squash := Vector2(1.06, 0.92)
## Remah: warna diambil dari ikon makanan bila sample_icon_color aktif.
@export var crumbs: ActionFeedback = preload("res://resources/feedback/eat_crumbs.tres")
@export var sample_icon_color := true
@export var chew_sound: AudioStream = preload("res://assets/audio/sfx/nibble.wav")
@export_range(-24.0, 12.0, 0.5) var chew_volume_db := -6.0
## Nada tiap gigitan naik sekian semitone agar terasa "nyam-nyam-nyam".
@export_range(0.0, 6.0, 0.5) var chew_pitch_step := 2.0

@export_group("Selesai")
@export var finish: ActionFeedback = preload("res://resources/feedback/sparkle.tres")
@export var gulp_sound: AudioStream = preload("res://assets/audio/sfx/pickup.wav")
@export_range(-24.0, 12.0, 0.5) var gulp_volume_db := -4.0
@export var stamina_color := Color(0.62, 0.95, 0.42)
@export var hp_color := Color(1.0, 0.45, 0.45)
@export var effect_color := Color(0.75, 0.85, 1.0)
@export_range(0.0, 2.0, 0.05) var text_hold := 0.5
## Jeda antar teks melayang (+stamina, +HP, nama efek).
@export_range(0.0, 0.5, 0.01) var text_stagger := 0.12
## Bila sedang makan, klik lagi diabaikan (true) atau langsung makan tanpa efek (false).
@export var block_while_eating := true
