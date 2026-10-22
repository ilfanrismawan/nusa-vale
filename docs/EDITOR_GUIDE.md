# Panduan edit crafting dan karakter di Godot

15 Oktober 2026. Path `res://` berikut dapat dicari langsung di panel FileSystem Godot.

## Edit dan tambah crafting recipe

File utama: **`res://resources/crafting/catalog.tres`**. Pilih file tersebut di FileSystem, lalu buka array **Recipes** di Inspector. Tiap elemen adalah Resource `CraftingRecipe` yang bisa dibuka dan diubah.

| Field Inspector | Fungsi / contoh |
|---|---|
| Recipe Id | ID unik resep, misalnya `storage_box` |
| Output Item Id | ID item hasil; harus ada `resources/item_data/<id>.tres` |
| Output Amount | Jumlah hasil per batch, 1–99 |
| Ingredients | Dictionary: key String ID item, value int positif; contoh `wood: 25`, `stone: 5` |
| Group | Kelompok menu crafting: `Equipment`, `Amunisi`, atau `Bangunan`; nama baru hanya muncul di filter Semua sampai UI ditambah |

Untuk menambah resep: tambah elemen di Recipes → pilih **New CraftingRecipe** → isi field → simpan katalog. Alternatifnya buat Resource `CraftingRecipe` tersendiri dan drag file `.tres` ke array Recipes. Bila menduplikasi resep, gunakan **Make Unique** sebelum mengubah dan ganti Recipe Id agar tidak duplikat.

Jika hasil/bahan adalah item baru, buat atau duplikasi `ItemData` di `resources/item_data/`, isi `item_id`, nama, ikon, kategori, harga dan pengaturan stack. Nama file harus cocok dengan ID karena resolver memuat `resources/item_data/<id>.tres`. Katalog crafting langsung dipakai `CraftingSystem` dan UI; tidak perlu mendaftarkan resep ke script kedua. Jalankan ulang game setelah mengedit resource saat sesi game sedang berjalan.

Uji cepat: buka tab Crafting, periksa bahan/hasil, buat satu dan beberapa batch, lalu coba tas penuh dan bahan kurang. Resep mesin bukan array yang sama: lihat `resources/furnace/`, `resources/preserves_jar/`, `resources/dehydrator/`; cooking saat ini dikonfigurasi di `scripts/system/cooking_manager.gd`.

## Edit pilihan customize character

File utama: **`res://resources/character/character_catalog.tres`**. Buka **Parts** di Inspector. Resource `CharacterPart` mengatur `Id`, `Display Name`, `Layer`, `Asset`, dan `Colors`.

- `Asset` merupakan path relatif terhadap folder masing-masing animasi. Contoh `Hair's/Standard/{color}.png`, `Skins/1.png`.
- Sediakan layer dengan tata letak frame yang cocok di setiap folder pose yang dipakai, bukan hanya Idle. Folder sumber ada di `assets/farm_rpg/Character/PNG/`.
- `Colors` harus sesuai nama file; placeholder `{color}`, `{skin}`, `{hair_color}` diganti oleh sistem.
- `Clothing Style`/`Hair Style` tertentu memakai pengolahan mask melalui kode. Menambah nama style baru saja belum menambah implementasi desainnya. Opsi `PANTS` juga perlu dukungan komposisi; keberadaan nilai enum tidak menjamin layer baru otomatis tergambar.

Tambah elemen Parts → **New CharacterPart** → ID unik → layer dan asset → simpan → jalankan Character Creator atau Wardrobe. Jangan mengubah ID pilihan lama tanpa mempertimbangkan save yang menyimpannya.

## Edit frame, FPS, loop dan animasi player

Ada dua jalur yang berbeda:

1. **Animasi dasar dari template:** buka **`res://scenes/player/Player.tscn`**, pilih `CharacterBody2D/AnimatedSprite2D`, klik **Sprite Frames** di Inspector untuk membuka panel SpriteFrames. Pilih animasi (misalnya `idle_down`, `walk_down`, `water_down`), atur FPS, loop, urutan frame, durasi dan region atlas. Nama node template di katalog adalah `AnimatedSprite2D`. Builder mempertahankan pengaturan template lalu mengganti gambar Josh dengan hasil komposisi karakter.
2. **Mapping sheet dan animasi tambahan:** buka katalog karakter → **Sheets**. Setiap `CharacterSheet` mengatur `Source Sheet`, `Part Folder`, `Frame Size`, `Directions`, layer alat/ekstra. Untuk animasi tambahan tanpa template, isi `Animation Name`, `Animation Fps`, `Animation Loop`, serta folder layer. Builder membentuk nama berakhiran `_down`, `_up`, `_right`, `_left` untuk empat arah, atau satu nama untuk satu arah. Untuk animasi dasar yang memiliki source sheet, FPS/loop utamanya mengikuti SpriteFrames template.

`Source Sheet` harus cocok dengan sumber atlas template supaya frame bisa diganti oleh komposisi. `Frame Size` dan susunan baris/kolom harus sesuai gambar. Tambahan animasi di katalog hanya membuat animasi tersedia; state/controller tetap perlu memanggilnya untuk aksi baru.

Timing efek alat diatur terpisah pada **`resources/action_data/<tool>.tres`**, yang direferensikan `resources/item_data/<tool>.tres`: `Animation Name` dan `Hit Frame`. Contoh: `resources/action_data/watering_can_wood.tres`. Biaya stamina/kekuatan/kecepatan berada di **`resources/tool_data/<tool>.tres`**. Jangan hanya mengganti FPS lalu menganggap waktu impact ikut pindah ke frame yang benar. Refill penyiram memiliki animasi runtime tersendiri yang dibentuk dari frame awal water/watering pada `action_state.gd`.

Komposisi karakter dilakukan saat runtime, bukan preview penuh otomatis di editor. Setelah edit, hentikan dan jalankan ulang game untuk membersihkan cache builder. Periksa tampilan di Character Creator dan gameplay, semua arah, idle/walk/run, alat dan carry. Regresi terkait: `tests/character_animation_regression.tscn`.

## Atur batas alat per pohon/batu

Buka scene objek di `scenes/objects/`, pilih root, lalu Inspector → **Tool requirement**:

- `Resource Size`: Small = minimal Kayu; Normal = minimal Tembaga; Large = minimal Besi.
- `Minimum Tool Tier`: dapat menaikkan syarat untuk resource langka, misalnya batu emas minimal Emas.

Ukuran tersebut adalah kategori gameplay yang ditulis eksplisit, bukan tebakan dari nama atau scale. Sesuaikan sprite, collider dan kategori bersama. Scene `small_rock.tscn` dan `large_rock.tscn` mewarisi `rock.tscn`; instance lokal bisa memiliki override Inspector. Pohon spawner memakai scene kecil/dewasa masing-masing, sehingga syarat berubah saat tumbuh. Layout cleanup farm berada di `resources/world/farm_cleanup_layout.tres`; ID objek dipertahankan agar save lama tidak memunculkan kembali objek yang sudah dibersihkan.

Bijih yang dapat pulih di Forest diatur pada `scenes/world/Forest.tscn` → **OreSpawner**.
`Daily Spawn` dan `Max Active` mengatur jumlah node, bukan unit bijih. `Entrance Position`
harus mengikuti posisi masuk Forest karena dipakai untuk memilih patch spawn yang terhubung.
`small_iron_rock.tscn` merupakan endapan besi kategori normal (minimal Tembaga), sedangkan
`RockIron.tscn` tetap kategori besar (minimal Besi). Jangan mengunci seluruh sumber bahan
upgrade di belakang tier alat yang justru memerlukan bahan tersebut.


## Gua, spawn dan prefab enemy/boss

Lihat [CAVE_EDITOR_GUIDE.md](CAVE_EDITOR_GUIDE.md) untuk marker layout, pengaturan spawn/pilar, scene enemy/boss, serta prefab tangga dan lift.
