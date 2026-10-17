# Tier crafting dan unlock Nusa Vale

Tanggal: 15 Oktober 2026. Status: **usulan balancing**, belum diterapkan ke gameplay.

Rancangan berdasarkan aset lokal Farm RPG, katalog crafting aktif, data alat, mesin, dan tujuh role pada GDD bagian 13. Tier di sini berarti urutan progres, bukan ranking barang paling kuat. Semua angka EXP, milestone, serta jendela waktu perlu playtest.

## 1. Hasil pemeriksaan dan batas rancangan

- Katalog `resources/crafting/catalog.tres` berisi **26 resep**, bukan 21 seperti dokumentasi crafting lama. Saat ini belum ada syarat level/EXP pada `CraftingRecipe` atau pemeriksaan unlock di `CraftingSystem`.
- Tujuh role GDD: Farmer, Forager, Fisher, Combat, Miner, The Merchant, The Economist; masing-masing level 1–10, classless. Jangan menambahkan role Crafter wajib yang memaksa semua pemain grinding crafting.
- Sepuluh material alat/equipment tersedia: Wood, Copper, Iron, Gold, Platinum, Crimson, Frost, Shadow, Fairy, Obsidian. Keberadaan ikon/data tidak membuktikan akses material, combat, atau dungeon sudah berjalan.
- Mesin craft/placeable aktif mencakup furnace, preserves jar, dehydrator, mayonnaise maker, cheese press, loom. Butter churn dan fermentation barrel memiliki ItemData dapur, tetapi belum menjadi bangunan craft/placeable pada StructureManager.
- Workbench, anvil, sawmill, sharpening station, alchemy table, beehive, kitchen pot, butter churn, cheese press, fermentation barrel, jam maker, dan `Tear.png` tersedia sebagai sprite Work Benches. Pemetaan fungsi baru tetap harus dibuat. Nama `Tear` jangan diasumsikan mesin tertentu tanpa inspeksi visual; gunakan item loom yang sudah dipetakan proyek.
- Pagar, peti, scarecrow (`Scarescrow.png`), sumur (`Well .png`), lampu jalan, birdhouse, meja, kursi, kasur, dan lemari punya aset. Sprite sheet furniture harus dipotong dan dipetakan sebelum menjadi item individual.

## 2. Aturan utama unlock

**Unlock = level role yang sesuai + milestone aktivitas + akses bahan.** Waktu bermain di tabel adalah target pacing, bukan timer wajib. Kalender dapat memperkenalkan NPC/quest, tetapi tidur berulang dan AFK tidak boleh membuka resep.

Pemain cepat boleh tiba lebih awal; pemain santai boleh lebih lambat tanpa kehilangan resep. Hari adalah hari dalam game. Jam adalah perkiraan jam bermain aktif yang berdiri sendiri, bukan konversi pasti durasi hari game.

| Tier | Identitas | Role | Target hari | Target jam aktif | Tujuan |
|---|---|---|---|---|---|
| T0 | Starter | Lv1 | 1–3 | 0–1 | Menyimpan, menanam, mengenal crafting |
| T1 | Perintis | Lv2 | 3–7 | 1–3 | Peleburan dan produksi sederhana |
| T2 | Produktif | Lv3–4 | 7–14 | 3–7 | Pengolahan hasil dan ternak |
| T3 | Spesialis | Lv5–6 | 14–28 | 7–15 | Industri kecil dan bengkel pribadi |
| T4 | Ahli | Lv7–8 | 29–56 | 15–30 | Material langka dan ekspedisi |
| T5 | Master | Lv9–10 | 57–112+ | 30–60+ | Masterwork dan proyek akhir |

Lv5/Lv10 tetap mengikuti percabangan spesialisasi GDD. Resep inti tersedia untuk kedua cabang; perk membedakan efisiensi atau varian, agar pilihan awal tidak mengunci konten pokok permanen.

## 3. Tierlist objek dan resep

Jumlah bahan untuk **1 output**, kecuali tertulis lain. Kayu=`wood`, batu=`stone`, serat=`fiber`, batubara=`coal`; batangan memakai ID material seperti `copper_bar`. **Aktif** = resep sudah di katalog saat audit; syarat unlock tetap usulan. **Baru** = resep/fitur usulan berdasarkan aset, bukan klaim sudah playable.

### T0 — starter yang boleh tersedia sejak awal

