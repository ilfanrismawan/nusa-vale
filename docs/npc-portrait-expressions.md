# Ekspresi portrait NPC

Wira sudah memakai ekspresi berdasarkan aktivitas di data/npc/wira.json.
Koordinat expressions adalah [kolom, baris], dihitung dari nol; ukuran satu frame 64 piksel.

Untuk ScheduledNPC lain, tambahkan pada visual di JSON NPC:

```json
"portrait_cell_size": 64,
"expressions": { "neutral": [0, 0], "happy": [0, 2] }
```

Tambahkan properti sejajar dialogue:

```json
"dialogue_expressions": { "breakfast": "happy", "working": ["happy", "neutral"] }
```

Nama aktivitas harus cocok dengan schedules. Array ekspresi mengikuti urutan baris dialog.
Periksa isi sheet masing-masing NPC sebelum menentukan koordinat; susunannya belum tentu sama.

Untuk VillageNPC melalui Inspector: isi Portrait Expressions dengan Texture2D/AtlasTexture,
Dialog Expressions untuk baris dialog biasa, Activity Expressions untuk nama aktivitas jadwal.
Ekspresi yang tidak tersedia kembali ke neutral, kemudian portrait bawaan.

Untuk event khusus saat dialog sudah terbuka:

```gdscript
_dialog_ui.set_expression("happy")
```

Saat pindah baris, dialog kembali memakai ekspresi yang dikonfigurasi untuk baris tersebut.
Implementasi ini menampilkan satu frame ekspresi statis; belum memutar animasi portrait.

Tes: Godot --headless --path . tests/portrait_expression_regression.tscn --quit-after 180
