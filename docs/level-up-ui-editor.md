# Rekap Level Up setelah tidur

`scenes/ui/level_up_ui.tscn` adalah scene native yang dibuka SkillManager setelah laporan pengiriman selesai. Buka di Godot untuk mengedit panel, font, warna, ikon, tombol dan posisi. Tema memakai `resources/ui/cooking_theme.tres`; backdrop memakai shader UI bersama. Root mengekspos `design_size` untuk scaling proporsional per viewport.

Panel kiri menampilkan satu kenaikan keahlian per halaman: ikon, pemilik, level sebelum/sesudah dan manfaat yang terbuka. Area manfaat dapat digulir bila kenaikan banyak level menghasilkan teks panjang. Panel kanan menampilkan satu pilihan cabang A/B per halaman. Nanti saja atau Esc menunda pilihan tanpa menghapusnya; pilihan tetap tersedia di tab Keahlian. Cabang belum tersedia tetap disabled sesuai resource RoleData.

Data level, nama role, ikon, perk dan judul cabang tetap berasal dari PlayerSkills dan `resources/skills/roles/*.tres`, bukan salinan nilai di UI. Pemain co-op ditampilkan memakai nama masing-masing. UI tidak memberikan EXP, memilih otomatis, atau mengubah mekanisme simpan game.

Tes: `tests/level_up_ui_regression.tscn` dengan NUSA_SAVE_AUDIT=1 dan APPDATA terisolasi yang mengandung nusa-save-audit-. Set NUSA_LEVEL_UI_SCREENSHOT=1 pada renderer non-headless untuk menyimpan preview di scratch.
