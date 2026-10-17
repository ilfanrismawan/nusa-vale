# Cooking di Godot Editor

- Buka `resources/cooking/data/recipe_database.tres` untuk mengatur daftar dan urutan resep.
- Buat resource `RecipeData`, isi `id` unik, `display_name`, `ingredients` (ID item dan jumlah), serta `book_price`. Harga 0 berarti resep langsung dikenal pemain.
- Tambahkan resource tersebut ke array `recipes` database. Save/load otomatis mengenali ID resep dari database.
- Atur `output_item` ke resource ItemData hasil masakan dan `output_count` untuk jumlah hasil. Bila output_item kosong, sistem memakai item dengan ID yang sama dengan resep untuk kompatibilitas resep lama.
- Bahan harus tersedia, jumlahnya positif, dan hasil harus valid. Resep yang belum lengkap dinonaktifkan di menu. Transaksi tas penuh tidak menghabiskan bahan.
- Pada ItemData makanan, pilih kategori FOOD, atur `stamina_restore`, lalu isi array `food_effects` dengan resource FoodEffectData. Field `speed_buff_seconds`/`speed_buff_multiplier` hanya menjadi fallback untuk item lama tanpa food_effects.
- Edit tata letak dan judul di `scenes/ui/cooking_ui.tscn`; ukuran panel dan scene baris tersedia pada Inspector root. Tampilan baris ada di `scenes/ui/cooking_recipe_row.tscn`.
- Buka `resources/cooking/data/cooking_catalog.tres` sebagai pintu masuk semua resep, peralatan, scene objek, dan bahan baru.
- Buka `scenes/objects/cooking/cooking_equipment_gallery.tscn` untuk melihat peralatan secara bersamaan di viewport editor. Scene ini adalah pratinjau tanpa pemain.
- Dapur Warung kini merupakan node instance `WarungKitchen` pada `scenes/world/town.tscn`. Geser node tersebut untuk mengubah posisi. Sprite2D, CollisionShape2D, dan Label tersimpan sebagai node scene, bukan dibuat lewat script saat runtime.
- Nama label, AtlasTexture/region, collision shape, dan posisi komponen bisa diedit di scene peralatan. Pilih Make Local bila ingin mengubah resource bersama hanya untuk satu instance.

## Mengganti ikon dan gambar

- Gambar resep tampil di RecipeIcon pada `scenes/ui/cooking_recipe_row.tscn`. Ubah Custom Minimum Size, Stretch Mode, dan layout node untuk mengatur tampilannya.
- Pada resource RecipeData, field `icon` adalah gambar pengganti khusus resep. Bila kosong, gambar otomatis memakai `output_item.icon`; semua 137 hasil resep sudah memiliki ikon dari paket aset.
- Untuk mengganti gambar makanan di inventory sekaligus gambar resep default, edit `ItemData.icon` pada `resources/item_data/*.tres`. AtlasTexture dapat di-expand untuk mengubah Atlas dan Region, atau diganti langsung dengan PNG/Texture2D lain.
- Untuk mengganti thumbnail peralatan dalam daftar requirements, isi `CookingEquipmentData.icon` pada `resources/cooking/equipment/*.tres`. Bila kosong, otomatis memakai `item.icon`.
- Layout thumbnail alat tersedia di `scenes/ui/cooking_equipment_badge.tscn`. Scene baris resep memiliki field `equipment_badge_scene` yang dapat diganti di Inspector. Label status menunjukkan apakah alat sudah tersedia.
- Untuk mengubah gambar objek di world, buka scene alat di `scenes/objects/cooking/` lalu edit `Sprite2D.texture`/AtlasTexture.region. Gambar world dan ikon inventory/UI sengaja dapat diedit terpisah.
- Gunakan Make Unique pada resource texture bila perubahan hanya untuk satu item atau satu instance scene.

## Daftar peralatan

Pembaruan cookingware set menambahkan pisau koki, set bumbu, blender, panggangan, mangkuk, dua jenis wajan, penanak nasi, ketel, toaster, cobek, talenan, pisau daging, spatula, kukusan, dan loyang. Gambar panci/kompor/oven juga diperbarui; rak piring disediakan sebagai dekorasi. Daftar lengkap 22 alat fungsional, 27 scene, dan 137 requirements ada di `docs/cookingware-equipment.md`. Tabel berikut menunjukkan fasilitas lama yang tetap dipertahankan.