| Barang | Resep | Unlock | Status |
|---|---|---|---|
| Peti kayu, 24 slot | 30 kayu | Tutorial simpan barang; Lv1 | Aktif |
| Workbench | 20 kayu + 10 batu | Tutorial crafting; Lv1 | Aktif |
| Pagar kayu | 4 kayu | Langsung | Aktif |
| Gerbang kayu | 6 kayu + 2 serat | Langsung | Aktif |
| Pagar batu | 4 batu | Pertama kali mengambil batu | Aktif |
| Pedang kayu | 8 kayu | Tutorial combat saat combat tersedia; Combat Lv1 | Aktif |
| Busur kayu | 10 kayu + 6 serat | Tutorial busur; Combat Lv1 | Aktif |
| Tongkat kayu | 8 kayu + 4 batu | Tutorial sihir; Combat Lv1 | Aktif |
| Helm kayu | 6 kayu + 2 serat | Combat Lv1 | Aktif |
| Armor kayu | 12 kayu + 4 serat | Combat Lv1 | Aktif |
| Celana pelindung kayu | 8 kayu + 4 serat | Combat Lv1 | Aktif |
| Sepatu kayu | 6 kayu + 4 serat | Combat Lv1 | Aktif |
| 10 anak panah kayu | 2 kayu + 1 batu | Tutorial busur | Aktif |
| Kursi sederhana | 8 kayu | Forager Lv1; craft pertama selesai | Baru; sprite Chairs |
| Meja sederhana | 16 kayu | Forager Lv1; craft pertama selesai | Baru; sprite Tables and desks |

Berikan tujuh alat kayu dasar melalui starter kit/tutorial bertahap: kapak, beliung, cangkul, penyiram, sabit, sekop, pancing. Jangan menuntut crafting alat untuk memperoleh bahan alat itu sendiri. Alat hilang harus dapat dipulihkan melalui NPC dengan biaya ringan; jangan membuat duplikasi gratis untuk dijual.

Prioritas belanja bahan awal: peti → furnace/bahan upgrade pertama → pagar/dekorasi. Workbench awal opsional karena menu inventory sudah dapat crafting. Jangan menghabiskan kayu starter untuk bangunan wajib tambahan. Senjata kayu adalah starter *cabang combat*, tidak perlu memenuhi menu awal sebelum combat berfungsi.

### T1 — mulai mengolah bahan

| Barang | Resep | Unlock spesifik | Status |
|---|---|---|---|
| Furnace | 25 batu + 10 bijih tembaga | Miner Lv2 + pecahkan 10 batu/endapan valid + temukan tembaga | Aktif |
| Peti tembaga, 36 slot | 30 kayu + 5 batangan tembaga | Forager Lv2 **atau** Economist Lv2 + pernah melebur tembaga | Aktif |
| Pedang tembaga | 3 batangan tembaga + 4 kayu | Combat Lv2 + tutorial pertarungan | Aktif |
| Armor tembaga | 5 batangan tembaga + 6 serat | Combat Lv2 + tutorial pertarungan | Aktif |
| Orang-orangan sawah | 20 kayu + 15 serat + 5 batu | Farmer Lv2 + panen 10 hasil tanaman | Baru; Scarescrow |
| Lampu kebun | 10 kayu + 2 batangan tembaga + 2 batubara | Forager Lv2 + pernah menjelajah malam | Baru; Street Lamp |

Scarecrow hanya dijadikan resep fungsional bila ancaman burung/hama benar-benar ada. Sebelum itu, labeli dekorasi dan jangan mewajibkannya pada tutorial. Lampu tidak perlu memakan batubara harian; biaya bahan di atas hanya konstruksi.

### T2 — produksi dan kebutuhan sehari-hari

