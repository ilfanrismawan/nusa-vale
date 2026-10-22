# Pohon Keahlian

Buka inventory lalu tab Keahlian untuk halaman pohon di dalam buku yang sama. Klik tab lain atau gunakan LB/RB untuk berpindah halaman. Esc menutup inventory langsung; tidak ada popup atau pergantian world scene.

## Edit di Godot

- `scenes/ui/skill_tree_ui.tscn`: semua panel, posisi, ukuran, teks statis, progress, tombol dan warna.
- `scenes/ui/skill_tree_node.tscn`: bingkai slot buku, highlight terpilih/hover/fokus, ikon, label level dan status.
- `scenes/ui/skill_tree_role.tscn`: template tombol kategori role.
- Root skill tree: `design_size`, warna status dan template scene.
- `resources/skills/roles/*.tres`: nama, ikon, EXP hint dan daftar perk. Pada setiap RolePerk, bagian Skill Tree UI menyediakan `ui_icon` opsional dan `ui_position`. Posisi (-1,-1) memakai layout otomatis; posisi nonnegatif menggantikan posisi node dalam halaman. Perk dengan level/cabang yang sama digabung ke satu node; ikon/posisi memakai perk pertama. Koordinat relatif terhadap TreePanel.

Posisi otomatis memakai node Marker2D `TierOrigin`, `TierStep`, dan `BranchStep` di TreePanel. Edit marker di editor untuk mengubah jarak tingkat/cabang. Template garis ada di `scenes/ui/skill_tree_connection.tscn`.

Lima level per halaman menampilkan pohon tanpa memerlukan pan/zoom. Detail panjang memakai tombol halaman di sisi kanan buku; seluruh teks tetap dapat dibaca tanpa scroll. Node terkunci masih bisa dipilih untuk membaca manfaat. Garis menghubungkan tingkat level, bukan prasyarat gameplay tambahan.

## Aturan gameplay tetap

Memilih node hanya preview. Konfirmasi hanya memilih cabang A/B yang level aktifnya sudah cukup, memakai PlayerSkills.choose; tidak membelanjakan token. Perk biasa aktif otomatis setelah level naik saat tidur. Token tetap ditukar ke EXP untuk satu level berikutnya dan baru aktif setelah tidur, bukan mata uang unlock node seperti Sparks. Cabang permanen; tidak ada tombol refund/reset yang backend-nya belum tersedia. Perk coming_soon diberi keterangan dan tidak diaktifkan oleh UI.

Data selalu milik pemilik inventory, termasuk co-op. Menutup pohon tidak membuka kontrol dunia karena inventory pemilik masih terbuka.

Tes: `tests/skill_tree_ui_regression.tscn`, NUSA_SAVE_AUDIT=1 dan APPDATA terisolasi yang mengandung nusa-save-audit-. NUSA_SKILL_TREE_SCREENSHOT=1 pada renderer non-headless menghasilkan scratch/skill-tree-ui-preview.png.

Inventory memasang `SkillTreePage` dan `RelationshipPage` sebagai instance Control di bawah `Dimmer/BookRoot` pada `scenes/ui/ui_inventory.tscn`. Aktifkan Editable Children untuk mengubah instance. Properti `inventory_scale` di root inventory mengatur pembesaran (default 1.5); ukuran otomatis dibatasi viewport, termasuk co-op. Script hanya mengisi data, status, dan aksi gameplay pada template node.

Seluruh halaman memakai `resources/ui/inventory_book_theme.tres`. Panduan lengkap: `docs/inventory-book-editor.md`.