| Scene di `scenes/objects/cooking/` | Fungsi | Tag resep |
| --- | --- | --- |
| `kitchen_pot.tscn` | Panci masak | `pot` |
| `cooking_stove.tscn` | Kompor | `stove` |
| `cooking_oven.tscn` | Oven | `oven` |
| `prep_counter.tscn` | Persiapan, salad, minuman, makanan dingin | `prep` |
| `butter_churn.tscn` | Mentega dan krim | `churn` |
| `fermentation_barrel.tscn` | Yoghurt, kecap, acar | `ferment` |
| `kitchen_sink.tscn` | Dekorasi dengan collision | — |
| `kitchen_fridge.tscn` | Dekorasi dengan collision; belum menjadi penyimpanan inventory | — |
| `kitchen_plate.tscn` | Dekorasi piring | — |
| `honey_dipper.tscn` | Dekorasi sendok madu | — |

Drag scene ke world untuk menempatkannya di editor. ItemData peralatan disediakan di `resources/item_data`, tetapi `placeable` tetap false karena belum didaftarkan ke sistem konstruksi/placement inventory. Tidak ada pembelian peralatan yang berpura-pura sudah bisa dipasang dari tas.

Pada root peralatan interaktif, `equipment_data` menunjuk ke `resources/cooking/equipment/*.tres`. Resep yang mencantumkan alat tersebut pada `required_equipment` otomatis dapat ditampilkan. `recipe_tags` dan `RecipeData.station_tags` tetap tersedia untuk kategori tambahan. Tag peralatan kosong menghilangkan filter tampilan, bukan melewati pemeriksaan alat wajib.

## Requirements peralatan masak

Setiap resep bawaan kini memiliki array `required_equipment` berisi referensi CookingEquipmentData. Semua alat pada array wajib tersedia bersamaan; bahan lengkap saja tidak cukup. Misalnya pai apel membutuhkan oven, loyang, mangkuk, spatula, pisau, talenan, dan set bumbu. Sup sayur membutuhkan panci, kompor, spatula, pisau, dan talenan.

Pilih root KitchenStation dan edit array `installed_equipment` untuk mengatur fasilitas dapur tersebut. `equipment_data` milik stasiun itu sendiri otomatis dihitung tersedia. Daftar fasilitas ini merupakan konfigurasi dapur oleh pembuat level; tidak otomatis membaca objek tetangga atau alat di tas. Dapur Warung awal memiliki 22 fasilitas terpasang agar resep yang telah tersedia tetap bisa digunakan. Hapus fasilitas melalui Inspector untuk membuat dapur yang lebih terbatas.

Daftar requirements terpisah dari tag penjelajahan resep. Saat alat kurang, UI menampilkan nama alat yang belum tersedia dan tombol memasak dinonaktifkan. CookingManager memeriksa ulang semua syarat sebelum menyentuh bahan di tas. Belajar/beli buku resep tetap boleh meski alat belum tersedia.

Semua proses memakai transaksi cooking instan yang sudah ada. Tag `ferment`, `churn`, dan `prep` mengelompokkan resep; belum menambah timer produksi, animasi mesin, atau simulasi pendinginan.

## Bahan dan resep baru

132 resep baru menambah total menjadi 137. Setiap resep memiliki referensi `output_item` yang dapat dipilih lewat Inspector. Sebanyak 36 bahan pendukung tersedia di stock `resources/shop/general_store.tres`; harga dibaca dari ItemData masing-masing. Edit array stock untuk mengubah ketersediaan bahan.

18 bahan pendukung tidak mempunyai ikon khusus dalam paket sumber dan memakai slot icon kosong yang dapat Anda isi. Lihat `docs/cooking-asset-inventory.md` untuk pemetaan 207 aset makanan, daftar resep, dan bahan tanpa ikon. Bahan mentah serta sebagian bahan olahan dikategorikan MATERIAL agar tidak dimakan seperti hidangan jadi.

ID resep harus tetap stabil setelah game disimpan agar kepemilikan resep dapat dipulihkan. Efek makanan disimpan pada PlayerData sehingga tetap aktif ketika berpindah scene, terpisah per pemain, berhenti menghitung waktu saat game pause, dan dibersihkan saat game baru/load save. Efek sementara belum diserialisasi ke save.