| Barang | Resep | Unlock spesifik | Status |
|---|---|---|---|
| Dehydrator | 40 kayu + 30 batu + 15 serat | Forager Lv3 **atau** Farmer Lv3 + kumpulkan/panen 5 jenis bahan berbeda | Aktif |
| Preserves jar | 50 kayu + 40 batu + 8 batubara | Farmer Lv3 + panen 30 hasil tanaman | Aktif |
| Mayonnaise maker | 40 kayu + 30 batu + 2 batangan tembaga | Farmer Lv3 + kumpulkan 5 telur hasil ternak sendiri | Aktif |
| Cheese press | 50 kayu + 40 batu + 3 batangan tembaga | Farmer Lv4 + kumpulkan 5 susu hasil ternak sendiri | Aktif |
| Loom | 60 kayu + 30 serat + 2 batangan tembaga | Farmer Lv4 **atau** Forager Lv4 + peroleh wool dari ternak pertama | Aktif |
| Peti besi, 48 slot | 40 kayu + 8 batangan besi | Forager Lv4 **atau** Economist Lv4 + pernah melebur besi | Aktif |
| Pedang besi | 3 batangan besi + 4 kayu | Combat Lv3 + kalahkan 20 musuh unik spawn | Aktif |
| Armor besi | 5 batangan besi + 6 serat | Combat Lv3 + kalahkan 20 musuh unik spawn | Aktif |
| Butter churn | 40 kayu + 20 batu + 2 batangan tembaga | Farmer Lv4 + olah 10 produk susu | Baru sebagai resep bangunan; item dapur ada |
| Sumur | 80 batu + 20 kayu + 5 batangan tembaga | Farmer Lv4 + siram 100 petak-hari unik | Baru; sumber isi ulang penyiram |
| Birdhouse | 20 kayu + 10 serat | Forager Lv3 + temukan 10 forage | Baru; dekorasi habitat, tanpa klaim produksi otomatis |

Jumlah ternak/panen menghitung unit dasar, bukan menggandakan angka karena kualitas atau bonus loot. Bahan beli tetap boleh dipakai crafting, tetapi tidak menggantikan milestone pengalaman merawat ternak.

### T3 — spesialis dan bengkel

| Barang | Resep | Unlock spesifik | Status |
|---|---|---|---|
| Peti emas, 60 slot | 50 kayu + 10 batangan emas | Forager Lv5 **atau** Economist Lv5 + temukan sumber emas yang dapat ditambang | Aktif |
| Anvil | 10 batangan besi + 30 batu + 10 kayu | Miner Lv5 + selesai 3 pesanan upgrade alat | Baru; Anvil |
| Sawmill | 80 kayu + 10 batangan besi + 30 batu | Forager Lv5 + tebang 30 pohon dewasa | Baru; Sawmill |
| Sharpening station | 40 batu + 5 batangan besi + 20 kayu | Combat Lv5 + tuntaskan tantangan bengkel | Baru; Sharpening Station |
| Beehive | 50 kayu + 15 serat + 3 batangan besi | Farmer Lv5 **atau** Forager Lv5 + budidayakan 3 jenis bunga | Baru; Beehive |
| Fermentation barrel | 60 kayu + 5 batangan besi + 10 serat | Farmer Lv5 + selesaikan 30 batch pengolahan | Baru sebagai resep bangunan; item dapur ada |
| Alchemy table | 50 kayu + 20 batu + 5 batangan emas + 10 mooncap | Forager Lv6 + temukan 15 spesies forage + riset perpustakaan | Baru; Alchemy Table |
| Lemari | 40 kayu + 5 cloth | Forager Lv5 + buat cloth pertama | Baru; Closet |
| Kasur tambahan | 50 kayu + 10 cloth + 10 serat | Forager Lv5; rumah memiliki ruang | Baru; Beds; kasur starter tetap tersedia |

Fungsi anvil: membuka crafting equipment logam lanjutan; NPC tetap menyediakan upgrade alat agar role lain dapat berkembang. Sawmill: 5 kayu → 1 papan. Papan adalah **material baru**, perlu ItemData dan ikon/atlas yang dipetakan; resep mesin awal sengaja tidak memakai papan agar tidak melingkar. Sharpening station memberi buff terbatas, bukan memaksa durability/repair rutin.

Blueprint lewat proyek Sayap Karya dapat menjadi pengenalan/alternatif akses fasilitas, tetapi jangan mengunci furnace dan upgrade tembaga di balik proyek yang sendiri meminta batangan.

### T4–T5 — mastery tanpa menambah mesin serupa secara berlebihan

- T4 membuka equipment Crimson/Frost, varian dekorasi mahal, dan resep pengolahan bernilai tinggi. Mesin dasar tetap relevan; upgrade modul internal lebih baik daripada tiga mesin dengan fungsi sama.
- T5 membuka Shadow/Fairy/Obsidian dan masterwork. Aset equipment sudah ada, tetapi quest, sumber material, dan combat perlu dibuat sebelum konten ini disebut playable.
- Obsidian Lv10 harus membutuhkan tantangan penguasaan nyata; jangan hanya meminta total jam online atau uang.
- Bus, train, kendaraan gerobak dagang, dan fasilitas kota menjadi layanan/proyek dunia. Jangan semuanya dibuat sebagai barang crafting inventory.
- Kandang, barn, silo, greenhouse, restorasi balai dan jembatan tetap mengikuti layanan/proyek yang sudah ada. Jangan memberi jalur crafting murah yang melewati biaya pembangunan.

