# Hover hotbar

Tooltip hotbar memakai `scenes/ui/hotbar_tooltip.tscn`: kartu krem berikon, nama maksimal dua baris, tanpa rincian kemampuan panjang. Tooltip mengikuti penempatan bawaan Godot dan tidak menangkap input mouse.

Ubah warna, radius, padding, ukuran ikon, lebar label dan font langsung di scene tersebut. Root hotbar mengekspos `tooltip_scene` di Inspector untuk mengganti template. Pertahankan path `Margin/Content/Icon` dan `Margin/Content/Name` pada template pengganti.

Slot inventory lain tetap memakai tooltip bawaan; perubahan ini khusus hotbar. Detail kemampuan item tetap tersedia melalui informasi inventory.

Tes: Godot --headless --path . tests/hotbar_hover_regression.tscn (gunakan NUSA_SAVE_AUDIT=1 dan APPDATA terisolasi yang mengandung nusa-save-audit-).
