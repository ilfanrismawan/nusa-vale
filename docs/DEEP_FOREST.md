# Deep Forest

## Mengedit scene di Godot

Buka `res://scenes/world/DeepForest.tscn`. Layout sudah disimpan sebagai node native dalam `.tscn`; runtime tidak membangun ulang map.

- `BaseLayerGround`, `RiverBanks`, `ForestPaths`, `MossyCliffs`, dan `Water`: edit tile dengan TileMap editor.
- `YSortEntities`: pindahkan pohon, batu, jembatan, altar, dan properti lainnya. Pohon panen memakai script Choppable dan mempertahankan ID penyimpanan.
- `Collision/Water`, `Collision/Cliffs`, dan `Collision/MapBounds`: sesuaikan CollisionShape2D saat mengubah sungai, tebing, atau batas map.
- `ResourceSpawnMask`: nyalakan Visible sementara untuk mengecat area resource, lalu sembunyikan kembali. Layer ini otomatis disembunyikan saat bermain. Tile mask memakai koordinat ground; area tanpa ground atau yang tertutup `ForestPaths` tidak dipakai untuk spawn.
- `ForageSpawner`, `WeedSpawner`, `TreeSpawner`, `DigSpotSpawner`, `OreSpawner`: ubah `daily_spawn`, `max_active`, dan pengaturan lainnya di Inspector.
- `ReturnToForest`: edit posisi pintu, collision, dan label. `Player`: edit posisi awal pemain untuk menjalankan scene langsung.
- `res://scenes/objects/deep_forest_tree.tscn` dan `small_deep_forest_tree.tscn`: asset pohon regenerasi yang bisa diedit terpisah.

Konversi dilakukan lewat headless Godot dengan `tools/bake_deep_forest.tscn`. Generator ditahan jika `.tscn` sudah ada. Jangan jalankan dengan `-- --overwrite` kecuali ingin mengganti seluruh edit manual dengan layout generator awal. `deep_forest_layout.gd` hanya digunakan oleh tool konversi, bukan saat gameplay.

Masuk lewat gerbang di selatan Forest (520, 720), tekan E. Keluar melalui gerbang utara Deep Forest; kembali ke Forest (520, 680).

Unlock permanen melalui UnlockManager: Forest sudah terbuka, 3.000G, 150 Kayu, 75 Batu dari tas pemain yang berinteraksi. Semua syarat diperiksa sebelum pembayaran; masuk berikutnya gratis. Unlock tersimpan dengan data unlock yang sudah ada, save lama tetap mengunci area baru.

Peta 100 × 80 tile (1.600 × 1.280 px), sekitar 2,9 kali luas Forest (896 × 800 px). Jalur melingkar berkelok dengan cabang menuju altar tua, dua jembatan di sungai barat, dan kolam air terjun di timur. Gerbang akar di utara menandai jalan pulang. Lima area terbuka menyediakan tempat panen di antara rimbunan pohon, batu berlumut, jamur besar, pilar, dan tebing.

Layout memakai asset milik proyek: `Tree Deep Forest`, tileset Grass/Water/Cliff Deep Forest, `Deep Forest Waterfall`, dan properti dalam `objects/exterior/Deep Forest`. Tanah memakai detail shader yang sudah ada. Pohon panen dan pohon hasil regenerasi memakai sprite Deep Forest sepanjang musim. Pohon awal menghasilkan 8 kayu, pohon hasil spawn 5 kayu saat dewasa. Pohon dekorasi membentuk batas rimbunan dan tidak bisa ditebang.

Resource hanya muncul di area terbuka, menjauhi jalan utama dan jembatan. Item save versi layout lama dipindahkan ke area panen bila posisinya kini berada di sungai, tebing, atau rimbunan. Tes rute menggunakan collision aktual untuk memastikan pintu keluar, altar, kedua jembatan, serta area panen saling terhubung.

| Resource | Baru/hari | Kapasitas |
| --- | ---: | ---: |
| Forage | 10 | 40 |
| Titik gali | 5 | 16 |
| Bijih | 4 | 20 |
| Pohon muda | 4 | 28 |
| Rumput liar | 6 | 30 |

Forage sepanjang musim: Jamur Rembulan (eksklusif, harga jual 180G, bobot 1) dan wild berry (bobot 0,7). Titik gali menghasilkan 1–2 truffle (250G/unit) sepanjang musim. Bijih: 65% besi, 35% tembaga, 5 unit/node. Resource memakai ForageManager untuk persistensi, batas kapasitas, dan pemulihan save; keluar-masuk pada hari sama tidak menghasilkan loot baru.

Potensi nominal harian jamur sekitar 1.059G (10 × 1/1,7 × 180), ditambah 1.250–2.500G truffle jika seluruh titik gali dipanen. Ini potensi sebelum stamina, waktu perjalanan, dan kapasitas tas; bukan pendapatan yang dijamin. Biaya unlock mendorong eksplorasi lanjutan dengan hasil yang bisa menutup investasi dalam beberapa kunjungan.

Validasi: `tests/deep_forest_regression.tscn`, jalankan dengan `NUSA_SAVE_AUDIT=1` dan APPDATA sementara agar tidak memakai save pemain.
