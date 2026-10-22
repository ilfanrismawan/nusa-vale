# Notifikasi dan petunjuk kontrol HUD

## Edit di Godot

- `scenes/ui/notify.tscn`: autoload Notify, posisi stack, lebar kartu, batas jumlah, batas tinggi dan margin layar. API `Notify.say(teks)` tetap sama.
- `scenes/ui/notification_card.tscn`: panel krem, badge pemberitahuan, teks dan indikator durasi. Pilih root untuk mengubah display_seconds, fade_seconds dan entrance_seconds.
- `scenes/ui/action_hints.tscn`: petunjuk HUD dengan HFlowContainer yang membungkus badge sesuai lebar viewport.
- `scenes/ui/action_hint_badge.tscn`: bentuk badge tombol dan label aksi.
- `scenes/ui/hud.tscn`: instance ActionHints dapat dipilih di editor; player diisi oleh HUD.

Tema memakai cooking_theme.tres. Warna panel/badge, font, jarak dan ukuran dapat diedit melalui scene tanpa membuat layout melalui kode.

## Perilaku

Notifikasi baru muncul di tengah atas agar tidak menutup cuaca/jam. Pesan kosong diabaikan, antrean terlihat dibatasi langsung, teks panjang dibungkus dan stack diskalakan bila melebihi layar. Fade dan durasi tetap berjalan saat gameplay dijeda. Semua node notifikasi dan petunjuk mengabaikan mouse, sehingga tidak menghalangi interaksi.

Petunjuk tetap mengikuti input terakhir, remap, konteks lapangan/udara/renang/combat, opsi show_hints, serta pemilik HUD di co-op. Tombol yang memiliki dua arti digabung ke satu badge. Menu/dialog dan kondisi kalah menyembunyikannya.

Badge ditempatkan di atas hotbar, menyisakan area bar HP/stamina. Saat meter penyiram muncul, petunjuk naik untuk menghindarinya. Margin serta right_reserve dapat diubah pada root ActionHints. Dictionary entries memungkinkan perubahan teks/daftar aksi per konteks.

## Tes

Gunakan NUSA_SAVE_AUDIT=1 dan APPDATA terisolasi. Tes khusus `tests/hud_feedback_visual_regression.tscn` memeriksa batas notifikasi, durasi saat pause, input keyboard/gamepad, click-through dan viewport kecil. NUSA_HUD_FEEDBACK_SCREENSHOT=1 tanpa --headless menyimpan preview di scratch.

Preview visual ringan tanpa memuat karakter: jalankan `tests/hud_feedback_preview.tscn` tanpa --headless dengan NUSA_SAVE_AUDIT=1. Ini merender scene notifikasi dan badge asli memakai contoh teks, lalu menyimpan scratch/hud-feedback-preview.png.
