# Inventory: satu buku, node scene

Semua tab berada di `scenes/ui/ui_inventory.tscn`, di bawah `Dimmer/BookRoot`. Tas, Status, Equipment, Crafting, Keahlian, NPC, Koleksi, dan Setelan mengisi buku yang sama. Esc menutup buku. LB/RB berpindah tab; Setelan dibatasi P1 saat co-op.

## Mengubah visual di Godot

- Tab dan ikon: `TopTabsContainer`. Label, posisi, ukuran, dan tooltip adalah node scene biasa.
- Kategori tas: `RightRibbonsContainer`. Ikon, aksen warna, label, dan label jumlah sudah ada dalam scene.
- Tas: `LeftPage`, `RightPage`. Dua belas instance slot berada langsung dalam `SlotGrid`; pratinjau drag memakai `scenes/ui/inventory_drag_preview.tscn`.
- Status: `scenes/ui/inventory_status.tscn`.
- Equipment: `scenes/ui/inventory_equipment.tscn`. Semua slot karakter dan portrait adalah node yang dapat dipindahkan di editor.
- Crafting: `scenes/ui/inventory_crafting.tscn`.
- Keahlian: `scenes/ui/skill_tree_ui.tscn`.
- NPC: `scenes/ui/npc_relationship_ui.tscn`.
- Koleksi: `scenes/ui/inventory_collection.tscn`.
- Setelan: `scenes/ui/inventory_settings.tscn`. Memakai backend SettingsMenu yang sudah ada untuk menyimpan audio/display, binding, save/load, dan aksi keluar. Tampilan SettingsMenu mandiri tetap dipakai menu utama.
- Aksi tas, dialog buang, dan konfirmasi Biji Daya adalah node/instance scene di inventory. `scenes/ui/drop_item_dialog.tscn` mengatur tampilan pilihan jumlah.

Buka subscene untuk mengedit secara global. Untuk perubahan khusus instance, aktifkan **Editable Children** pada instance halaman. Pertahankan nama node bertanda Unique Name (ikon %) karena controller mengikat data dan sinyal melalui nama tersebut.

## Tema dan template

`resources/ui/inventory_book_theme.tres` menyimpan font, warna teks, skin panel dari atlas inventory, tombol cokelat, field input, progress, dan slider. Semua halaman memakai tema yang sama dengan nuansa tas. Ubah tema atau override node melalui Inspector; controller tidak membangun tema saat runtime.

Komponen daftar dinamis memakai template `.tscn`: `book_pager`, `book_text`, `inventory_action`, `inventory_empty`, `inventory_recipe_tile`, `inventory_material_row`, `inventory_collection_entry`, `inventory_binding_row`, `skill_tree_node`, `skill_tree_role`, `skill_tree_connection`, `relationship_resident`, `relationship_gift`, dan `relationship_heart`. Script menginstansiasi template sesuai data, mengisi teks/ikon/status, dan menghubungkan aksi; ukuran/layout/skin ada pada scene.

Keahlian dan NPC didesain pada ukuran halaman buku 420×224, sehingga tidak lagi mengecilkan panel fullscreen 1280×720. Marker `TierOrigin`, `TierStep`, dan `BranchStep` mengatur susunan otomatis pohon skill. Data role/perk, profil NPC, dan resep tetap bersumber dari katalog game.

Root inventory mengekspor `inventory_scale` (default 1.5). Ukuran otomatis dibatasi viewport, termasuk split-screen. Semua konten buku bebas ScrollContainer. Daftar panjang memakai tombol halaman, sedangkan deskripsi panjang dibagi ke halaman teks tanpa kehilangan isi. Pilihan jumlah buang, konfirmasi konsumsi/keluar, dan pemilih slot save tetap memakai dialog aksi yang sudah ada; tab halaman tidak membuka overlay atau mengganti scene dunia.

## Verifikasi

`tools/verify_mvp.ps1 -Scenes @('tests/menu_regression.tscn','tests/skill_tree_ui_regression.tscn','tests/npc_relationship_ui_regression.tscn') -TimeoutSeconds 120 -SkipEditor`

Tes menggunakan APPDATA audit terisolasi: klik tab/filter/slot, crafting, equip/unequip, discovery, hubungan, cabang skill, token, pengaturan audio, binding, save/load, kepemilikan co-op, dan pause.

## Batas kertas dan halaman tanpa scroll

Konten utama berada di dalam bidang kertas buku: kiri `(32, 20, 196, 224)` dan kanan `(248, 20, 200, 224)`, relatif terhadap BookRoot. Halaman tambahan memakai root 420×224 pada posisi `(28, 20)`; sisi kiri berawal pada x=4 dan sisi kanan x=220. Tidak ada panel kertas tambahan yang menimpa bingkai atau lipatan buku. Bookmark atas dan filter tas tetap menjadi navigasi di tepi buku.

`book_pager.tscn` menyediakan tombol sebelumnya/berikutnya dan nomor halaman. Inspector `content_path` menunjuk container isi, sedangkan `page_size` menentukan jumlah entri per halaman. Script hanya mengatur visibilitas entri dari template yang sudah ada. Resep, equipment, koleksi, NPC, hadiah dan binding kontrol memiliki pager masing-masing.

`book_text.tscn` menjaga seluruh isi deskripsi/status/catatan tetap tersedia melalui halaman teks. Ubah font dan tombol pada node Body/Navigation. Teks dibagi berdasarkan ukuran area dan metrik font, bukan dipotong permanen.

NPC menyediakan pilihan Profil, Aktivitas, Hadiah dan Detail hadiah. Setelan menyediakan Layar, Audio dan Permainan di halaman kiri; binding kontrol berhalaman di kanan. Detail panjang tidak memerlukan scrollbar.

`tests/inventory_book_layout_regression.tscn` memeriksa tidak adanya ScrollContainer pada konten buku, batas komponen, akses resep terakhir, serta kelengkapan teks panjang setelah pagination.