## 4. Sepuluh tier alat: resep dan role

Gunakan role alat: kapak/sekop → Forager; beliung → Miner; cangkul/penyiram/sabit → Farmer; pancing → Fisher. Ini syarat pesanan, bukan larangan memakai alat pemberian teman. Setiap upgrade mengonsumsi **alat tier sebelumnya** dan dikerjakan NPC selama **2 pergantian hari** sesuai sistem aktif.

| Material tujuan | Tier progres | Level role | Bahan per alat | Uang | Milestone usulan |
|---|---|---:|---|---:|---|
| Kayu | T0 | 1 | Starter kit; pengganti lewat NPC | — | Tutorial alat |
| Tembaga | T1 | 2 | 5 batangan tembaga + 10 kayu | 500 G | 10 aksi produktif sesuai role |
| Besi | T2 | 3 | 5 batangan besi + 15 kayu | 1.200 G | 30 aksi produktif + pernah memakai alat tembaga |
| Emas | T3 | 5 | 5 batangan emas | 2.500 G | Akses material emas + tantangan role pertama |
| Platinum | T3 | 6 | 5 batangan platinum | 4.500 G | Akses area material platinum |
| Crimson | T4 | 7 | 5 batangan crimson | 7.000 G | Selesaikan ekspedisi area Crimson |
| Frost | T4 | 8 | 5 batangan frost | 10.000 G | Selesaikan ekspedisi area Frost |
| Shadow | T5 | 9 | 5 batangan shadow | 14.000 G | Selesaikan ekspedisi area Shadow |
| Fairy | T5 | 9 | 5 batangan fairy | 20.000 G | Quest penguasaan Fairy |
| Obsidian | T5 | 10 | 5 batangan obsidian | 28.000 G | Tantangan master role + sumber Obsidian |

Shadow dan Fairy sama-sama memerlukan Lv9, tetapi milestone area/quest berbeda. Urutan material mengikuti proyek saat ini; Crimson→Frost→Shadow bukan cabang yang harus dipilih salah satu.

Bahan dan biaya tabel mengikuti pola upgrade aktif; periksa setiap ToolData sebelum implementasi massal. Resep furnace saat ini: **2 bijih material → 1 batangan**, tanpa tambahan coal pada resep tembaga/emas yang diperiksa. Coal untuk mesin tidak otomatis berarti bahan bakar furnace.

**Wajib menyelesaikan masalah akses material berikut:** batu emas sekarang mensyaratkan beliung emas. Sediakan endapan emas kecil yang bisa ditambang beliung besi atau sumber emas alternatif yang terjamin sebelum upgrade emas diminta. Terapkan prinsip sama pada tier sesudahnya. Jalur Kayu→Tembaga→Besi sudah memiliki endapan kecil pendukung; jangan merusaknya dengan gate EXP terlalu mahal.

## 5. Formula equipment lengkap dari aset

Resep kayu dan pedang/armor tembaga-besi di bagian 3 mempertahankan katalog aktif. Tabel di bawah adalah **resep baru untuk slot yang belum ada**, ditambah perluasan tier tinggi. Semua output satu kecuali panah 10. Tidak mengonsumsi equipment lama agar pemain tetap bisa membawa set cadangan.

| Slot | Resep dasar tembaga/besi | Resep Gold–Obsidian |
|---|---|---|
| Sword | 3 batangan + 4 kayu | 5 batangan tier tujuan + 4 kayu |
| Bow | 3 batangan + 10 kayu + 6 serat | 5 batangan + 10 kayu + 2 cloth |
| Staff | 3 batangan + 8 kayu + 4 batu | 5 batangan + 8 kayu + 5 mooncap |
| Helmet | 3 batangan + 2 serat | 4 batangan + 1 cloth |
| Armor/chestplate | 5 batangan + 6 serat | 8 batangan + 3 cloth |
| Leggings | 4 batangan + 4 serat | 6 batangan + 2 cloth |
| Boots | 2 batangan + 4 serat | 4 batangan + 2 cloth |
| Arrow ×10 | 1 batangan + 2 kayu | 1 batangan + 2 kayu |

Level Combat mengikuti material: Copper 2, Iron 3, Gold 5, Platinum 6, Crimson 7, Frost 8, Shadow/Fairy 9, Obsidian 10. Equipment Gold+ dibuat di anvil atau jasa NPC; jangan mewajibkan pemain Combat menaikkan Miner Lv5 sendiri. Material dapat dibeli/ditukar/dihasilkan rekan co-op.

Gems, leather, magic core, dan token boss tidak dipakai sebagai syarat wajib awal karena supply gameplay belum dibuktikan. Jika kelak dibuat, gunakan untuk varian masterwork/cosmetic, dengan sumber dan drop terjamin untuk progres utama. Jangan menganggap semua staff sudah punya sihir aktif hanya karena ikonnya tersedia.

## 6. Barang hasil pengolahan dan resepnya

Pemisahan penting: unlock mesin diperoleh dari pengalaman; resep produk terbuka saat mesin dan bahan pertama dikenali. Jangan meminta pemain memproduksi selai untuk membuka satu-satunya mesin selai.

| Tier | Produk | Resep per output | Stasiun/status |
|---|---|---|---|
| T1+ | Batangan | 2 bijih → 1 batangan; gunakan resource resep tiap material | Furnace; aktif |
| T2 | Selai strawberry | 1 strawberry → 1 strawberry_jam | Preserves jar; aktif |
| T2 | Selai blueberry | 1 blueberry → 1 blueberry_jam | Preserves jar; aktif |
| T2 | Acar mentimun/tomat | 1 cucumber/tomato → 1 pickled_cucumber/pickled_tomato | Preserves jar; aktif |
| T2 | Buah kering/kismis | 1 apple/grape → 1 dried_fruit/raisins | Dehydrator; aktif |
| T2 | Mayones | 1 chicken_egg/duck_egg → 1 mayonnaise/duck_mayonnaise | Mayonnaise maker; aktif; kualitas ikut sistem ternak |
| T2 | Keju | 1 cow_milk/goat_milk → 1 cheese/goat_cheese | Cheese press; aktif; kualitas ikut sistem ternak |
| T2 | Kain | 1 wool → 1 cloth | Loom; aktif; kualitas ikut sistem ternak |
| T2 | Mentega | 2 cow_milk → 1 butter | Butter churn; rasio usulan, sesuaikan database dapur |
| T3 | Madu | 1 sunflower + siklus produksi → 1 honey | Beehive; mekanik baru; bunga dikonsumsi sebagai input awal sederhana |
| T3 | Papan | 5 wood → 1 papan | Sawmill; material baru |
| T3 | Shoyu | 3 adzuki_bean + 1 salt → 1 shoyu | Fermentation barrel; pendekatan bahan game, resep usulan |
| T3 | Yogurt | 2 cow_milk → 1 yogurt | Fermentation barrel; resep usulan |
| T3 | Ramuan stamina kecil | 2 common_mushroom + 1 chamomile → 1 ramuan | Alchemy table; output/ItemData baru, ikon Potions perlu dipetakan |

Resep dapur yang sudah dikerjakan terpisah harus tetap menjadi sumber kebenaran saat diintegrasikan. Jangan menimpa resep masakan hanya agar cocok tabel ini. Durasi mesin aktif kini sangat singkat (sekitar 3,5–20 detik); sebelum memperbanyak mesin, uji keuntungan per hari agar pemain tidak mencapai ekonomi akhir hanya dengan spam mesin pertama.

## 7. EXP dan pengalaman yang layak dihitung

Usulan ambang EXP **kumulatif per role**, level mulai 1: Lv1=0; Lv2=100; Lv3=300; Lv4=700; Lv5=1.400; Lv6=2.400; Lv7=3.800; Lv8=5.600; Lv9=8.000; Lv10=11.000. Ini baseline balancing, bukan formula yang sudah ada.

| Role | Sumber EXP usulan | Pencegahan farming palsu |
|---|---|---|
| Farmer | Panen 6–12/unit dasar; perawatan ternak 3/hewan-hari; hasil ternak 8 | Siram/cangkul hanya 1 EXP per petak per hari; pengulangan tidak memberi EXP |
| Forager | Forage 5; pohon dewasa 12; titik gali 8 | Hanya objek dunia yang benar-benar habis/berubah |
| Fisher | Tangkapan sukses 10/20/35 sesuai kelangkaan | Tidak memberi EXP untuk batal lempar, melepas-menangkap item yang sama |
| Miner | Batu 4; endapan bijih 8–16 | Menempatkan lalu menghancurkan barang sendiri tidak memberi EXP |
| Combat | Musuh kalah 10–30; boss pertama 150 | Tanpa EXP dari memukul target kebal, teman, atau dummy berulang |
| Merchant | Pesanan pelanggan selesai 20–50; transaksi bermargin nyata 2–10 | Beli-jual balik item tidak boleh menjadi loop EXP menguntungkan |
| Economist | Kontrak terpenuhi 30–80; milestone kontribusi balai 50–150 | Pindah saldo/donasi lalu refund tidak memberi EXP; hindari EXP murni per uang |

Crafting bahan massal tidak memberi EXP utama tanpa batas. Bonus discovery sekali per resep boleh memberi 10 EXP ke role terkait. Target sekitar 70–120 EXP per hari fokus pada awal permainan; validasi agar Lv2 tercapai di sesi pertama dan Lv5 membutuhkan beberapa siklus kegiatan.

Skill level menjawab penguasaan; milestone menjawab pengalaman yang bervariasi. Pemain yang memanen 500 tanaman sama sebaiknya tidak otomatis membuka semua mesin, bunga, ternak, dan fermentasi sekaligus.

## 8. Co-op, UI, dan save

- Level/EXP milik setiap pemain; blueprint bangunan yang ditemukan dibagikan ke rumah tangga. Satu Farmer ahli boleh membuat mesin untuk semua; pemain lain boleh memakai mesin tanpa mengulang syarat level.
- Equipment yang sudah dibuat boleh dipakai rekan tanpa syarat level tambahan. Pembuat/pemesan tetap harus memenuhi gate. Kekuatan ekstrem dapat diseimbangkan lewat kebutuhan area, bukan membatalkan hadiah co-op.
- P2–P4 yang baru bergabung tidak perlu menunggu kalender pribadi. Progres dunia bersama tetap terbuka, EXP pribadi mulai dari aktivitasnya; buku studi bisa menjadi jalur mengejar sesuai GDD.
- Recipe terlihat sebagai siluet satu tahap sebelum unlock; tampilkan syarat nyata seperti “Farmer Lv3 · panen 18/30”, bukan hanya ikon gembok. Tier jauh tampil di indeks koleksi agar menu awal tidak penuh.
- Tutorial menampilkan 5 resep utilitas inti; equipment muncul pada pengenalan combat. Daftar selanjutnya terbuka sesuai aktivitas pemain.
- Inventory tetap dapat membuat T0–T2. Workbench menjadi akses nyaman; anvil/alchemy adalah stasiun untuk kategori lanjutan. Hindari workbench wajib untuk membuat workbench itu sendiri.
- Gate harus diperiksa pada preview **dan** commit craft, pesanan NPC, upgrade peti, dan jalur produksi relevan; menyembunyikan tombol saja tidak cukup.
- Simpan `role_xp`, milestone, blueprint personal/shared, dan discovery. Migrasi save lama harus mempertahankan semua barang/mesin dan resep yang pernah dibuat. Jangan membuat pemain lama kehilangan akses terhadap mesin yang sudah dipasang.

## 9. Prioritas penerapan

1. Implementasikan unlock dan EXP untuk resep yang sudah aktif; mulai T0–T2 dan jalur tiga material pertama. Pertahankan resep/biaya aktif selama playtest awal.
2. Pastikan supply wood, stone, fiber, coal, copper, iron, dan emas kecil memiliki jalur yang tidak melingkar. Prioritaskan furnace dan satu upgrade sebelum menambah sink bahan awal.
3. Uji solo dan 2–4 pemain: waktu peti pertama, furnace pertama, pesanan tembaga, mesin pertama, serta cadangan uang untuk bibit ulang.
4. Tambahkan objek berfungsi nyata: sumur, beehive, butter churn/fermentation yang terintegrasi dapur, kemudian sawmill/anvil/alchemy.
5. Aktifkan T4–T5 setelah sumber material, area, dan tantangan role tersedia. Jangan menjadikan data equipment sebagai bukti combat/dungeon selesai.

Rujukan lokal: `resources/crafting/catalog.tres`, `scripts/resources/crafting_recipe.gd`, `scripts/system/crafting_system.gd`, `scripts/system/tool_upgrade_manager.gd`, `resources/tool_data/`, `autoload/structure_manager.gd`, `resources/furnace/`, `resources/preserves_jar/`, `resources/dehydrator/`, `docs/GDD.md`, `docs/TOOL_PROGRESSION.md`, dan `docs/EARLY_PROGRESSION_AUDIT_2026-10-15.md`.

