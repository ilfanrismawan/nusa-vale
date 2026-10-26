# Nusa Vale — Game Design Document (GDD)

Versi dokumen: 3.36 (26 Oktober 2026).
Dokumen ini adalah **sumber kebenaran desain** proyek `E:\nusa-vale` (Game Design Document resmi).
Pada versi 1.9, ditambahkan 4 pilar fundamental Life-Sim / Farming RPG: **Sistem Peternakan & Satwa** (kandang Barn/Coop, sapi, kambing, domba, ayam, bebek, kuda, pakan & affection), **Mesin Pengolah Pasca-Panen (Artisan Goods)** (mayones, keju, selai, fermentasi keg, tenun, pengasap ikan), **Sistem Cuaca Harian Dinamis** (cerah, hujan penyiram otomatis, badai petir penangkal baterai, salju), serta **Sistem Sosial, Persahabatan, & Jadwal Harian NPC** (hati 0-10, sistem hadiah loved/hated, rutinitas harian, heart events, dan romansa/teman sekamar).

## Cara membaca dokumen ini

Setiap angka atau aturan desain diberi label:

- **[terpasang]**: implementasi tersedia di kode/Resource dan memiliki jalur integrasi. Label ini tidak otomatis berarti lulus tes terkini atau selesai playtest; batas fitur dan bukti verifikasi disebutkan terpisah.
- **[keputusan]**: sudah diputuskan oleh pemilik proyek (menjadi spesifikasi wajib yang harus diimplementasikan).
- **[usulan]**: ide lanjutan yang masih terbuka untuk penyempurnaan detail teknis lebih lanjut.

---

## Status implementasi hasil audit — 22 Oktober 2026

**Area Ranch Eep — 24 Oktober 2026 [terpasang]:** `scenes/world/eep_ranch.tscn` menghubungkan Farm di utara dan Town di barat. Rumah sekaligus toko Eep tersedia di `scenes/world/interior/eep_home.tscn`, dengan jadwal merawat padang saat cerah, berteduh saat hujan, berjualan, makan dan tidur di rumah. Toko melayani pembelian ternak serta pakan/peralatan; ID sosial dan flag cerita Eep dipertahankan. Rincian scene, akses dan verifikasi: [EEP_RANCH.md](EEP_RANCH.md).

**Tindak lanjut NPC — 24 Oktober 2026 [terpasang sebagai baseline konten]:** seluruh 13 warga (termasuk tujuh profil sosial lama dan Prof. Baskoro) kini memakai database resident terpusat. Data dasar, ulang tahun, hadiah, jadwal default/hujan, dialog hati, lima milestone dialog per NPC (65 total), serta reward surat untuk seluruh warga tersedia. Instance lama yang menduplikasi Wira/Bima di Town dilepas; Baskoro memakai presenter Universitas. Kedai Zarathia dan makanan Joko terhubung ke sistem toko. Portrait khusus si kembar/Ubay sudah digunakan; artwork lain, rumah pribadi, rutinitas musim/festival, pilihan dialog/sinematik dan romansa lanjutan tetap belum lengkap. Metadata/kisah baru adalah baseline editorial yang dapat ditinjau, bukan konfirmasi kanon pemilik. Rincian perubahan, verifikasi dan kekurangan terkini: [NPC_CENTRALIZATION_2026-10-24.md](NPC_CENTRALIZATION_2026-10-24.md). Ringkasan audit 22 Oktober berikut tetap menjadi riwayat baseline sistem lain; status NPC terbaru mengikuti laporan tindak lanjut ini.

Proyek berada pada **alpha dengan banyak sistem inti terpasang**. Audit ini membaca kode, scene, Resource, konfigurasi proyek, data NPC, runner dan tes pada workspace aktif, termasuk perubahan yang belum di-commit. Jumlah file/data tidak menunjukkan persentase penyelesaian atau kesiapan rilis.

Ringkasan berikut menjadi acuan status terkini. Angka dan keputusan desain di bagian rinci tetap berlaku kecuali diberi koreksi implementasi. Hasil audit 15–20 Oktober adalah riwayat, bukan bukti pengujian kode terbaru. Inventaris audit awal ada di [AUDIT_GDD_2026-10-22.md](AUDIT_GDD_2026-10-22.md); tindak lanjut akses HerbalHouse, kunci hati, rumah tangga/surat, serta Role dijelaskan di [IMPLEMENTATION_SOCIAL_ROLE_2026-10-22.md](IMPLEMENTATION_SOCIAL_ROLE_2026-10-22.md).

**Playtest pemilik — LULUS / SELESAI (22 Oktober 2026):** pemilik proyek mengonfirmasi bahwa prioritas stabilitas dan playtest loop inti solo/co-op sudah dilakukan dan lulus. Jangan merekomendasikan ulang milestone ini sebagai pekerjaan yang belum selesai. Pengujian berikutnya difokuskan pada perubahan baru atau bug/regresi konkret. Acuan lintas dokumen: [PLAYTEST_STATUS.md](PLAYTEST_STATUS.md). Prioritas aktif berikutnya: **balancing progres dan ekonomi**, kemudian kelengkapan konten serta fitur yang belum terpasang.

**Baseline balancing 22 Oktober 2026 [terpasang]:** modal tanam dipertahankan setelah upgrade Tembaga, biaya tas/rumah bertahap, target stamina 200 tercapai, EXP aktivitas diselaraskan, nilai 137 resep cooking diaudit (136 harga diubah), selisih jual kembali bibit mencegah loop EXP tanpa biaya, serta serangan gua diselaraskan terhadap DEF equipment. Detail angka, asumsi simulasi kas solo/co-op dan bukti tes terarah: changelog GDD 3.30 (bagian 19) dan laporan `tools/balance_audit.py`; file laporan terpisah tidak pernah dibuat. Celah sistem setelah baseline ini: [AUDIT_2026-10-26.md](AUDIT_2026-10-26.md). Kelulusan playtest umum pemilik di atas tetap berlaku; ini bukan pembukaan ulang milestone tersebut.

**Tingkat bukti:** “kode/data” berarti telah diperiksa secara statis; “lulus tes” hanya berlaku untuk tes dan run yang disebutkan; “playtest” memerlukan pemeriksaan permainan nyata. Tes headless tidak membuktikan kualitas visual, gamepad fisik, balancing, atau alur panjang solo/co-op.

**Verifikasi 22 Oktober:** validator NPC dan konfigurasi rumah tangga lulus tanpa error/warning. Tindak lanjut telah menjalankan regresi Town/HerbalHouse, Role EXP, seluruh cabang Role, NPC Story, Household, Skill Tree UI, House dan Gathering dengan marker `failures=0`; hasil suite terkait dan batas verifikasi dicatat dalam laporan implementasi. Error sertifikat Windows pada run awal kini dapat ditoleransi secara eksplisit lewat opsi runner `-AllowCertificateStoreWarning`, tanpa mengabaikan error script/assertion atau error Godot lainnya. Bukti otomatis ini tidak menyatakan full suite lulus. Status playtest manual pemilik dicatat terpisah pada konfirmasi di atas; rincian perangkat dan platform tidak ditambahkan.

**Aturan gameplay terbaru [terpasang]:**

- Penyiraman pada tanah cangkul memakai stamina sekali per aksi sesuai tier (minimum 1) dan satu air per petak yang dituangi, termasuk petak yang sudah basah karena hujan/penyiraman sebelumnya. Tangki kosong, tanah tidak valid, atau stamina tidak cukup tidak menghabiskan air/stamina. Refill memakai biaya tersendiri sekali pada impact animasi.
- Tanah cangkul tanpa crop kembali menjadi ground pada pergantian hari berikutnya, baik basah maupun kering. Tanah dengan crop tetap ada meskipun belum disiram. Data di area yang tidak sedang dikunjungi juga dibersihkan; hasil tersimpan setelah save. Tanah bekas tanaman yang baru layu saat pergantian musim mengikuti pembersihan pada pergantian hari berikutnya.
- Kapak/Beliung Kayu hanya untuk kategori objek kecil; Tembaga membuka normal; Besi membuka besar. `Resource Size` dan `Minimum Tool Tier` dapat diatur di Inspector root objek. Syarat tier langka dapat lebih tinggi: batu emas minimal Emas. Menolak alat lemah tidak merusak objek atau memakai stamina.
- Pine/Birch/Maple dewasa memakai kategori normal; Mahogany/Deep Forest dewasa besar. Pohon muda dan serpihan kayu tetap dapat dipanen alat Kayu. Batu kecil/normal/besar tersedia dalam scene tersendiri; layout cleanup memakai ketiganya dengan ID save yang sama. Batu tembaga tetap dapat ditambang dengan Kayu, batu besi memerlukan Besi.

Panduan editor resep, karakter, animasi dan syarat objek: [EDITOR_GUIDE.md](EDITOR_GUIDE.md).

**Progres awal (2.7) [terpasang]:** Forest memiliki sumber bijih yang pulih 2 node/hari, kapasitas 10, enam node pada kunjungan pertama. Tembaga dapat ditambang dengan Kayu; endapan besi kecil memerlukan Tembaga dan membuka jalan menuju alat Besi. Spawn bijih dibatasi ke patch yang terhubung dari pintu masuk dengan alat awal. Tiga batu dekat rumah menjadi kecil untuk mencukupi akses bahan jembatan + Furnace; ID save dipertahankan. UI upgrade menampilkan kekuatan, kategori objek, dan sisa saldo. Harga serta biaya proyek tidak berubah. Audit cashflow, metode rute dan batas verifikasi ada di [EARLY_PROGRESSION_AUDIT_2026-10-15.md](EARLY_PROGRESSION_AUDIT_2026-10-15.md).

| Sistem | Terpasang | Batas implementasi |
|---|---|---|
| Loop inti | Farming, inventory, toko, shipping esok hari, crafting, alat, save | Playtest loop inti solo/co-op lulus menurut pemilik; balancing progres/ekonomi menjadi prioritas berikutnya |
| Peternakan | Ayam, bebek, sapi, kambing, domba, kerbau, kapibara, kuda tunggangan; perawatan, kualitas, merumput, interior, upgrade; pembiakan Barn, Inkubator, bulu bebek | Sprite kuda/kerbau/kapibara masih placeholder hasil recolor sapi; festival, ayam jago dan layanan kesehatan berbayar belum ada |
| Pengolahan | Furnace, Mayonnaise Maker, Cheese Press, Loom, Preserves Jar, Dehydrator, Beehive, Sawmill, Keg, Oil Maker, Fish Smoker, Penangkal Petir; stasiun Alchemy Table dan Anvil | Mesin olahan artisan lengkap dan teruji di runner; penuaan Cellar masih target |
| Dunia | Farm, rumah, Forest, Deep Forest, Town, Balai Nadi, Greenhouse, Gunung dan Gua Tambang 1–100 | Pohon buah permanen lintas musim terpasang; Pantai dan Modern City masih target |
| Town/NPC | Bangunan/interior, jadwal/rute, layanan, hadiah, panel hubungan, dialog bersyarat hati/flag; heart event, surat cerita, status dating/married, upacara dasar, pasangan/roommate tinggal di rumah, bantuan harian, surat resep/bingkisan | Upacara dasar berupa dialog di rumah; sinematik khusus dan bouquet/pendant masih target; reward seluruh 13 warga terpasang sebagai baseline 24 Oktober |
| Cuaca | Cerah, Hujan, Badai Petir (Thunderstorm) dengan kilat prosedural & penangkal petir Battery Pack; menyiram outdoor otomatis | Salju/blizzard masih target; cuaca belum bergantung musim. Prakiraan besok tersedia di TV rumah (`scripts/ui/television_ui.gd`) |
| Cooking | 137 Resource resep, 22 Resource alat masak, database resep, buku per pemain, dapur rumah, stamina/HP, buff laju dan regenerasi HP | Hitungan data bukan bukti semua resep bisa diakses; kanal memasak TV mengajarkan resep; buff lanjutan perlu implementasi/verifikasi; hadiah resep sosial terpasang untuk 13 resident |
| Biji Daya | Tiga sumber unik memberi +30 stamina; rumah Lv2 +30 dan Lv3 +40, maksimum individu 200 | Biji tetap per karakter; penghuni tanpa Biji Daya mencapai 170 dengan rumah penuh |
| Fishing | Minigame, lokasi, jam, musim ikan, air beku musim dingin, kolam air panas Gunung, danau gua lantai 10 | Pantai (`beach_sea`) belum punya scene |
| Co-op | Lokal split-screen 2–4 pemain | Playtest solo/co-op lulus menurut pemilik; perubahan baru diuji sesuai dampaknya |
| Konten lanjutan | Data equipment, HP per pemain, combat dasar (pedang/busur/tongkat), musuh dengan AI kejar/serang, denda tumbang lewat Klinik, Gunung + Gua Tambang lantai 1-100, lima boss, pemanah/penyihir, lift dan Toko Combat | musik boss orkestra (belum dibuktikan), bazaar, festival, ekonomi dinamis belum terpasang |
| Role/EXP | Tujuh role Lv1–10 per karakter, EXP aktivitas, level setelah tidur, cabang, buku riset, Token Talenta, UI keahlian | Kurir Logistik, Forest Whisperer, Bintang Perak, Bintang Emas, dan Perpetual Orchard aktif; 7 perk bergantung sistem lanjutan masih “Segera hadir” |
| Audio/horor | Autoload MusicManager, aset BGM area/siang/malam/hujan/tengah malam, crossfade; NightHorror dan data kejadian | Belum ada playtest audio sesi ini; bukan bukti musik boss orkestra selesai |

Koreksi acuan implementasi:

- Viewport aktif `project.godot`: **1280 × 720**, window awal 1280 × 720; angka 960 × 540 di tabel lama sudah kedaluwarsa.
- `SAVE_VERSION = 26` di `autoload/save_manager.gd` (v26: pembiakan, inkubator dan bulu bebek, bagian 4.10.11). Riwayat v17 rumah, v18 gathering/tapper, v19 hubungan NPC, v20 aksesori/mesin, v21 roster co-op, v22 Role & EXP tetap berlaku. Format saat ini juga menyimpan `npc_progress` (flag, event selesai, romansa, surat dan household) serta `friendships.<npc>.locked` per karakter. Shipping menyimpan histori pembayaran kurir. Save lama memperoleh default kosong; hubungan lama yang masih maksimum dikunci saat dibaca. Riwayat pernah maksimum tetapi sudah turun sebelum v25 tidak dapat dipulihkan dari data yang tidak pernah disimpan.
- Stamina awal 100, maksimum pemain dapat naik melalui Biji Daya. Detail transaksi dan persistensi: [BIJI_DAYA.md](BIJI_DAYA.md).
- Pingsan batas waktu pada 05:10 memulangkan pemain, bangun 08:00 dengan 50% kapasitas stamina; pemain co-op yang sudah tidur pulih penuh. **Tidak memotong uang atau item**. Denda medis karena HP habis (bagian 4.2 dan 8.1) terpasang terpisah sejak Phase 4B-1.
- Shipping dibayar saat pergantian hari melalui `ShippingManager.settle`, ke saldo bersama dan ringkasan pendapatan. Dengan Economist Lv6 Kurir Logistik, kas dibayar pada 12.00 dan 17.00; sisa kiriman dibayar esok pagi. Ringkasan pagi juga memuat kiriman yang sudah dibayar, tanpa membayar ulang.
- Restorasi Balai Nadi membutuhkan **100 kayu + 50 batu + 500 G**; Greenhouse 150 kayu + 75 batu + 5 copper_bar. Akses Balai dari town sudah terpasang.
- `DailyWeather`: hari pertama cerah; berikutnya peluang hujan 30% berdasarkan seed tersimpan. Desain lima cuaca di bagian 4.1 belum seluruhnya tersedia.
- Deep Forest sudah terpasang di `scenes/world/DeepForest.tscn`: akses Forest + 3.000 G + 150 kayu + 75 batu untuk unlock permanen. Area gathering ini bukan dungeon combat. Lihat [DEEP_FOREST.md](DEEP_FOREST.md).
- Mesin berbasis detik aktif berhenti saat pause dan tidak mendapat catch-up tidur/offline. **Pengecualian: Beehive memakai siklus hari permainan, menghasilkan madu/lilin tiap 3 hari dan dijeda saat musim dingin.** Lihat [PROCESSING_AUDIT.md](PROCESSING_AUDIT.md).
- Usulan peternakan pada bagian 4.10 yang telah diwujudkan mengacu pada aturan aktual [LIVESTOCK_CORE_LOOP.md](LIVESTOCK_CORE_LOOP.md); angka historis bukan spesifikasi kedua.

Prioritas aktif setelah konfirmasi pemilik: balancing progres/ekonomi → kelengkapan konten pada sistem yang tersedia → farming/produksi dan sistem pendukung perk → sosial serta eksplorasi/combat → perluasan dunia. Milestone playtest loop inti solo/co-op sudah lulus dan tidak menjadi pekerjaan awal lagi. Pengujian perubahan baru tetap mengikuti dampaknya; rekomendasi lama yang meminta pengulangan playtest umum digantikan oleh [status playtest terkini](PLAYTEST_STATUS.md).

---

## 1. Ringkasan

| Hal | Nilai | Status |
|---|---|---|
| Genre | Farming RPG 2D pixel art, tampak atas (top-down) | [terpasang] |
| Engine | Godot 4.7, renderer GL Compatibility, GDScript | [terpasang] `project.godot` |
| Viewport | 1280 x 720, window awal 1280 x 720, stretch `canvas_items`, skala fractional | [terpasang] |
| Ukuran tile | 16 px | [terpasang] |
| Filter tekstur | Nearest (pixel art tajam) | [terpasang] |
| Bahasa | Default teks UI, dialog, notifikasi, dan `display_name` item berbahasa **Indonesia**; ke depannya mendukung opsi pilihan bahasa (Indonesia & Inggris) di Pengaturan; `item_id` tetap snake_case Inggris | [keputusan] |
| Pemain | 1 pemain, atau co-op lokal split screen 2-4 pemain; pemain bisa ikut/keluar di tengah permainan (4.14) | [terpasang] |
| Aset utama | Farm RPG Tiny Asset Pack + gambar tambahan dengan palet `Paletta.png` | [terpasang] |
| Scene awal | `scenes/ui/main_menu.tscn` | [terpasang] |

### Premis dan Storytelling [keputusan]
- **Awal Mula**: Pemain tiba di desa terpencil bernama **Nusa Vale** untuk mengelola sebidang tanah pertanian keluarga yang lama terbengkalai. Desa ini dulunya makmur, namun fasilitas umum rusak, jembatan ke Hutan ambruk, Greenhouse hancur, dan Balai Nadi kehilangan denyut kehidupannya.
- **Perjalanan Restorasi**: Melalui kerja keras bertani, memancing, menambang, dan gotong royong menyumbangkan bahan ke Balai Nadi, pemain memulihkan satu per satu fasilitas desa (Jembatan Hutan, Greenhouse, Balai Nadi, bengkel Blacksmith, Warung Makan, dan Klinik).
- **Misteri Gua & Gunung**: Demi mendapatkan mineral langka dan logam mulia tingkat tinggi (Emas hingga Obsidian), pemain harus membuka akses ke kawasan Gunung dan menaklukkan Gua tambang yang dihuni berbagai monster liar, dibantu oleh perlengkapan tempur dari Combat Shop / Adventurer Guild.
- **Visi Endgame — "Endless Game" & Ekspansi Modern City**: Nusa Vale dirancang sebagai game tanpa akhir (*endless game*). Setelah desa Nusa Vale sepenuhnya pulih, makmur, dan mandiri, cerita tidak tamat; pemain akan membuka jalur transportasi baru (stasiun kereta / pelabuhan) menuju **Kota Modern (Modern City)**. Di kota modern ini terbuka konten late-game baru: pasar komoditas skala besar, peralatan canggih berteknologi tinggi, kendaraan modern, apartemen, serta peluang ekonomi baru.

---

## 2. Core Loop

### Loop Harian [terpasang + keputusan]
1. Bangun di rumah jam 06:00 dengan stamina penuh (atau jam 08:00 jika pingsan).
2. Cangkul, tanam bibit musiman (termasuk tanaman khusus musim dingin), siram air; tebas rumput liar dengan sabit.
3. Kumpulkan sumber daya alam: tebang pohon (kayu), tambang batu/bijih di Hutan & Gua, pungut tanaman forage, gali titik cacing, atau memancing.
4. Jual hasil di **Shipping Bin** (barang diambil oleh NPC kurir di sore hari atau pembukuan uang diterima keesokan paginya saat tidur) atau langsung di toko.
5. Manfaatkan bengkel & crafting: lebur bijih di Furnace, rakit peralatan/bangunan di meja crafting, atau bawa alat ke Blacksmith kota untuk di-upgrade (ditinggal 1–2 hari pengerjaan).
6. Eksplorasi malam diperbolehkan sampai 05:00 dengan kabut, ambience horror, rasa takut, dan kejadian ganjil setelah tengah malam di luar ruangan (lihat 4.1, Horor Tengah Malam). Tidur di kasur paling lambat 05:00 (hari baru + simpan otomatis). Pada tick 05:10 pemain terjaga **pingsan**, dipulangkan, dan bangun 08:00 dengan stamina 50%; pemain co-op yang sudah berbaring pulih penuh. Tidak ada kehilangan item akibat batas waktu.

### Loop Jangka Menengah [terpasang + keputusan]
- Memperbaiki jembatan rusak (100 kayu + 50 batu) untuk membuka Hutan.
- Kontribusi proyek restorasi Balai Nadi (pemulihan Balai Nadi & pembukaan Greenhouse 32 petak lintas musim).
- Menanam dan merawat pohon buah permanen lintas musim.
- Meningkatkan tier perlengkapan kerja (Kayu $\rightarrow$ Tembaga $\rightarrow$ Besi $\rightarrow$ Emas dst.).
- Membuka akses Gunung dan lantai Gua untuk menambang mineral langka.

### Core Loop Peternakan [terpasang + keputusan + usulan]

**Cek kebutuhan → sediakan pakan → rawat hewan dan kandang → kumpulkan hasil → jual/olah/sumbangkan → tambah cadangan dan tingkatkan kandang → ulangi esok hari.**

- **Pagi**: kunjungi kandang, ambil hasil perawatan kemarin, cek hewan yang belum makan atau belum dielus. Pakan dan mengelus ayam melalui menu kandang sudah [terpasang].
- **Sepanjang hari**: penuhi satu jatah pakan per hewan dan bangun kasih sayang [keputusan]; merumput, menyikat, membersihkan kandang, serta menangani kondisi kurang sehat menjadi rincian lanjutan [usulan] pada bagian 4.10.
- **Sore**: tentukan hasil untuk penjualan, bahan masakan, atau mesin pengolah [keputusan]; periksa cadangan pakan untuk hari berikutnya [usulan].
- **Pergantian hari**: evaluasi perawatan hari yang selesai, hasilkan produk sesuai spesies dan kondisi, lalu buka kembali kebutuhan harian. Ayam kenyang menghasilkan telur; ayam lapar tidak menghasilkan telur [terpasang].
- **Tujuan jangka menengah**: punya kawanan kecil yang terawat dan pemasukan rutin sebelum memperbesar kapasitas; upgrade membantu pekerjaan berulang sekaligus membuka spesies baru [usulan].

Spesifikasi terperinci dan batas antara fitur terpasang dengan rancangan lanjutan ada di **bagian 4.10.1–4.10.8**.

### Loop Jangka Panjang & Endgame [keputusan]
- Memasak makanan berbuff di dapur rumah atau Warung Makan.
- Menjelajahi lantai-lantai terdalam Gua Dungeon, menghadapi monster dengan kombinasi senjata dan armor late-game dari Toko Combat.
- Membeli kendaraan (sepeda dan sapu terbang) untuk mobilitas tinggi.
- Membuka rute ekspansi ke **Modern City** setelah seluruh desa Nusa Vale pulih seutuhnya.

---

## 3. Dunia dan Area

| Area | Scene | Isi | Status |
|---|---|---|---|
| Farm | `scenes/world/farm.tscn` | Rumah, Greenhouse (32 petak), papan proyek Balai Nadi, Shipping Bin, ShopCounter, Broken Bridge, 2 FishingSpot (`farm_pond`, `farm_river`), pohon, batu, forage, titik gali | [terpasang] |
| Rumah (interior) | `scenes/world/interior/interior_house.tscn` | Kasur tidur, lemari Wardrobe, dapur memasak, pintu keluar | [terpasang + keputusan] |
| Greenhouse (interior) | `scenes/world/interior/greenhouse.tscn` | 32 petak tanam lintas musim; terbuka setelah proyek Greenhouse selesai | [terpasang] |
| Balai Nadi | `scenes/world/balai_nadi/exterior.tscn`, `interior.tscn` | Gedung permanen di Kota dengan pintu masuk permanen; meja kontribusi proyek restorasi desa | [terpasang + keputusan] |
| Hutan (Forest) | `scenes/world/Forest.tscn` | Pohon spawn, batu tembaga, batu besi, forage musiman, rumput liar, titik gali, sungai hutan | [terpasang] |
| Kota (Town) | `scenes/world/town.tscn` | Toko General Store, Sekolah, Universitas, Blacksmith (Pandai Besi), Warung Makan, Klinik, Balai Nadi permanen, rumah warga | [terpasang + keputusan] |
| Gunung (Mountain) | `scenes/world/mountain.tscn` | Akses dari Hill, pintu Gua, forage dan kolam air panas; jalur Modern City masih keputusan | [terpasang sebagian + keputusan] |
| Gua / Dungeon | `scenes/world/cave/cave.tscn` | Konfigurasi 1–100, bijih, musuh, lima boss, tangga/lift dan Toko Combat; layout/tier di `resources/cave/` dan `scenes/world/cave/` | [terpasang sebagian] |
| Bukit (Hill) | `scenes/world/hill.tscn` | Rumah warga, akses Gunung dan rute NPC | [terpasang] |
| Ranch Eep | `scenes/world/eep_ranch.tscn`, `scenes/world/interior/eep_home.tscn` | Kolam, padang berpagar, rumah/toko ternak, pakan dan peralatan; utara Farm, barat Town | [terpasang 24 Oktober 2026] |
| Deep Forest | `scenes/world/DeepForest.tscn` | Gathering lanjutan; unlock permanen dari Forest | [terpasang] |
| Pantai (Beach) | scene baru | Spot memancing laut (`beach_sea`), hasil laut, forage pantai (harus di-unlock) | [keputusan] |
| Modern City | scene baru | Area perkotaan metropolitan late-game, teknologi modern, kendaraan canggih (harus di-unlock setelah Nusa Vale makmur) | [keputusan] |

### Pengelolaan Status Area & Unlock [keputusan]
- **`UnlockManager` adalah satu-satunya sumber kebenaran (single source of truth)** untuk pembukaan area dan pintu gerbang.
- Flag lama di `WorldState` yang tumpang tindih (seperti `school_open` atau pengecekan jembatan terpisah) distandarkan ke `UnlockManager.is_unlocked(area_id)`.
- Ketika jembatan rusak selesai diperbaiki, `UnlockManager.unlock("forest")` dipanggil secara langsung.

---

## 4. Sistem yang Sudah Terpasang & Aturan Desain Baru

### 4.1 Waktu, Musim, dan Cuaca Harian [terpasang + keputusan] `autoload/day_cycle.gd`

| Aturan | Nilai | Status |
|---|---|---|
| Kecepatan waktu | 10 menit game = 6 detik nyata (06:00–05:00 = 13 menit 48 detik aktif) | [terpasang] |
| Mulai hari | 06:00 | [terpasang] |
| Waktu pingsan | 05:10: pemain terjaga pingsan, hari berganti, bangun 08:00 dengan energi 50% | [terpasang] |
| Musim | Semi (Spring), Panas (Summer), Gugur (Fall), Dingin (Winter); 28 hari per musim; 1 tahun = 112 hari | [terpasang] |
| Tanaman Musim Dingin | Ladang luar ruangan di musim dingin **memiliki tanaman khusus musim dingin** (mis. Snow Yam, Winter Root, Kubis Salju) | [keputusan] |
| Memancing di Musim Dingin | Permukaan air luar ruangan (kolam & sungai ladang/hutan) membeku sehingga **memancing diblokir**, KECUALI di spot khusus (seperti sumber air panas atau danau gua es) yang harus di-unlock terlebih dahulu | [keputusan] |
| Visual Musim | Tekstur tileset dan pepohonan berganti otomatis sesuai musim lewat `SeasonalTileSwapper` | [terpasang] |
| Tint waktu (siang/sore/malam) | Global: setiap scene dunia otomatis ikut, tanpa node tambahan. Siang 06–16 putih, sore 16–18 jingga, malam 18–06 biru gelap | [terpasang 19 Oktober 2026] |
| Kekuatan tint | Outdoor 100%; interior (path scene berisi `interior`) 50% (`DayCycle.interior_time_strength`); gua (path berisi `/cave/`) 0%, tampilan sendiri | [terpasang; angka usulan] |

**Tint Waktu Global [terpasang 19 Oktober 2026]** (`autoload/day_cycle.gd`, `scripts/world/scene_lighting.gd`):
- Saat scene dunia masuk tree (scene utama, atau area co-op di SubViewport `CoopRoot`), DayCycle memakai CanvasModulate milik scene itu jika ada; jika tidak ada, DayCycle menambahkan `DayCycleTint` sendiri. Scene baru tidak perlu disetel apa pun.
- Warna CanvasModulate yang diatur di editor (mis. `AmbientTint` toko, `WarnaRuangan` rumah Ubay, CanvasModulate kehijauan DeepForest) menjadi **warna dasar ruangan** dan dikalikan dengan warna waktu, tidak lagi ditimpa. Hasil = warna dasar × (putih → warna waktu sesuai kekuatan). Tidak ada penggelapan ganda karena tetap satu CanvasModulate per scene.
- Override per scene: tambahkan node `SceneLighting` di mana saja dalam scene. `follow_time` (matikan untuk tempat selalu gelap/khusus), `time_strength` 0–1, `room_color` (warna dasar tambahan).
- HUD/UI di CanvasLayer tidak terpengaruh. Warna dipasang saat scene masuk tree, jadi tidak ada kedip saat pindah scene walau Transition menjeda game.

**Sistem Cuaca Harian Dinamis (Weather System) [keputusan]**:
- Prakiraan cuaca diprediksi setiap hari melalui siaran Televisi di rumah atau papan cuaca desa.
- Variasi Cuaca:
  1. **Cerah (Sunny / Clear)**: Cuaca standar; sinar matahari cerah, tanaman membutuhkan siraman air manual.
  2. **Hujan (Rainy)**: Langit mendung dan rintik hujan; **secara otomatis menyiram seluruh petak ladang luar ruangan** sepanjang hari (pemain menghemat stamina dan air untuk fokus menjelajah gua/memancing). Beberapa spesies ikan langka hanya aktif saat hujan.
  3. **Badai Petir (Thunderstorm / Heavy Storm)**: Hujan lebat disertai kilat dan guruh. Berisiko menyambar tanaman/pohon liar kecuali dilindungi oleh **Penangkal Petir (*Lightning Rod*)**. Penangkal petir yang tersambar menghasilkan item berharga *Battery Pack* untuk perakitan teknologi otomatis.
  4. **Berkabut (Foggy / Overcast)**: Hutan diselimuti kabut tebal; jamur dan forage langka bermunculan lebih banyak di hutan.
  5. **Salju & Badai Salju (Snow & Blizzard)**: Terjadi di musim dingin; permukaan tanah membeku, suhu dingin menuntut pemain mengenakan pakaian hangat atau masakan berbuff penghangat tubuh.

#### Horor Tengah Malam [terpasang 19 Oktober 2026; angka usulan]

Hanya di luar ruangan; interior, pemain yang tidur, dan transisi tidur/pingsan tetap tenang. Per pemain (co-op: tiap layar punya efeknya sendiri). Scene `scenes/effects/night_horror.tscn` (dibuat oleh HUD); semua angka ada di Inspector node `NightHorror`. Tanpa perubahan save.

- **Rasa Takut (0–1)**: naik di gelap (sebelum 00.00 maksimal 0,45; setelah 00.00 sampai penuh ±1 menit di gelap), turun cepat dalam radius 72 px dari cahaya yang menyala (PointLight2D: Api Unggun, Lampu Taman, Lentera, Lilin, Furnace, dst.) atau node grup `horror_safe_light` (boleh punya properti `safe_radius`). Habis saat masuk ruangan, tidur, atau hari berganti. Tanpa denda gameplay.
- **Detak jantung**: mulai rasa takut 0,25; jeda 1,15 detik → 0,4 detik dan makin keras. Tiap detak tepi layar berdenyut merah; mulai 0,75 kamera ikut bergoyang (solo saja).
- **Layar 00.00–05.00**: kabut + vinyet lama, warna memudar kebiruan, film grain, chromatic aberration yang melebar saat takut, dan glitch (potongan layar bergeser + dengung rendah) pada kejadian besar. Shader `resources/horror/night_horror.gdshader`. Catatan: efek layar ikut mewarnai HUD karena digambar di atasnya.
- **Kejadian ganjil** (`resources/horror/events/*.tres`, kelas `HorrorEvent`; mulai kegelapan 0,7 = 00.00, jeda 18–38 detik, makin sering saat takut, tiap kejadian punya bobot, rasa takut minimal, cooldown, suara pengganti opsional, dan teks Notify opsional):

| Kejadian | Isi | Takut minimal |
|---|---|---|
| Siluet sekilas | Bayangan diam di tepi layar (efek lama) | 0 |
| Siluet melesat | Bayangan melintas cepat + glitch | 0,4 |
| Bisikan | Bisikan dari kiri/kanan pemain (suara posisional) | 0 |
| Bisikan nama | Bisikan dekat + glitch + teks "ada yang membisikkan namamu" | 0,6 |
| Langkah kaki | 8 langkah makin dekat di belakang; hanya terdengar saat pemain berjalan, berhenti saat pemain berhenti | 0,2 |
| Lampu berkedip | Hingga 3 lampu terdekat berkedip lalu padam sesaat (rasa aman hilang); tanpa lampu layar berkedip gelap | 0 |
| Mata merah | Sepasang mata merah 110 px dari pemain, berkedip, hilang bila didekati (<40 px) | 0,35 |
| Gagak | 5 gagak terbang mendadak + koak + guncangan kecil | 0 |

Suara (detak, bisikan, langkah, koak, dengung lampu, dengung glitch, angin) disintesis lewat `scripts/effects/horror_synth.gd`; file audio bisa dipasang di properti `sound` / `heartbeat_sound`.

**Penunggu malam (makhluk penguntit) [terpasang 19 Oktober 2026; angka usulan]**: Kuntilanak dan Pocong (`scenes/horror/kuntilanak.tscn`, `pocong.tscn`, script `NightStalker`; sprite + wajah jumpscare di `assets/horror/` dengan file .aseprite, digambar dari Paletta).
- Muncul mulai ±01.00 (kegelapan 0,75) bila rasa takut ≥ 0,45, pemain tidak dekat cahaya, dan tidak ada makhluk lain: diundi tiap 15 detik (peluang 35%, jeda awal 40 detik, jeda 150 detik setelah makhluk pergi). Muncul 170 px di belakang pemain, di titik yang tidak terang. Satu makhluk per pemain.
- Hanya bergerak saat tidak dilihat. Dilihat = pemain mana pun di area itu menghadapnya (±62°, ≤ 230 px); makhluk membeku (Pocong membeku di udara). Ditatap 3,5 detik: menghilang lalu muncul 70 px di belakang pemain sambil berbisik (maksimal 2 kali).
- Kuntilanak melayang hingga 34 px/detik (berjalan 25, berlari 75) dan menganga saat dekat; kemunculannya ditandai tawa melengking. Pocong melompat 20 px tiap ±0,7 detik dengan bunyi hentakan. Keduanya pucat bercahaya dan berdengung saat dekat; dalam 110 px rasa takut naik cepat dan layar sesekali glitch.
- Disentuh: jumpscare wajah layar penuh + jeritan + kilat merah + guncangan, kontrol terkunci 0,9 detik, rasa takut penuh, energi -25 (Kuntilanak) / -30 (Pocong). Default tidak bisa membuat pingsan (sisa minimal 1; `jumpscare_can_faint`).
- Lolos: berlari, masuk ruangan, atau berdiri di dekat cahaya (lampu/api mengusirnya). Pergi sendiri setelah 75–85 detik. Tanpa perubahan save.

### 4.2 Stamina, Tidur, dan Denda Pingsan [terpasang + keputusan]

- Stamina awal 100 per pemain; tiga Biji Daya menambah 30, rumah tingkat 2 memberi +30 dan tingkat 3 +40 lagi (bonus rumah total 70), sehingga maksimum individu mencapai **200**. Bonus rumah dibagi seluruh penghuni; Biji Daya tetap milik karakter yang mengonsumsinya.
- Biaya stamina alat sekali per ayunan (berkurang drastis pada tier tinggi, lihat tabel 4.5).
- Memungut forage dan menebas rumput liar tidak menggunakan stamina (stamina cost = 0) [keputusan].
- Tidur di kasur rumah memulihkan stamina 100%, memicu pergantian hari, dan menyimpan game otomatis.
- **Pingsan batas waktu [terpasang]**: 05:10, bangun 08:00 di rumah dengan 50% kapasitas stamina; tanpa kehilangan uang/item. Pemain co-op yang sudah tidur pulih penuh.
- **Pingsan kelelahan [keputusan 2026-10-17, terpasang]**: stamina yang turun sampai 0 membuat karakter pingsan (animasi death), lalu bangun di rumah dengan 50% stamina tanpa denda uang/item. Solo: hari berganti, bangun 08:00, game disimpan. Co-op: hanya pemain itu yang dipulangkan. Tanda sebelumnya: bar stamina berdenyut di bawah 25%, karakter berkeringat dan berkedip pucat di bawah 15%; aksi yang ditolak karena lelah membuat bar bergetar dan berkedip merah.
- **Denda medis karena HP habis [terpasang, Phase 4B-1]**:
  - Pemain tumbang, layar pindah ke **Klinik Desa** (`clinic.tscn`) sebagai transisi, lalu bangun di rumah dengan HP 50% dan stamina maksimal 50%. Solo: hari berganti dan bangun 08:00, lalu game disimpan. Co-op: hanya pemain yang tumbang yang dipulangkan, waktu tetap berjalan untuk pemain lain.
  - Sanksi: **biaya perawatan 10% uang** (maksimal 1.000 G) dan **2 tumpukan barang acak di tas berkurang separuh** (dibulatkan ke atas). Alat, senjata, perlengkapan, bangunan, barang taruh, dan Biji Daya tidak pernah hilang.
  - Semua angka ada di `resources/combat/defeat_rules.tres` (DefeatRules).

### 4.3 Inventory, Equipment, dan Lokalisasi Bahasa [terpasang + keputusan]

- Ransel 36 slot (aktif 12 / 24 / 36 sesuai `bag_level`). Upgrade ransel dibeli di toko (1.500 G dan 7.500 G).
- Hotbar 8 slot dengan tombol geser halaman (Tab / Gamepad Back).
- Sortir tas (R) otomatis menggabungkan stack dan merapikan alat di depan.
- **Kontrol & Konteks Input [terpasang, v3.24]**: satu tombol boleh punya arti berbeda di konteks berbeda, tetapi di satu konteks satu tombol hanya punya satu aksi, jadi farming, lompat, combat, dan dialog tidak bertabrakan. Tata letak meniru game yang sudah dikenal pemain baru: lapangan seperti **Stardew Valley**, lompat seperti **Story of Seasons: Grand Bazaar**, combat seperti **game soulslike** (Elden Ring / Dark Souls).
  - **Input router**: `PlayerInput` (`scripts/player/player_input.gd`) satu-satunya tempat yang memutuskan aksi. Tata letak bawaan ada di `InputLayout` (`scripts/player/input_layout.gd`); tiap binding membawa konteks dan router hanya mengaktifkan binding yang konteksnya cocok (aksi Input Map varian `aksi@konteks`, co-op `p2_aksi@konteks`).
  - **Konteks** (dipilih otomatis, yang pertama cocok menang): UI yang mendorong konteks (dialog NPC = Dialog) → Menu (tas/toko/pause terbuka) → Di udara (sedang lompat) → Berenang (disiapkan, belum ada air yang bisa direnangi) → **equipment context** dari barang yang dipegang di hotbar (`scripts/player/equipment_context.gd`): pedang = Combat dekat; busur/tongkat = Combat jauh; alat, benih, makanan, tangan kosong = Lapangan.
  - **Lapangan (Stardew Valley)**:

    | Aksi | Keyboard + Mouse | Gamepad (Xbox) |
    |---|---|---|
    | Jalan | WASD | Stik kiri / D-pad |
    | Pakai alat | Klik kiri / C | X |
    | Interaksi, bicara, periksa | E / X / klik kanan | A |
    | Lari (tahan, tanpa auto-run) | Shift | RT |
    | Tas / menu | I / Esc | B / Start |
    | Tas tab Crafting / beri hadiah | - | Y |
    | Slot sebelumnya / berikutnya | Scroll / ← → | LB / RB (di tas: ganti tab) |
    | Pilih slot | 1-8 | - |
    | Halaman hotbar | Tab | Back |
    | Rapikan tas | R | R3 |

  - **Lompat (Grand Bazaar)**: Spasi / A. Tekan lagi di udara = **lompat ganda**. Pakai alat di udara sambil memegang **benih** = benih ditebar ke petak cangkul kosong 3x3 di sekitar tempat mendarat. Gamepad A juga interaksi: bila ada NPC, pintu, forage, atau objek di depan, A = interaksi; selain itu A = lompat. Lompat tidak memakai stamina dan hanya visual (tabrakan tetap). Tidak bisa melompat sambil memegang senjata (Spasi = roll). Belum ada sheet animasi lompat: sprite jalan diangkat di atas bayangan.
  - **Combat saat memegang senjata (soulslike)**:

    | Aksi | Keyboard + Mouse | Gamepad (Xbox) |
    |---|---|---|
    | Serang ringan (tahan = berat) | Klik kiri / C | RB / X |
    | Serangan berat | tahan klik kiri | RT |
    | Roll | Spasi | B tekan singkat |
    | Lari | Shift | B tahan |
    | Tangkis (tahan) / parry (tepat waktu) | Klik kanan (pedang) | LB |
    | Bidik busur / tongkat | Klik kanan (busur/tongkat) | LT + stik kanan |
    | Weapon Art | F | LT (pedang) / L3 |
    | Kunci target (lock-on) | Q / klik tengah | R3 (stik kanan = pindah target) |
    | Ganti slot | Scroll / ← → | D-pad kiri / kanan |
    | Tas | I / Esc | Start |

    Klik kanan ke pintu/objek di dekat pemain tetap interaksi walau memegang senjata (tangga gua). B saat combat tidak membatalkan/membuka tas.
  - **Lock-on** (`scripts/combat/lock_on.gd`): mengunci musuh terdekat di depan dalam 150 px; pemain menghadap target saat berjalan, serangan dan bidikan mengarah ke target; lepas otomatis bila target mati, lebih dari 200 px, atau senjata disimpan.
  - **Prompt tombol dinamis** (`scripts/ui/input_prompt.gd`): teks seperti "[E] Masuk" berganti jadi "[A] Masuk" begitu pemain memegang gamepad, dan ikut tombol yang diatur ulang (gerbang Hutan Dalam, jembatan rusak, dialog NPC). **Petunjuk tombol HUD** (`scripts/ui/action_hints.gd`) di kiri bawah menampilkan arti tombol penting sesuai konteks; bisa dimatikan di Pengaturan > Kontrol.
  - **Atur ulang tombol (remap)** di Pengaturan > Kontrol: klik tombol di kolom Keyboard + Mouse atau Gamepad lalu tekan tombol baru (Esc batal). Tombol yang sudah dipakai aksi lain di konteks yang sama otomatis ditukar. Disimpan per komputer di `user://input_bindings.cfg` (bukan save game, tanpa perubahan save). Satu pengaturan gamepad berlaku untuk semua gamepad co-op. Stik kiri selalu berjalan dan tidak bisa diatur ulang.
  - Tes: `tests/input_context_regression.tscn`, `tests/gamepad_input_regression.tscn`.
- Equipment: 7 slot terpasang (`helmet`, `armor`, `leggings`, `boots`, lalu `necklace`, `ring`, `accessory` sejak save v20, lihat 4.13). Senjata (pedang, busur, tongkat sihir) **dipegang dari hotbar**, bukan dipasang; slot Weapon di menu hanya menampilkan senjata yang sedang dipegang. Save lama yang memasang senjata memindahkannya ke tas. 96 Resource item memiliki `equipment_slot` eksplisit: 30 senjata dan 66 wearable. Angka ini adalah inventaris data; tidak menyatakan semua dijual di toko atau telah diuji.
- **Konvensi Bahasa & Lokalisasi [keputusan]**:
  - `display_name` item diseragamkan ke **Bahasa Indonesia** sebagai bahasa utama (misal: "Kapak Kayu", "Pedang Besi", "Wortel", "Ikan Lele").
  - Sistem disiapkan mendukung multi-bahasa dengan opsi beralih Bahasa Indonesia / Bahasa Inggris di menu Pengaturan.
  - `item_id` tetap memakai format snake_case Inggris untuk kompatibilitas kode.

### 4.4 Pertanian (Farming) [terpasang + keputusan]

- Alur: Cangkul tanah yang `farmable` $\rightarrow$ Tanam bibit $\rightarrow$ Siram air setiap hari $\rightarrow$ Panen saat matang.
- 39 tanaman musiman dasar + penambahan tanaman khusus musim dingin di ladang [keputusan].
- **Pohon Buah Permanen [keputusan]**:
  - Pohon buah (Apel, Ceri, Jeruk, Persik, Mangga, Pisang, Aprikot) **bukan tanaman sekali panen**.
  - Bibit pohon buah ditanam dan tumbuh melalui beberapa fase hingga menjadi pohon dewasa permanen yang tetap berdiri lintas musim.
  - Pohon berbuah secara berkala hanya pada musim spesifiknya masing-masing, dapat dipanen berulang kali setiap beberapa hari selama musim aktif tanpa perlu menanam ulang.
- **Greenhouse [terpasang]**: 32 petak tanam lintas musim di dalam ruangan, tidak terpengaruh musim luar dan tanaman tidak pernah layu.

### 4.5 Alat, Tier, dan Pengerjaan Upgrade [terpasang + keputusan]

- 7 Jenis Alat: Kapak (`axe`), Cangkul (`hoe`), Beliung (`pickaxe`), Sekop (`shovel`), Kaleng Air (`watering_can`), Sabit (`sickle`), Pancing (`fishing_rod`).
- 10 Tier Progresi: Wood $\rightarrow$ Copper $\rightarrow$ Iron $\rightarrow$ Gold $\rightarrow$ Platinum $\rightarrow$ Crimson $\rightarrow$ Frost $\rightarrow$ Shadow $\rightarrow$ Fairy $\rightarrow$ Obsidian.

**Spesifikasi Efek Tier Alat** (Terverifikasi dari `TOOL_PROGRESSION.md`):

| Tier | Jangkauan Bidik | Kecepatan | Area Kerja (Cangkul/Sekop/Sabit/Air) | Kapasitas Tangki Air | Kekuatan Pukul (Kapak/Beliung) | Bonus Loot Sekop |
|---|---:|---:|---|---:|---:|---:|
| Kayu (Wood) | 1,5 petak | 1,00x | 1x1 | 20 | 1 | 0% |
| Tembaga (Copper) | 1,6 petak | 1,10x | 1x2 | 35 | 2 | 5% |
| Besi (Iron) | 1,8 petak | 1,20x | 1x3 | 55 | 3 | 10% |
| Emas (Gold) | 2,0 petak | 1,30x | 2x2 | 80 | 4 | 15% |
| Platinum | 2,2 petak | 1,40x | 2x3 | 110 | 5 | 20% |
| Crimson | 2,4 petak | 1,55x | 3x3 | 145 | 7 | 25% |
| Frost | 2,6 petak | 1,70x | 3x4 | 185 | 9 | 30% |
| Shadow | 2,8 petak | 1,85x | 3x5 | 230 | 12 | 35% |
| Fairy | 3,0 petak | 2,00x | 4x5 | 280 | 15 | 40% |
| Obsidian | 3,2 petak | 2,20x | 5x5 | 350 | 20 | 45% |

**Aturan Upgrade Alat [keputusan]**:
- **Interaksi dengan NPC Pandai Besi (Blacksmith NPC)**: Upgrade alat **tidak dilakukan pada meja/stasiun kosong**, melainkan pemain harus datang dan **berinteraksi langsung dengan NPC Pandai Besi / penjaga bengkel Blacksmith** di kota Nusa Vale.
- Pemain membuka dialog layanan bengkel: membeli batangan/batu bara, memperbaiki perlengkapan, atau memesan penempaan upgrade alat.
- **Waktu Pengerjaan 1–2 Hari**: Alat yang di-upgrade diserahkan ke NPC Blacksmith beserta batangan logam dan biaya uang, ditinggal selama 1–2 hari kerja, lalu diambil kembali dari NPC setelah selesai.
- Resep upgrade tier:
  - Copper: 350 G + 5 copper_bar + 10 wood
  - Iron: 1.000 G + 5 iron_bar + 15 wood
  - Gold: 2.300 G + 5 gold_bar
  - Platinum: 4.500 G + 5 platinum_bar
  - Crimson: 7.000 G + 5 crimson_bar
  - Frost: 10.000 G + 5 frost_bar
  - Shadow: 14.000 G + 5 shadow_bar
  - Fairy: 20.000 G + 5 fairy_bar
  - Obsidian: 28.000 G + 5 obsidian_bar

Baseline terbaru: changelog 3.30 (bagian 19); audit lanjutan [AUDIT_2026-10-26.md](AUDIT_2026-10-26.md). Panen awal 510 G + modal 100 G membayar Tembaga 350 G dan bibit ulang 225 G, menyisakan 35 G. Margin 39 crop dan ternak dipertahankan. Nilai jual kembali benih menjadi 40% harga beli untuk mencegah jual-beli berulang tanpa rugi saat bonus grosir/shipping aktif.

### 4.6 Tebang, Tambang, Furnace, dan Nilai Logam [terpasang + keputusan]

- **Furnace & Bengkel Blacksmith [keputusan]**:
  - Furnace pelebur bijih logam tersedia sebagai **resep Crafting** yang bisa dirakit pemain dan dipasang bebas di area Farm.
  - Penempaan dan upgrade alat dipusatkan melalui interaksi dengan NPC Pandai Besi di bengkel kota.
- **Sumber Bijih Tingkat Lanjut [keputusan]**:
  - Batu Tembaga dan Besi ada di Hutan.
  - Batu Emas (*Gold Ore*) hingga batuan logam langka berikutnya (Platinum, Crimson, Frost, Shadow, Fairy, Obsidian) **ditempatkan di area Gunung dan lantai-lantai Gua tambang** yang harus di-unlock terlebih dahulu.
- **Harga Jual Batangan Logam Naik Progresif [keputusan]**:
  - Tembaga (Copper Bar): 40 G
  - Besi (Iron Bar): 80 G
  - Emas (Gold Bar): 160 G
  - Platinum Bar: 260 G
  - Crimson Bar: 400 G
  - Frost Bar: 580 G
  - Shadow Bar: 800 G
  - Fairy Bar: 1.100 G
  - Obsidian Bar: 1.500 G

### 4.7 Toko, Shipping Bin, dan Logistik Penjualan [terpasang + keputusan]

- **Shipping Bin [keputusan]**:
  - Pemain memasukkan barang ke Shipping Bin di ladang kapan saja.
  - **Uang tidak dibayar seketika**. Barang diangkut oleh NPC kurir logistik desa di sore hari (misal jam 17:00) atau total pendapatan dihitung dan dibayarkan ke saldo pemain saat tidur malam dengan rekapitulasi ringkasan pendapatan harian.
- Toko General Store tetap melayani pembelian instan untuk pemain yang butuh uang tunai langsung di tempat.

### 4.8 Foraging, Titik Gali, dan Pembersihan Lahan [terpasang + keputusan]

- Parameter spawn harian yang berlaku [keputusan]:
  - Forage Hutan: 3 item per hari (maksimum menumpuk 12 item).
  - Titik Gali Cacing: 2 di hutan, 1 di ladang per hari (maks 5 dan 3).
  - Rumput Liar: 4 di ladang, 3 di hutan per hari (maks 30 dan 15); peluang 60% menjatuhkan Serat (*Fiber*).
  - Pohon Tumbuh Alami: 2 bibit per hari di hutan (tumbuh dewasa dalam 7 hari).
  - Konsumsi stamina untuk memungut forage dan menebas rumput liar adalah 0.

### 4.9 Balai Nadi & Restorasi Desa [terpasang + keputusan]

- Balai Nadi memiliki **gedung dan pintu permanen di Kota** [keputusan].
- Menggunakan sistem kontribusi proyek restorasi berbasis Resource `RestorationProject`:
  - Proyek 1: Restorasi Balai Nadi (100 kayu + 50 batu + 500 G).
  - Proyek 2: Pemulihan Greenhouse (150 kayu + 75 batu + 5 batangan tembaga).
  - Proyek Berikutnya [keputusan]: Renovasi bengkel Blacksmith, Warung Makan, jembatan pegunungan, dan fasilitas desa lainnya menggunakan sistem kontribusi komunitas Balai Nadi yang sama.

#### 4.9.1 Sayap dan Paket ala Community Center [terpasang 25 Oktober 2026; isi paket dan angka = usulan]

- Balai Nadi bekerja seperti Community Center Stardew (paket untuk memulihkan sayap), **bukan museum** [keputusan].
- 21 paket: Balai Utama 1, Sayap Alam 7, Karya 4, Niaga 4, Pengetahuan 5. Data `resources/restoration/bundles/*.tres` (tiga paket lama tetap di `resources/restoration/`), urutan di `balai_nadi_catalog.tres`.
- **Pilih N dari M** [usulan, menunggu konfirmasi pemilik]: `RestorationProject.slots_required` (0 = semua item wajib). Paket selesai begitu N jenis terisi penuh; jenis lain tidak bisa disumbang lagi.
- Tiap paket memberi 1 Token Talenta (bagian 13.4) + hadiah barang `reward_items`. Biji Daya "balai" hanya dari Restorasi Balai dan Greenhouse.
- Item kualitas (perak/emas/besar) belum diterima sebagai pengganti item biasa.

| Sayap | Paket (isi N dari M) | Hadiah paket |
|---|---|---|
| Balai Utama | Restorasi Balai Nadi (100 kayu, 50 batu, 500 G) | Biji Daya |
| Alam | Kebun Sepanjang Musim (Greenhouse); Paket Serangga; Panen Semi 4/6 (parsnip, potato, cauliflower, strawberry, garlic, cabbage); Panen Panas 4/6 (tomato, corn, melon, blueberry, chili, watermelon); Panen Gugur 4/6 (pumpkin, eggplant, grape, beet, broccoli, wheat); Kebun Buah 5/7 (apple, cherry, orange, peach, mango, apricot, banana); Hasil Liar 6/9 (daffodil, spring onion, sweet pea, wild berry, common mushroom, hazelnut, holly, winter root, mooncap) | Greenhouse; 3 tapper; 10 bibit stroberi/melon/labu; 1 bibit mangga; 20 bug bait |
| Karya | Peternak 5/7 (telur ayam/bebek, susu sapi/kambing/kerbau, wol, bulu bebek); Artisan 6/8 (keju, keju kambing, keju kerbau, mayones, kain, madu, sirup maple, selai); Tukang (20 papan, 5 tali, 10 resin, 50 serat, 10 tanah liat); Pandai Besi (5 copper bar, 5 iron bar, 3 gold bar, 20 coal) | 20 jerami; preserves jar; sawmill; furnace |
| Niaga | Dapur Desa 6/8 (roti, omelet, sup sayur, sup ikan, pancake, nasi kepal, telur goreng, ikan panggang); Kedai Minum 5/7 (kopi, jus, teh hijau, wine, bir, mead, boba); Lumbung Rempah (5 garam, gula, tepung, minyak, shoyu); Dana Pasar (5.000 G) | cooking oven; keg; oil maker; beehive |
| Pengetahuan | Ikan Sungai 5/7 (mas, lele, nila, carp, bullhead catfish, perch, chub); Ikan Musiman 5/7 (faeries fish, tiger trout, gurame, dorado, pike, walleye, sturgeon); Danau Gua 4/5 (ghost catfish, bone fish, zombie fish, crayfish, dynamite fish); Permata Nusa 6/8 (quartz, amethyst, topaz, emerald, ruby, sapphire, citrine, onyx); Mineral & Artefak (earth crystal, frozen tear, fire quartz, old bone, 10 slime gel) | 20 bait; 10 lure; 15 glow bait; 3 geode; omni geode |

- **Hadiah sayap lengkap** [keputusan pemilik 25 Oktober 2026: bonus permanen per sayap; angka usulan]. Data `resources/restoration/wings/<id>.tres` (`BalaiWing.effects`), dibaca `SkillSystem.stat/household` lewat `BalaiNadiManager.wing_stat()` dan berlaku untuk semua pemain co-op. Penyumbang terakhir mendapat +2 Token Talenta dan flag `balai_wing_<id>_done`.
  - Alam: `crop_growth` +0,10 (peluang +1 hari tumbuh, ±10% lebih cepat).
  - Karya: `tool_upgrade_discount` 0,10 (biaya uang upgrade alat di Empu Bima -10%, bahan tetap).
  - Niaga: `ship_bonus` dan `shop_sell` +0,05 (harga jual +5%).
  - Pengetahuan: `geode_chance` 0,25 (peluang geoda di gua ×1,25).
- Tahap restorasi baru "Jantung Desa" saat keempat sayap lengkap.
- **Tampilan sebelum/sesudah restorasi** [terpasang 25 Oktober 2026]: Bale Agung di luar memakai `assets/balai_nadi/v4/bale_agung_ruined.png` (atap bolong, kusam, lumut, tirai sobek, kristal padam; dibuat dari v2 lewat skrip) sampai Restorasi Balai Nadi selesai, lalu `v2/bale_agung.png` (`scripts/world/balai_restoration_art.gd`). Interior memakai gambar ruangan `v1/interior_ruined.png` / `interior_restored.png` menggantikan kotak placeholder; meja kontribusi dan batas jalan disesuaikan dengan gambar.
- Tanpa perubahan save (tetap v26): progres disimpan per `project_id`, save lama memuat paket baru dalam keadaan kosong; status dan flag sayap dihitung ulang saat load. Tes `tests/balai_bundles_regression.tscn`.

### 4.10 Sistem Peternakan & Satwa (Animal Husbandry & Ranching) [terpasang + keputusan + usulan]

**Implementasi core loop (13 Oktober 2026) [terpasang]**: ayam, bebek, sapi, kambing, domba; pakan dan jerami; elusan +3 dan sikat +1 sehari; kebersihan, kesehatan/pemulihan; telur, susu, wol dengan ukuran/kualitas; petak rumput pakan dan hewan berjalan di ladang; silo 240 jatah; upgrade kandang 4/8/12 dan auto-feeder; Mesin Mayones, Mesin Keju, Alat Tenun; save/load dan perawatan bersama co-op. Panduan aturan aktual dan harga ada di **[LIVESTOCK_CORE_LOOP.md](LIVESTOCK_CORE_LOOP.md)**. Angka usulan di bawah yang sesuai panduan tersebut kini sudah terpasang. **Peternakan lanjutan (25 Oktober 2026) [terpasang]**: kerbau, kapibara, kuda tunggangan, pembiakan Barn, Inkubator, dan bulu bebek; aturan di bagian 4.10.9–4.10.11. Ayam jago/cemani, festival, dan layanan kesehatan berbayar masih rancangan lanjutan.

- **Bangunan Kandang (Coop & Barn)**:
  - Dibangun melalui meja Crafting / pertukangan desa dan dipasang di ladang:
    - **Kandang Unggas (Coop)**: Kapasitas awal 4 ekor (dapat di-upgrade ke Big Coop 8 ekor & Deluxe Coop 12 ekor dengan auto-feeder).
    - **Kandang Ternak Besar (Barn)**: Kapasitas awal 4 ekor (dapat di-upgrade ke Big Barn 8 ekor & Deluxe Barn 12 ekor dengan auto-feeder).
    - **Silo Jerami**: Menyimpan rumput kering pakan ternak (kapasitas 240 jerami per silo), otomatis terisi saat menebas rumput liar ladang dengan sabit.
- **Varietas Hewan Ternak**:
  - *Unggas (Coop)*: Ayam Putih/Cokelat (Telur harian), Bebek (Telur bebek & Bulu bebek), Ayam Jago / Cemani (untuk Adu Ayam Sumo di festival).
  - *Ternak Besar (Barn)*: Sapi Perah (Susu sapi), Kambing (Susu kambing dua hari sekali), Domba (Bulu wol setiap 3 hari), Kuda (Tunggangan cepat & peserta Derby Balap Kuda), serta Kerbau Lumpur / Kapibara (Susu kerbau & satwa ramah ladang).
- **Rutinitas Perawatan & Sistem Kasih Sayang (Affection System)**:
  - *Pakan Harian*: Memberikan jerami (*Hay*) di palung kandang saat hari hujan/dingin, atau membuka pintu kandang agar hewan merumput bebas di luar saat cerah (*Grazing*).
  - *Interaksi Kasih Sayang (Petting)*: Mengelus hewan setiap hari memunculkan balon hati (`♥`) dan menaikkan tingkat persahabatan hewan (1–5 bintang hati).
  - *Peralatan Peternakan*: Kaleng Pemeras Susu (*Milk Pail*), Gunting Cukur Wol (*Shears*), dan Sikat Bulu (*Animal Brush*).
  - *Kualitas Hasil Ternak*: Hewan berhati tinggi menghasilkan produk ukuran besar (*Large Egg, Large Milk*) dan kualitas Bintang Emas bernilai jual tinggi.

#### 4.10.1 Fondasi yang Sudah Terpasang [terpasang]

Rujukan implementasi: `scripts/system/chicken_husbandry.gd`, menu kandang, dan `docs/FARM_BUILDINGS_WEATHER.md`.

- Kandang ayam memuat 4 ayam dewasa putih/cokelat, masing-masing berharga 800 G; pemain dapat memberi nama.
- Satu ayam membutuhkan satu `animal_feed` per hari (harga beli 10 G). Aksi individual atau **Beri pakan semua** menggunakan tas pemain yang berinteraksi.
- Mengelus memberi kasih sayang sekali per ayam per hari. Nilai internal kasih sayang berada pada rentang 0–100.
- Saat hari berganti, ayam yang sudah makan menghasilkan satu `chicken_egg` (harga jual 50 G); makan menambah kasih sayang 2 poin, hari lapar mengurangi 3 poin, dengan batas 0–100.
- Telur terkumpul sebagai stok kandang. Tas penuh tidak menghapus telur; pengambilan sebagian tetap aman. Batas stok saat ini 999 telur.
- Data ayam, pakan, kasih sayang, dan produksi tersimpan; kandang serta hasilnya dipakai bersama oleh pemain co-op.
- Catatan fondasi sebelum versi 2.2: Barn awalnya hanya bangunan. Ternak besar, hewan berjalan, jerami, kualitas, kebersihan, dan kesehatan kini terpasang melalui perluasan core loop; interior Barn/Coop kini terpasang dengan UID stabil dan dukungan co-op.

#### 4.10.2 Pengalaman dan Rutinitas Pemain [usulan]

Target rutinitas untuk 4 hewan adalah **45–90 detik nyata per hari**, termasuk perjalanan dekat kandang. Target ini perlu diuji lewat playtest; kebutuhan ternak tidak boleh menghabiskan sebagian besar hari yang berdurasi sekitar 10 menit nyata.

| Tahap | Aksi pemain | Umpan balik | Manfaat/keputusan |
|---|---|---|---|
| Cek pagi | Buka ringkasan kandang atau dekati hewan | Nama, kenyang/lapar, sudah/belum dielus, kondisi, hasil siap | Tahu prioritas tanpa membuka banyak panel |
| Pakan | Isi palung atau buka akses padang rumput yang aman | Ikon pakan dan jumlah hewan yang sudah makan | Pakai stok untuk kepastian atau rumput untuk menghemat |
| Kedekatan | Elus; sikat ternak berbulu sesuai kebutuhan | Balon hati dan perubahan kasih sayang | Perawatan konsisten meningkatkan kualitas hasil |
| Kebersihan | Bersihkan satu titik kotor kandang bila ada | Lantai kembali bersih dan indikator kondisi membaik | Menjaga kenyamanan dengan pekerjaan singkat |
| Panen | Ambil telur; gunakan pemeras susu atau gunting wol saat siap | Animasi, bunyi, jumlah dan kualitas produk | Hasil jelas berhubungan dengan perawatan sebelumnya |
| Alokasi hasil | Jual, simpan untuk masakan/kontribusi, atau olah | Nilai produk dan kebutuhan mesin terlihat | Uang cepat atau nilai lebih tinggi setelah pengolahan |
| Persiapan | Cek cadangan, prakiraan cuaca, dan pintu kandang | Ringkasan kebutuhan besok | Membatasi jumlah hewan sesuai kemampuan merawat |

Pakan dan elusan tidak menguras stamina. Memeras, mencukur, dan membersihkan masing-masing diusulkan memakai 1 stamina per aksi berhasil; aksi pada hewan yang belum siap tidak memakai stamina. Semua angka biaya ini masih [usulan].

#### 4.10.3 Pakan, Merumput, dan Cuaca [keputusan + usulan]

**Satu jatah pakan per hewan per hari** dan pilihan jerami/merumput mengikuti keputusan dasar bagian 4.10. Rincian berikut [usulan]:

- Pakan Ayam yang sudah ada tetap sah untuk unggas. Jerami menjadi pakan bersama untuk unggas dan ternak penghasil susu/wol; jangan menghapus stok pakan lama ketika sistem diperluas.
- Palung memiliki satu tempat per kapasitas kandang. Setiap jatah hanya dapat dikonsumsi satu hewan; status kenyang mencegah konsumsi ganda antara palung dan merumput.
- Merumput hanya aktif saat cerah, di luar musim dingin, dengan rumput pakan yang dapat dicapai. Pintu terbuka saja tidak membuat hewan kenyang; satu petak rumput pakan menyediakan satu jatah dan kemudian habis.
- Rumput pakan dibedakan dari rumput liar yang menjatuhkan Serat. Memanen jerami tidak mengganti aturan drop Serat yang sudah ada; peluang konversi jerami perlu ditentukan terpisah.
- Bila rumput tidak cukup, palung menjadi cadangan. Hewan yang belum kenyang saat kembali masuk masih dapat memakan jatah yang tersedia.
- Hujan, badai, dan salju membuat hewan tetap di dalam. Hewan di luar kembali otomatis pukul 18:00 atau saat cuaca berbahaya; menutup pintu tidak boleh menjebak hewan di luar atau menghilangkannya.
- Auto-feeder Deluxe mengambil jerami dari silo pada awal hari untuk mengisi tempat palung yang kosong, sebatas stok. Pakan yang sudah tersedia tidak ditimpa; kekurangan stok ditampilkan pada ringkasan pagi.
- Ringkasan menampilkan stok dan perkiraan **hari cadangan = floor(jatah tersedia / jumlah hewan pemakan pakan)**; bila tidak ada hewan, tampilkan “Belum ada hewan”. Jangan mengasumsikan rumput besok pasti mencukupi.

#### 4.10.4 Kasih Sayang, Kebersihan, dan Kesehatan [usulan]

- Gunakan nilai kasih sayang 0–100 yang sudah ada. Tampilan 0–5 hati: satu hati penuh per 20 poin. Mengelus memberi +3 sekali sehari; makan tetap +2, lapar tetap −3 agar selaras dengan fondasi ayam.
- Menyikat sapi, kambing, domba, dan kuda memberi +1 sekali sehari. Mengulang elusan/sikatan menampilkan “Sudah dirawat hari ini” tanpa bonus tambahan, termasuk jika dilakukan pemain lain.
- Kasih sayang adalah hubungan jangka panjang; kondisi **Nyaman / Kurang nyaman / Kurang sehat** menjelaskan kebutuhan saat ini. Jangan menyembunyikan kebutuhan lewat satu angka suasana hati.
- Satu kandang berisi hewan memunculkan paling banyak satu titik kotor pada awal hari, sampai maksimum 3 titik. Satu interaksi membersihkan satu titik. Kandang kosong tidak menghasilkan kotoran.
- Kondisi Nyaman membutuhkan makan hari itu dan kurang dari 3 titik kotor. Kandang dengan 3 titik kotor membuat hewan Kurang nyaman; dua evaluasi harian berturut-turut tanpa makan atau dengan kandang penuh kotoran membuat hewan Kurang sehat.
- Kurang sehat menghentikan produksi. Setelah satu hari penuh mendapat pakan dan kandang bersih, kondisi pulih pada pergantian hari; kasih sayang tidak langsung kembali. Obat/perawatan Rian dapat menjadi layanan lanjutan dengan harga tersendiri, bukan syarat wajib untuk pulih.
- Hewan tidak mati atau hilang karena perawatan terlewat. Konsekuensi berupa kehilangan hasil, penurunan kasih sayang, dan waktu pemulihan; UI menyebutkan penyebab dan tindakan pemulihan.

#### 4.10.5 Produksi dan Kualitas Hasil [keputusan + usulan]

Interval sapi harian, kambing dua hari, dan domba tiga hari mengikuti arah desain spesies [keputusan]. Rincian penjadwalan dan kualitas berikut [usulan], kecuali produksi ayam dasar yang sudah terpasang.

| Hewan | Hasil | Interval hari terawat | Pengambilan |
|---|---|---:|---|
| Ayam petelur | Telur | 1 | Ambil stok kandang; fondasi sudah terpasang |
| Sapi | Susu sapi | 1 | Pemeras susu pada hewan yang siap |
| Kambing | Susu kambing | 2 | Pemeras susu pada hewan yang siap |
| Domba | Wol | 3 | Gunting wol pada hewan yang siap |
| Bebek | Telur bebek | 2 | Ambil stok kandang; bulu sebagai hasil lanjutan |
| Kerbau | Susu kerbau | 2 | Pemeras susu; Mesin Keju → Keju Kerbau [terpasang] |
| Kuda, ayam jago, kapibara | Mobilitas/festival/kedekatan | Tidak memproduksi komoditas harian | Perawatan mengikuti kebutuhan spesies; kuda dan kapibara [terpasang] |

- Hari terawat untuk produksi adalah hari kenyang dan tidak Kurang sehat pada evaluasi malam. Hari gagal tidak menambah penghitung, tidak mereset kemajuan sebelumnya, dan tidak membuat utang hasil.
- Produk pagi berasal dari evaluasi hari sebelumnya. Memberi makan hari ini tidak langsung membuat produk baru. Sapi/kambing/domba menyimpan maksimum satu hasil siap per hewan; selama belum dipanen, penghitung produksi berhenti.
- Untuk ayam/bebek, telur masuk stok kandang sesuai kapasitas penyimpanan yang ditampilkan. Saat penuh, produksi tambahan berhenti dengan peringatan; tidak menumpuk hasil tersembunyi untuk dicairkan setelah panen.
- Kualitas ditetapkan saat produk dibuat: Normal pada kasih sayang 0–39, Perak 40–79, Emas 80–100, dengan pengali harga dasar 1,0× / 1,25× / 1,5×, dibulatkan ke bawah. Kondisi Kurang nyaman membatasi hasil ke Normal.
- Ukuran Besar terbuka pada kasih sayang minimal 60 dan kondisi Nyaman, dengan pengali tambahan 1,25×. Kualitas dan ukuran disimpan pada produk; mengelus setelah produk siap tidak mengubah hasil tersebut.
- Harga beli hewan baru, harga susu/wol, usia dewasa, inkubasi, dan pembiakan memerlukan tabel balancing tersendiri. Tahap awal mempertahankan pembelian hewan dewasa agar loop perawatan dapat diuji lebih dahulu.

#### 4.10.6 Progresi dan Ekonomi [usulan]

1. **Mulai kecil**: bangun Coop dan beli 1–2 ayam; tutorial menunjukkan pakan, elusan, tidur, lalu telur pertama. Rian memberi panduan perawatan; Pak Damar tetap melayani pembangunan kandang.
2. **Stabilkan cadangan**: tambah sampai 4 ayam setelah mampu menyediakan pakan beberapa hari. Pada harga yang terpasang, 4 ayam menghasilkan 200 G bruto dan membutuhkan 40 G pakan per hari; margin 160 G belum menghitung modal, waktu, dan pengolahan.
3. **Diversifikasi**: bangun Barn untuk sapi, lalu kambing/domba. Jadwal panen berbeda memberi variasi dan kebutuhan alat tanpa mewajibkan semua spesies.
4. **Tambah nilai**: olah telur menjadi mayones, susu menjadi keju, dan wol menjadi kain sesuai mesin bagian 4.11; modal dan waktu mesin perlu diperhitungkan saat menyeimbangkan harga.
5. **Perluas dan otomatisasi**: kapasitas 4 → 8 → 12 serta auto-feeder mengikuti [keputusan] kandang. Otomatisasi pakan tidak menggantikan kedekatan, panen manual, atau pemeriksaan kesehatan.

#### 4.10.7 UI, Co-op, dan Penyimpanan [usulan]

- Ringkasan per kandang: **kenyang X/Y**, **dielus X/Y**, hasil siap, titik kotor, hewan perlu pemulihan, serta cadangan pakan. Detail hewan menampilkan nama, spesies, hati, dan alasan belum berproduksi.
- Saat aksi berhasil, tampilkan perubahan yang nyata. Saat gagal, jelaskan “Pakan habis”, “Tas penuh”, “Belum siap diperah”, atau “Sudah dielus hari ini”.
- Co-op berbagi hewan, palung, stok, dan penanda aksi harian; biaya pakan/alat dan hasil panen memakai tas pemain pelaku. Dua pemain dapat membagi tugas tanpa menggandakan bonus atau produk.
- Simpan ID hewan stabil, kandang asal, nama, spesies/varian, kasih sayang, tanggal makan/elus/sikat, kondisi, penghitung produksi, hasil siap beserta kualitas, kotoran, stok pakan, dan hari evaluasi terakhir.
- Pergantian hari dievaluasi sekali sebelum reset penanda harian dan auto-save. Reload, perpindahan scene, pingsan, serta menu pemain lain tidak boleh mengulang produksi. Lompatan beberapa hari dievaluasi per hari dengan konsumsi stok nyata; tidak menganggap satu jatah cukup untuk semua hari.
- Migrasi save ayam mempertahankan nama, kasih sayang, tanggal perawatan, dan stok telur yang ada. Telur lama menjadi Normal; jangan menghapus hewan atau menghadiahkan produksi tambahan.

#### 4.10.8 Urutan Implementasi dan Kriteria Penerimaan [usulan]

| Tahap | Cakupan | Bukti penerimaan |
|---|---|---|
| A — Perjelas fondasi ayam | Ringkasan kebutuhan, tutorial, peringatan stok | Ayam kenyang memberi 1 telur esok hari; lapar 0; tas penuh mempertahankan hasil; reload/co-op tidak menggandakan aksi |
| B — Hewan hidup di ladang | Interior, elusan langsung, palung, jerami/silo, merumput dan pintu | Pakan dikonsumsi tepat satu jatah per hewan; rumput habis memicu kebutuhan cadangan; hujan/dingin mencegah merumput; hewan kembali dengan aman |
| C — Perawatan dan produk | Kebersihan, kondisi, sapi/kambing/domba, alat dan kualitas | Interval 1/2/3 hari terawat benar; sakit berhenti produksi dan dapat pulih; hasil siap tidak ditimpa; kualitas tercatat sebelum panen |
| D — Perluasan | Upgrade kandang, auto-feeder, bebek dan integrasi mesin | Kapasitas sesuai tier; stok silo berkurang sesuai konsumsi; kehabisan pakan terlihat; migrasi save mempertahankan ternak |

Playtest memeriksa durasi rutinitas 4 hewan, keterbacaan penyebab produksi gagal, manfaat memilih merumput/pakan, dan kemampuan meninggalkan ladang setelah kebutuhan utama selesai. Kerbau, pembiakan, festival, dan layanan kesehatan lanjutan dikerjakan setelah loop dasar stabil.

#### 4.10.9 Satwa Tambahan: Kerbau, Kapibara, Kuda [keputusan + terpasang]

Diputuskan pemilik 25 Oktober 2026 (memilih seluruh usulan). Data di `RanchHusbandry.SPECIES`; ketiganya tinggal di Barn dan memakai kapasitas 4/8/12, pakan, elusan, sikat, kebersihan, kesehatan, dan merumput seperti ternak lain.

| Hewan | Harga | Hasil | Interval | Catatan |
|---|---:|---|---:|---|
| Kerbau (`buffalo`) | 4.000 G | Susu Kerbau 180 G (+ ukuran/kualitas) | 2 hari terawat | Pemeras Susu; Mesin Keju: Susu Kerbau → Keju Kerbau 270 G |
| Kapibara (`capybara`) | 2.000 G | Tidak ada | – | Satwa ramah: selama satu kapibara Nyaman (makan, sehat, kotor < 3), hewan lain sekandang yang makan mendapat +1 kasih sayang tambahan saat pergantian hari; tidak menumpuk |
| Kuda (`horse`) | 5.000 G | Tunggangan | – | Maksimal 1 kuda per save; tidak dibiakkan |

Sprite `assets/farm_rpg/animals/{buffalo,horse,capybara}.png` memakai tata letak `cow.png` dan masih placeholder hasil recolor sapi (`scratch/gen_ternak_art.py` di folder proyek bersama); ikon toko kerbau memakai atlas `Animals farm icons.png`.

#### 4.10.10 Kuda Tunggangan [keputusan + terpasang]

- Tunggangi lewat tombol **Tunggangi** di menu kandang Barn (dibuka dari depan Barn) atau dengan berinteraksi pada kuda yang sedang merumput setelah dielus dan diberi pakan. Kuda harus dewasa, sudah makan hari itu, dan tidak Kurang sehat. Di dalam interior kandang kuda tidak bisa dinaiki.
- Kecepatan 1,6× di luar ruangan, naik linear sampai 1,8× pada kasih sayang 100. Tidak bisa sambil memakai kendaraan bagian 10 (sepeda/sapu), dan sebaliknya.
- Tombol interaksi saat berkuda = turun; kuda kembali ke kandang. Masuk interior/gua, pingsan, atau tidur menurunkan pemain otomatis. Co-op: satu kuda hanya dinaiki satu pemain.
- Status tunggangan tidak disimpan; setelah memuat save pemain berjalan kaki.

#### 4.10.11 Pembiakan, Inkubasi, dan Hasil Tambahan [keputusan + terpasang]

- **Pembiakan Barn**: tombol **Kawinkan** (gratis) untuk hewan dewasa dengan kasih sayang ≥ 80 (4 hati), Nyaman, kandang punya tempat, dan belum ada kehamilan lain di kandang itu. Lama hamil dalam hari terawat: sapi 6, kambing 5, domba 5, kerbau 7, kapibara 4; hewan hamil tetap berproduksi. Bila kandang penuh saat lahir, kelahiran menunggu sampai ada tempat.
- **Inkubator** (`incubator`): dirakit (50 kayu + 2 batang besi + 1 kuarsa), dipasang sekali di Kandang Unggas lewat menu kandang. Satu telur ayam (3 hari) atau bebek (5 hari), semua ukuran/kualitas. Ayam yang menetas berwarna putih/cokelat bergantian. Kandang penuh menunda penetasan.
- **Anak hewan**: dewasa setelah 3 hari (unggas) atau 5 hari (Barn), ditampilkan 65% ukuran, perlu dirawat, tidak berproduksi/dibiakkan/ditunggangi. Nama awal "Anak …" dapat diganti di kartu hewan.
- **Bulu Bebek** (`duck_feather`, 250 G): bebek dengan kasih sayang ≥ 60 dan kandang tidak penuh kotoran mengumpulkan 1 kemajuan per hari terawat; tiap 4 hari satu bulu masuk stok kandang bersama telur (batas 999). Kualitas tidak berlaku.
- **Pupuk kandang** dari usulan tidak dibuat karena sistem pupuk dari kotoran belum ada.
- **Save v26**: per hewan `baby_days`, `pregnant`, `feather`; per kandang `incubator` {`installed`, `egg`, `days`}. Save lama dimuat sebagai hewan dewasa tanpa kehamilan/inkubator. Regresi: `tests/ranch_expansion_regression.tscn`.

### 4.11 Mesin Pengolah Pasca-Panen (Artisan Goods & Processing) [keputusan]

Mesin pengolah yang dapat dirakit melalui Crafting dan ditempatkan di ladang atau gudang untuk mengubah komoditas mentah menjadi produk bernilai tinggi:
- **Mayonnaise Maker**: Telur biasa $\rightarrow$ Mayones (nilai jual +50%); Telur Emas/Besar $\rightarrow$ Mayones Kualitas Emas.
- **Cheese Press**: Susu Sapi $\rightarrow$ Keju Batangan; Susu Kambing $\rightarrow$ Keju Kambing (*Goat Cheese* bernilai jual tinggi).
- **Preserves Jar (Toples Pengawet)**: Buah segar $\rightarrow$ Selai Manis (*Jam*); Sayuran $\rightarrow$ Acar Segar (*Pickles*).
- **Keg (Tong Fermentasi)**: Gandum $\rightarrow$ Bir Olahan; Buah $\rightarrow$ Anggur/Jus Buah Fermentasi (membutuhkan waktu fermentasi 2–4 hari). Catatan [terpasang]: tong fermentasi (`fermentation_barrel`) dan butter churn saat ini dibeli di toko Dapur Nusantara, bukan dirakit.
- **Loom (Alat Tenun)**: Wol domba $\rightarrow$ Kain Halus (*Cloth*) untuk bahan pakaian dan dekorasi.
- **Oil Maker**: Jagung / Biji Bunga Matahari / Truffle $\rightarrow$ Minyak Masak & Minyak Truffle bernilai mewah.
- **Fish Smoker (Pengasap Ikan)**: Ikan mentah + kayu $\rightarrow$ Ikan Asap bernilai jual 2x lipat dan memulihkan stamina tinggi.

---

### 4.12 Upgrade Rumah di Wira [terpasang 2026-10-18 + angka usulan]

Upgrade rumah dipesan ke **Wira**, tukang kayu di Bukit (layanan "Bangun / Upgrade"), lewat kartu pertama "Upgrade Rumah" di menu bangunan yang sama dengan Kandang/Barn/Silo.

- **Alur** [terpasang]: pilih kartu, bahan diambil dari tas pemain yang memesan, uang dari kas bersama, bayar di depan. Wira bekerja beberapa hari (seperti Empu Bima); upgrade selesai saat pergantian hari ke-N setelah dipesan dan muncul Notify. Satu pesanan sekaligus, satu tingkat per pesanan. Tingkat rumah milik seluruh rumah tangga (co-op).
- **Data** [terpasang]: `HouseLevelData` (`scripts/resources/house_level_data.gd`), satu file per tingkat `resources/house/house_level_<n>.tres` (nama, deskripsi, ikon, harga, bahan, lama hari, flag, bonus stamina, pesan selesai). Logika di `HouseManager` (`scripts/system/house_manager.gd`, dipegang `GameState.house`).
- **Tingkat** [usulan, menunggu konfirmasi pemilik proyek; ubah angkanya di `.tres`]:

| Tingkat | Nama | Harga | Bahan | Lama | Membuka |
|---|---|---|---|---|---|
| 1 | Kitchen Room | 3.500 G | 120 kayu, 40 batu | 2 hari | Ruang dapur (flag `house_kitchen_upgraded`, pintu Dapur di rumah) |
| 2 | Spacious Bedroom | 12.000 G | 250 kayu, 120 batu, 8 iron bar | 3 hari | Stamina maksimum semua pemain +30 (`house_bedroom_upgraded`) |
| 3 | Grand House | 30.000 G | 400 kayu, 250 batu, 8 gold bar | 3 hari | Stamina maksimum +40 lagi, gudang bawah tanah (`house_cellar_upgraded`, untuk fitur tong nanti) |

- **Hubungan dengan dapur** [terpasang]: renovasi dapur tidak lagi dijual di toko Dapur Nusantara; toko itu tetap menjual kitchen set dan alat masak setelah tingkat 1 selesai. Pintu Dapur ditambahkan oleh `interior_house.gd` (posisi `kitchen_door_position`) karena node-nya tidak ada di `interior_house.tscn`.
- **Save v17** [terpasang]: key `house` = `{level, order: {level, ready_day}}`. Save v16 ke bawah tanpa key ini: tingkat 0, kecuali flag `house_kitchen_upgraded` sudah menyala (dapur dibeli di toko lama) = tingkat 1.
- **Belum** [usulan]: tampilan luar rumah belum berubah per tingkat (belum ada art rumah yang diperbaiki); gudang bawah tanah baru berupa flag.

### 4.13 Crafting Lanjutan [terpasang 2026-10-18 + angka usulan]

Semua resep di bawah memakai `CraftingRecipe` di `resources/crafting/catalog.tres` (meja crafting/tas), kecuali yang disebut stasiun. Bahan dan angka adalah usulan Claude dan bisa diubah langsung di `.tres`.

- **Senjata, armor, dan panah per tier** [terpasang]: Tembaga sampai Obsidian kini punya resep pedang, busur, tongkat sihir, helm, armor, celana zirah, sepatu, dan panah x10 (70 resep). Pola: pedang 3 bar + 4 kayu, busur 2 bar + 8 kayu + 6 serat, tongkat 2 bar + 6 kayu + permata, helm 3 bar + 2 serat, armor 5 bar + 6 serat, celana 4 bar + 4 serat, sepatu 2 bar + 4 serat, panah 1 bar + 2 kayu. Permata per tier: Tembaga kuarsa, Besi ametis, Emas topaz, Platinum zamrud, Crimson rubi, Frost safir, Shadow oniks, Fairy kristal peri, Obsidian kuarsa api. Pedang/busur memakai permata mulai Emas; armor mulai Crimson.
- **Peti tier 9-10** [terpasang]: Peti Fairy (120 slot, 20 Fairy Bar + 100 kayu) dan Peti Obsidian (132 slot, 22 Obsidian Bar + 110 kayu), juga lewat upgrade peti di tempat.
- **Dekorasi farm** (grup "Dekorasi") [terpasang]: Orang-orangan Sawah, Rumah Burung, Lampu Taman (menyala malam), Tumpukan Jerami, Ember Kayu, Tong Kayu, Kotak Surat Hias, Patung Batu, Manusia Salju, Palung Pakan, Api Unggun (animasi + cahaya), Lilin Hias (animasi + cahaya), Tumpukan Tong, Papan Pengumuman. Tambahan versi 3.19: Sumur Hias, Air Mancur, Ayunan, Jungkat-jungkit, Papan Petunjuk, Tikar Piknik (wol), Lampu Kembar (resin, menyala malam), Jemuran, Rumah Anjing (tulang tua), Penunjuk Angin Sapi dan Ayam, Lentera Resin (menyala malam), Pohon Natal, Kotak Pasir, Sapu Lidi Hias. Dipasang dan dikemas seperti pagar; hanya hiasan (orang-orangan belum mengusir gagak, sumur belum mengisi penyiram).
- **Mesin baru** (grup "Bangunan") [terpasang]:
  - **Sarang Lebah**: 1 Madu + 1 Lilin Lebah tiap 3 hari, dijeda Musim Dingin. Ini sumber pertama Lilin Lebah.
  - **Penggergajian**: 3 Kayu menjadi 1 Papan Kayu dalam 8 detik (`resources/sawmill/`).
  - **Meja Alkimia**: stasiun ramuan (`resources/crafting/alchemy.tres`): Ramuan Penyembuh (+60 HP), Ramuan Stamina (+80), Ramuan Kilat (kecepatan 1,3x 120 detik), Ramuan Pemulihan (+4 HP tiap 3 detik selama 60 detik), Ramuan Penyembuh Besar (sirup maple, +120 HP dan +40 stamina).
  - **Landasan Tempa**: stasiun cincin dan kalung Kayu sampai Obsidian (`resources/crafting/anvil.tres`); cincin = 2 bar + permata, kalung = 3 bar + permata (tier Kayu memakai tali). Puncaknya Cincin Prisma (ATK +22) dan Kalung Prisma (DEF +14) dari Pecahan Prisma + batangan Obsidian dan Fairy.
- **Bahan baru** (grup "Bahan") [terpasang]: Papan Kayu (penggergajian), Tali Sulur (4 serat), Kulit Olahan x2 (1 kain + 1 tar pinus), Umpan Buatan x5 (1 copper bar + 2 serat, bonus umpan 0,35).
- **Slot aksesori aktif** [terpasang]: slot Kalung (kalung, DEF +1..+11), Cincin (cincin, ATK +1..+18), dan Aksesori (sarung tangan kulit/besi/emas, tabung panah ATK +3). ATK dari perlengkapan kini ikut menambah serangan senjata di combat. Slot Perisai masih terkunci.
- **Save v20** [terpasang]: equipment menyimpan key `necklace`, `ring`, `accessory`; record sarang lebah (`job.day`, `ready` madu + `extra` lilin) dan penggergajian disimpan seperti furnace. Save lama: slot baru kosong.
- **Tidak dikerjakan** [catatan]: Butter churn dan tong fermentasi sudah dijual di toko Dapur Nusantara (bukan crafting). Bom, troli tambang, dan prop gua menunggu thread gua. Pagar besi/putih butuh autotile. Furnitur interior, buku, seruling, dan dekorasi pantai menunggu penempatan di luar farm / scene pantai.


### 4.14 Co-op Drop-in ala Stardew [keputusan 2026-10-19, terpasang]

Pemain lain bisa ikut atau keluar di tengah permainan tanpa kembali ke main menu. Keputusan pemilik proyek (2026-10-19): tanpa kabin (langsung ikut, tidur di rumah utama), cara ikut = tekan Start di gamepad yang belum dipakai lalu konfirmasi, karakter yang bisa dimuat hanya karakter co-op save ini, dan pemain boleh keluar di tengah permainan dengan data tersimpan.

- **Bergabung** [terpasang]: saat bermain (sendiri atau sudah co-op), gamepad yang belum dipakai menekan **Start**. Game dijeda sebentar dan menu "P2 bergabung" muncul, hanya dikendalikan gamepad itu (D-pad/stik pilih, A pilih, B batal, X dua kali = hapus karakter). Pilihan: karakter co-op save ini yang sedang tidak dimainkan, **+ Karakter Baru**, atau Batal. Karakter baru membuka layar kustomisasi yang sama dengan Game Baru, tetapi tanpa nama farm dan pet (milik P1); nama bawaan "Pemain N" sehingga bisa langsung lanjut dengan gamepad. Setelah memilih, layar terbagi dan pemain baru muncul di samping P1; semua pemain tetap di area dan posisinya.
- **Gamepad P1** [terpasang]: gamepad pertama yang dipakai P1 saat main sendiri tetap milik P1 setelah co-op dimulai (keyboard + mouse + gamepad itu), jadi Start-nya tetap membuka tas. Gamepad lain yang menekan Start dianggap pemain baru.
- **Keluar** [terpasang]: pemain tamu **menahan Start 1,5 detik** lalu memilih "Ya, keluar"; P1 juga bisa memakai tombol **Keluarkan <nama>** di menu pause halaman Permainan. Game disimpan saat pemain keluar. Layar sisa pemain digabung ulang; bila tinggal P1, game kembali ke main sendiri di area dan posisi P1.
- **Batasan** [terpasang]: bergabung/keluar ditolak (dengan Notify) saat ada pemain di gua, saat pemain sedang pindah area atau berbaring di kasur, saat transisi berjalan, dan (main sendiri) saat menu pause terbuka. Maksimal 4 pemain bersamaan.
- **Daftar karakter co-op** [terpasang]: tiap save menyimpan semua karakter co-op yang pernah ikut (maks. 8), termasuk yang sedang tidak bermain, seperti farmhand Stardew. Tas, stamina, HP, equipment, resep, persahabatan, ulang tahun, dan penampilan per karakter; uang tetap bersama. Game yang dimuat selalu mulai sendiri; pemain lain bergabung lagi dan memilih karakternya.
- **Lobby main menu** [terpasang]: tombol Co-op Lokal tetap ada; setelah lobby, tiap pemain tamu memilih karakter dengan menu yang sama. Bila semua tamu batal, game dimulai sendiri.
- **Save v21** [terpasang]: `coop_players` kini daftar semua karakter co-op dengan key `id` per karakter. Save v6-v20: P2-P4 lama menjadi karakter co-op pertama di daftar dengan id baru.
- **Catatan** [terpasang]: saat layar dibangun ulang (bergabung/keluar), area dimuat ulang seperti saat pindah pintu, jadi barang yang dijatuhkan di tanah dan musuh di area itu ikut direset; isi ladang, bangunan, dan tas tidak berubah. Uji tanpa gamepad di editor: F2 menambah/mengeluarkan pemain numpad (numpad 8456 jalan, 0 alat, 1 interaksi; tahan * untuk keluar).
- Kode: `autoload/coop.gd` (request_join, leave, current_plan), `scripts/system/coop_drop_in.gd`, `scripts/ui/coop_join_menu.gd`, `CoopRoot.spawn_plan`, `GameState.coop_roster`. Tes: `res://tests/coop_drop_in_regression.tscn`.

---

## 5. Sistem Memancing (Fishing) [terpasang + keputusan]

- Mini-game melempar kail dengan meteran tenaga, menunggu gigitan, dan menyeimbangkan barra tangkapan hijau mengikuti ikon ikan.
- 65 spesies ikan dengan 5 tingkat kelangkaan (Umum, Tidak Umum, Langka, Epik, Legendaris) dan variasi lokasi/jam tangkap.
- **Musim Ikan (`seasons` di `FishData`) [keputusan]**:
  - Ditambahkan atribut daftar musim ke dalam data ikan. Spesies ikan tertentu hanya dapat dipancing pada musim yang sesuai.
  - **[terpasang 18 Oktober 2026]** `FishData.seasons` (`spring`/`summer`/`fall`/`winter`); kosong = sepanjang tahun. `FishingManager.roll_catch` hanya memilih ikan musim berjalan.
  - Pembagian awal (usulan Claude, bisa diubah di `resources/fish_data/*.tres`): ikan umum air tawar (mas, lele, nila, carp, chub, perch, shad, sunfish, crayfish, bullhead catfish) sepanjang tahun. Musiman: Faeries Fish (semi); Frog, Large Mouth Bass (semi, panas); Tiger Trout (semi, gugur); Gurame (semi, panas, gugur); Dorado, Golden Fish (panas); Dynamite Fish (panas, gugur); Sturgeon (panas, dingin); Zombie Fish (gugur); Bone Fish, Ghost Catfish, Pike, Walleye (gugur, dingin). Laut: Clownfish, Dolphin (panas), Salmon (gugur), Glacier Fish (dingin).
  - Perbaikan data: lokasi ikan mas `" forest_river"` (berspasi) menjadi `"forest_river"`.
- **Air Beku Musim Dingin [keputusan]**:
  - Permukaan danau dan sungai biasa membeku di musim dingin sehingga aktivitas memancing di luar ruangan diblokir.
  - Pemain dapat memancing di musim dingin hanya jika telah membuka akses ke area pancing khusus (seperti pemandian air panas tersembunyi atau danau bawah tanah di dalam gua).
  - **[terpasang 18 Oktober 2026]** `FishingSpot.freezes_in_winter` (bawaan `true`). Di Musim Dingin meteran lemparan menandai air beku sebagai bukan air, dan lemparan ke air beku dibatalkan tanpa memotong stamina ("Air membeku di musim dingin..."). Spot khusus cukup memakai `freezes_in_winter = false`.
  - **Spot musim dingin [terpasang 18 Oktober 2026, keputusan pemilik proyek: keduanya]**, dibangun dari kode oleh `scripts/world/winter_pond.gd` (tepi kolam beranimasi dari "Water Ground animations tiles.png", isi warna Water tile, tabrakan bibir kolam):
    - **Kolam Air Panas** di Gunung (`mountain_hot_spring`, 8x6 tile di sisi barat, ada uap). Ikan: carp, perch, sunfish, pike, walleye, sturgeon, tiger trout.
    - **Danau Bawah Tanah** di Gua Tambang lantai 10 (`cave_lake`; lantai, posisi, dan ukuran di `CaveData.lake_floor/lake_cell/lake_size`). Ikan: crayfish, chub, bullhead catfish, ghost catfish, bone fish, zombie fish, dynamite fish.
    - Keduanya terbuka sepanjang tahun; tabel ikan tetap mengikuti musim. Pembagian ikan = usulan Claude, ubah lewat `locations` di `resources/fish_data/*.tres`.

---

## 6. Sistem Memasak (Cooking) [terpasang sebagian + keputusan]

**Nilai ekonomi [terpasang 22 Oktober]:** harga hasil dihitung sekitar 110% nilai jual seluruh bahan per batch dibagi jumlah hasil, dengan dependensi resep bertingkat ikut dihitung. Jika seluruh bahan bisa dibeli/dibuat dari bahan toko, harga hasil dibatasi agar bonus jual maksimum tidak menutup biaya beli termurah setelah diskon. Sebagian masakan bahan toko berfungsi sebagai konsumsi/buff, bukan jalur uang instan. Tool `tools/balance_audit.py` menghitung harga secara deterministik; 136 dari 137 harga output berubah. Contoh: Omelet 75 → 220 G, Mentega 55 → 220 G, Kopi 35 → 13 G. Harga buku, alat masak dan efek makanan tetap.


**Cakupan saat audit 22 Oktober 2026 [terpasang, kode/data]:** 137 Resource resep di `resources/cooking/recipes/`, 22 Resource alat di `resources/cooking/equipment/`, database `resources/cooking/data/recipe_database.tres`, dan `CookingManager`. Lima resep adalah cakupan tahap awal 14 Oktober, bukan jumlah konten saat ini. Resep yang dapat dimasak bergantung pada entri database, buku yang dipelajari karakter, alat yang tersedia, dan bahan. Jumlah Resource tidak membuktikan seluruh resep sudah dapat dibuat dalam permainan.

Dapur rumah setelah upgrade tingkat 1 di Wira, buku per pemain, pemulihan stamina/HP, buff laju dan regenerasi HP sudah memiliki implementasi. Hadiah resep sosial kini tersedia untuk 13 resident melalui kotak surat (12.4); Kanal memasak TV sudah mengajarkan resep; kelengkapan buff lanjutan masih memerlukan implementasi/verifikasi. Lihat `COOKING.md` untuk riwayat tahap dasar.

- **Status**: Disetujui untuk diimplementasikan [keputusan].
- **Fasilitas**: Dapur di interior rumah (setelah upgrade rumah) serta kompor/panci di Warung Makan kota.
- **Kategori Item**: Kategori baru `FOOD` (= 9) pada `ItemData.Category`.
- **Manfaat**:
  - Memulihkan Stamina dan Health Point (HP).
  - Memberikan efek status/buff sementara (kecepatan jalan, keberuntungan memancing, peningkatan serangan/pertahanan di dungeon).
- **Resep Masakan**: Menggunakan bahan hasil tani, ikan, telur/ternak, dan forage (misal: Ikan Bakar Lele, Sup Sayur Bening, Salad Buah, Roti Gandum, dsb.).
- Resep dipelajari dari siaran TV, membeli buku resep di Warung, atau hadiah persahabatan warga.

---

## 7. Ekspansi Pengumpulan Alam (Gathering Expansion) [terpasang]

- **Status**: Phase 4A-3 terpasang 18 Oktober 2026 (save v18). Keputusan pemilik proyek: jaring tier Kayu dibuat lewat crafting, tier berikutnya dibeli di toko hanya bila jaring sebelumnya sudah dimiliki; tangkap cukup dengan ayun; serangga dijual, jadi umpan, dan sebagian untuk paket Balai Nadi; tapper dari crafting, dipasang di pohon liar dan pohon tanaman pemain.

### 7.1 Jaring Serangga [terpasang]

| Jaring | Cara dapat | Harga | Syarat | Jangkauan | Stamina |
|---|---|---|---|---|---|
| Jaring Kayu | Crafting: 15 Serat + 10 Kayu | - | - | 20 px | 2 |
| Jaring Tembaga | Toko Umum | 2.000 G | Jaring Kayu | 28 px | 2 |
| Jaring Besi | Toko Umum | 5.000 G | Jaring Tembaga | 36 px | 1 |
| Jaring Emas | Toko Umum | 12.500 G | Jaring Besi | 48 px | 1 |

- Membeli tier baru menukar jaring lama di tas (jaring lama hilang). Toko menampilkan "terkunci" bila jaring sebelumnya belum ada. Harga, resep, dan stamina adalah pilihan Claude [usulan, bisa diubah].
- Ayunan memakai animasi `catch_insect` dan menangkap serangga terdekat dari titik ayun dalam jangkauan tier. Data: `resources/item_data/bug_net_*.tres`, `ToolData.BUG_NET_REACH`.

### 7.2 Serangga [terpasang]

15 serangga, data di `resources/bugs/*.tres` (item di `resources/item_data/`). Muncul per musim, siang (06-18) atau malam, dan area; serangga terbang melayang, serangga darat merayap, dan semuanya kabur bila pemain terlalu dekat. Tiap area punya batas jumlah: Ladang 5, Hutan 6, Kota 4, Gunung 4, Gua 3 (lantai biasa, bukan arena boss).

| Serangga | Area | Musim | Waktu |
|---|---|---|---|
| Kupu Kubis | Ladang, Hutan, Kota | Semi, Panas | Siang |
| Kupu Ujung Oranye | Ladang, Hutan | Semi | Siang |
| Lebah | Ladang, Kota | Semi, Panas | Siang |
| Ulat | Ladang, Hutan | Semi, Gugur | Siang |
| Kupu Raja (Monarch) | Hutan, Gunung | Panas, Gugur | Siang |
| Capung | Ladang, Hutan, Kota | Panas | Siang |
| Tonggeret | Hutan, Kota | Panas | Siang |
| Jangkrik | Ladang, Hutan, Kota | Panas, Gugur | Malam |
| Ngengat Luna | Hutan, Gunung | Semi, Panas | Malam (langka) |
| Kupu Morpho | Hutan | Panas | Siang (langka) |
| Kupu Laksamana Merah | Ladang, Kota, Gunung | Gugur | Siang |
| Ngengat Sutra | Kota, Gunung | Gugur, Dingin | Malam |
| Semut | Gua | Sepanjang tahun | Bebas |
| Kunang-kunang | Ladang, Hutan | Panas | Malam (bercahaya) |
| Ngengat Cinnabar | Gua | Sepanjang tahun | Bebas (langka) |

- Kegunaan: dijual, bahan resep umpan pancing, dan 5 serangga untuk paket Balai Nadi.
- **Umpan** [keputusan, 18 Oktober 2026]: umpan dibuat lewat crafting; serangga dan cacing mentah bukan umpan, hanya bahannya. Saat melempar kail, umpan termurah di tas dipakai otomatis (1 buah).

| Umpan | Resep | Hasil | Efek |
|---|---|---|---|
| Umpan | 2 Cacing | 5 | Waktu tunggu gigitan -20% |
| Umpan Serangga | 1 Jangkrik + 1 Ulat Daun | 5 | Waktu tunggu -30% |
| Umpan Kilau | 1 Kunang-kunang + 1 Ngengat Sutra | 3 | Waktu tunggu -40%, ikan langka lebih sering |

- **Paket Serangga** Balai Nadi (sayap Alam): Kupu Raja, Capung, Kunang-kunang, Jangkrik, Ngengat Luna, masing-masing 1. Hadiah: 3 Tapper. Data `resources/restoration/bug_bundle.tres`; `RestorationProject.reward_items` baru untuk hadiah barang.

### 7.3 Tapper [terpasang]

- Resep: 2 Batang Tembaga + 40 Kayu. Dipasang dengan menghadap pohon besar (pohon kecil tidak bisa). Satu tapper per pohon; panen dengan interaksi, lalu tapper mulai lagi.
- Game belum punya pohon ek, jadi resin datang dari birch dan mahoni [usulan]:

| Pohon | Hasil | Hari | Harga jual |
|---|---|---|---|
| Maple | Sirup Maple | 4 | 25 G |
| Pinus | Tar Pinus | 3 | 50 G |
| Birch | Resin | 3 | 60 G |
| Mahoni | Resin | 2 | 60 G |

- Menebang pohon bertapper menjatuhkan tapper (dan hasilnya bila sudah siap). Data tapper disimpan per world dan posisi pohon (save v18, kunci `gathering`).
- **Pohon tanaman pemain** [usulan]: pohon besar yang ditebang menjatuhkan biji pohon (30%): Biji Maple, Buah Pinus, Biji Birch, Biji Mahoni. Biji ditanam di tanah Ladang yang tidak dicangkul, tumbuh seperti pohon liar, dan bisa dipasangi tapper setelah besar.

### 7.4 Forage Musiman Kota, Gunung, Pantai [terpasang]

| Area | Semi | Panas | Gugur | Dingin |
|---|---|---|---|---|
| Kota | Daffodil, Bawang Daun, Kacang Polong Manis, Lidah Buaya | Bunga Matahari, Beri Liar, Blackberry, Lidah Buaya | Jamur, Hazelnut, Pala, Blackberry | Holly, Akar Musim Dingin, Hazelnut, Pala |
| Gunung | Bawang Daun, Kacang Polong Manis, Mooncap, Tanah Liat | Bunga Matahari, Beri Liar, Jamur, Kuarsa | Blackberry, Hazelnut, Truffle, Mooncap | Holly, Akar Musim Dingin, Tanah Liat, Kuarsa |
| Pantai | Kelapa Muda, Lidah Buaya, Kerang, Cangkang | Kelapa, Lidah Buaya, Cangkang, Bintang Laut | Kelapa, Kerang, Siput, Teripang | Kerang, Cangkang, Siput, Bintang Laut |

- Data `resources/forage_data/<area>_<item>.tres`. Kota dan Gunung aktif sekarang (ForageSpawner baru di `mountain.tscn`). Pantai belum punya scene; datanya aktif begitu scene pantai diberi ForageSpawner dengan lokasi `beach`.

---

## 8. Sistem Pertarungan (Combat) & Musuh [terpasang sebagian + keputusan]

**Balancing gua 22 Oktober:** rumus `max(1, ATK − DEF)` dipertahankan. ATK musuh/jurus boss dinaikkan mengikuti armor setingkat agar equipment tidak membuat seluruh rentang gua hanya memberi 1 damage. Fase, HP, pola serangan, telegraph, hadiah sekali dan checkpoint tidak diubah. Band awal dikurangi menjadi 1–2 musuh (lantai 1–5) dan 2–3 (6–10). Damage normal dengan empat bagian armor rujukan: lantai 3 Kayu 4; 8 Tembaga 1–4; 15 Tembaga 4–14; 30 Besi 6–14; 50 Emas 10–18; 70 Crimson 14–24; 90 Shadow 21–33. Aksesori, buff, block dan bonus role dapat mengurangi angka ini. Jurus boss fase pertama terhadap armor rujukan memberi 10–60 damage; fase/murka tetap menaikkan bahayanya. Angka lengkap ada di laporan balancing.


### 8.1 Cakupan Combat untuk Fase MVP [terpasang sebagian - Phase 4B-1, 4B-2]

**Implementasi Phase 4B-1 [terpasang, 17 Oktober 2026]:**
- **HP**: 100 per pemain (`PlayerData.hp`), terpisah dari stamina, disimpan per pemain (save v14; save lama dimuat dengan HP penuh). Pulih penuh saat tidur. Makanan memulihkan HP sebesar `ItemData.hp_restore` (default setengah dari pemulihan stamina); efek makanan dapat memberi `hp_per_tick`. Bar HP merah di HUD, di kiri bar stamina.
- **Kontrol**: pegang pedang/busur/tongkat di hotbar. **Klik kiri menyerang**, **tahan klik kanan untuk membidik** ke arah mouse (garis bidik menunjukkan jangkauan). Selama membidik, karakter berpose memegang senjatanya: busur ditarik, tongkat sihir terangkat (`WeaponStyle.aim_pose_frame`); klik kiri langsung melepas dari pose itu. Membidik sambil berjalan/berlari: badan tetap berpose bidik, kaki tetap melangkah (frame gabungan dibuat otomatis dari animasi jalan/lari).
- **Combo** (`WeaponStyle` grup Combo): klik kiri lagi saat serangan berjalan atau dalam 0,45 detik setelahnya menyambung pukulan berikutnya; jeda lebih lama atau ganti senjata mengulang combo. Combo 3 pukulan untuk semua senjata, pukulan ketiga adalah finisher (suara dan partikel `combo_finisher`):
  - Pedang: damage 100% / 100% / 150%, finisher tebasan lebih lebar (1,3x) dan knockback 2,5x.
  - Busur: tembakan ketiga melepas 2 panah menyebar 8 derajat, tetap memakai 1 anak panah.
  - Tongkat sihir: cast ketiga bola sihir 2x lebih besar, damage 150%, knockback 2x; stamina tetap 3 per cast.
- **Juice combat** (`scripts/combat/combat_juice.gd`, hanya visual/suara): musuh berkedip putih dan memipih saat kena; hitstop dan getar kamera sebanding damage (finisher lebih berat); angka damage meloncat (finisher besar dengan "!"); busur tebasan pedang; ekor cahaya panah/bola sihir dan percikan saat pecah; musuh mati meledak jadi partikel dan cincin, jarahan berhamburan satu per butir; penghitung combo "x2"/"x3!" dan zoom kamera saat finisher.
- **Pemain terluka**: percikan darah ke arah dorongan plus noda di tanah yang memudar, pinggir layar berkedip merah, dan saat HP di bawah 25% waktu melambat sesaat (solo). Bar HP bergetar, meneteskan darah, menyisakan bar putih yang menyusul turun, dan berdenyut merah saat HP rendah. Tanpa membidik, serangan mengarah ke arah hadap. Saat memegang senjata, klik kanan tidak dipakai interaksi (gunakan E/X). Gamepad menyerang ke arah hadap.
- **Senjata** (`resources/combat/*.tres`, WeaponStyle): pedang tebasan sekitar 1,5 tile di depan tanpa stamina; busur proyektil 8 tile, memakai 1 anak panah terkuat di tas ("Tidak ada anak panah!" bila habis), tanpa stamina; tongkat sihir bola energi 6 tile tanpa amunisi, 3 stamina.
- **Rumus**: damage = `max(1, ATK - DEF)`. ATK = ATK senjata (+ ATK anak panah); DEF pemain = total DEF helm, armor, celana, sepatu.
- **Terkena serangan**: 0,8 detik kebal (berkedip), knockback, animasi damage, angka damage melayang.
- **Musuh target** (`resources/enemies/*.tres`, EnemyData, art dari `assets/farm_rpg/Enemy`): Slime Hijau, Slime Biru, Myconid Merah. Melukai bila disentuh, mati dengan animasi Dead dan menjatuhkan item (slime: Slime Gel, myconid: Common Mushroom). Suara kena/mati per musuh (`EnemyData.hit_feedback`, `death_feedback`).
- **Kalah**: lihat bagian 4.2 (Klinik sebagai transisi + denda, lalu bangun di rumah).
- **Uji cepat (build debug)**: Ctrl+F7 memunculkan slime di depan pemain, Ctrl+F8 memberi 20 damage ke diri sendiri, Ctrl+F9 memberi pedang, busur, 30 anak panah, dan tongkat sihir kayu. Ctrl+F6 langsung memegang tongkat sihir kayu di slot hotbar aktif dan mengisi penuh stamina; Ctrl+F10 langsung memegang busur kayu dan menambah 30 anak panah kayu. Tes otomatis: `tests/combat_regression.tscn`.
- **AI musuh [terpasang, Phase 4B-2, 17 Oktober 2026]** (`scripts/combat/enemy.gd`, angka di grup AI `EnemyData`). State machine: **Diam** (1-2,5 detik) lalu **Patroli** acak dalam radius 40 px dari titik muncul; **Mengejar** pemain terdekat dalam radius aggro (slime 80 px = 5 tile, myconid 96 px); **Ancang-ancang** 0,35-0,45 detik (musuh berkedip merah, jendela pemain menghindar); **Menyerang**: slime menerjang (lunge) ke arah pemain, myconid mengayun kapak (Attack.png, damage di frame 3 bila pemain masih di depan); **Jeda** 1-1,5 detik; **Tertegun** 0,25-0,35 detik setelah dipukul (plus knockback; dipukul panah/sihir dari jauh langsung mengincar penembaknya); **Pulang** ke titik muncul bila pemain lebih jauh dari 150 px atau musuh terlalu jauh dari asal. Pemain yang pingsan/kalah diabaikan. Animasi jalan/serang 4 arah dari baris sheet (bawah, atas, kanan, kiri). Kecepatan: slime hijau 38 px/detik, slime biru 46, myconid 30. `ai_enabled = false` membuat musuh kembali jadi target diam.
- Gua/dungeon dan Toko Combat: terpasang di Phase 4B-3, lihat bagian 9.

**Rancangan awal (acuan):**
Untuk fase MVP, sistem combat dirancang ringkas, fungsional, dan stabil untuk melengkapi alur dungeon:
- **Bar Health Point (HP)**: Pemain memiliki bar HP terpisah dari Stamina (dasar 100 HP). HP pulih saat tidur atau makan makanan bergizi.
- **Kondisi Kalah**: Jika HP habis (0), pemain pingsan dan terbangun di Klinik Desa dengan sanksi denda uang dan/atau kehilangan sebagian item ransel.
- **Tipe Senjata Dasar**:
  - Pedang (*Sword*): Ayunan jarak dekat (*melee slash*) dengan hitbox area di depan pemain.
  - Busur & Anak Panah (*Bow & Arrow*): Menembakkan proyektil lurus (*ranged projectile*) dengan konsumsi panah dari inventori.
  - Tongkat Sihir (*Staff*): Menembakkan proyektil energi sihir (*magic projectile*).
- **Formula Stat Sederhana**:
  - `Damage_Diterima = max(1, Serangan_Musuh - Total_Defense)`
  - `Damage_Diberikan = max(1, Serangan_Senjata + Bonus_Stat - Defense_Musuh)`
- **Toko Perlengkapan Tempur (Combat Shop / Guild Petualang)**:
  - Bertempat di area pintu masuk Gua/Dungeon.
  - Menjual amunisi panah, pedang, tongkat sihir, serta 80 item perlengkapan (helm, armor, celana, sepatu dari tier Kayu hingga Obsidian) dengan harga berjenjang dan bernilai tinggi (*worth it*) untuk fase late-game.
- **AI Musuh MVP**: State machine sederhana (*Idle/Patrol* $\rightarrow$ *Mengejar dalam radius aggro* $\rightarrow$ *Menyerang saat jarak dekat* $\rightarrow$ *Knockback saat terkena pukulan*).

---

### 8.2 Visi Pengembangan Lanjutan: Sistem Combat 2D Top-Down Soulslike [keputusan - Roadmap Lanjutan]
Setelah fase MVP rampung, sistem combat akan dievolusikan menjadi sistem pertarungan **2D Top-Down Soulslike** yang kompleks, menantang, presisi (*deliberate*), dan membutuhkan penguasaan ritme bertarung.

#### A. Mekanika Tempur Kompleks Berbasis Stamina & Timing (Soulslike Core) [terpasang 2026-10-17]
1. **Stamina-Driven Combat**:
   - Setiap aksi tempur—menyerang (*light/heavy*), menghindar (*dodge roll*), menangkis (*parry/block*), dan berlari—mengonsumsi Stamina.
   - Jika stamina terkuras habis (0), pemain mengalami penalti *Exhausted* (kecepatan gerak melambat drastis, tidak bisa menyerang atau menghindar selama 1–1,5 detik). Manajemen stamina menjadi faktor krusial hidup dan mati.
2. **Dodge Roll & Jendela Invulnerability Frames (I-Frames)**:
   - Pemain dapat melakukan *dodge roll* ke arah gerak atau hadap mouse/gamepad.
   - Terdapat jendela singkat *i-frames* (misal: 10–14 frame / 0,2 detik) di mana pemain kebal terhadap damage proyektil dan tebasan.
   - Efisiensi roll dipengaruhi oleh beban perlengkapan (*Equip Load*): Fast Roll (beban ringan), Medium Roll (beban sedang), Heavy Fat-Roll (beban berat dengan i-frame minimal).
3. **Parry, Block, & Riposte Counter-Attack**:
   - **Block**: Menahan tombol pertahanan mengurangi damage yang masuk (persentase damage reduction tergantung perisai/senjata) dengan mengorbankan stamina.
   - **Timed Parry**: Menekan tombol parry tepat sebelum serangan musuh mendarat (jendela presisi 4–8 frame).
   - Parry sukses memicu efek visual dentingan kilat (*parry flash*), suara benturan nyaring, meniadakan damage, dan membuat musuh terkena status **Stagger**.
   - Pemain dapat mendekati musuh yang stagger untuk melancarkan serangan pemungkas berdaya hancur tinggi (**Riposte / Critical Strike**).
4. **Sistem Poise & Stagger Meter (Pemain & Musuh)**:
   - Baik pemain maupun monster memiliki nilai ketahanan benturan (*Poise*).
   - Serangan berat (*Heavy Attack*) atau kombo berkelanjutan mengikis bar poise musuh tersembunyi.
   - Ketika poise musuh pecah, musuh terpelanting atau terdiam sementara (*groggy/stagger*), membuka jendela serangan bebas.
5. **Attack Commitment & Frame Data Presisi**:
   - Setiap serangan memiliki 3 fase animasi tegas:
     - *Startup Frames* (ancang-ancang pukulan).
     - *Active Hitbox Frames* (area senjata menghasilkan damage).
     - *Recovery Frames* (waktu jeda kembali ke posisi netral).
   - Pemain tidak dapat sembarangan membatalkan (*cancel*) animasi di tengah ayunan tanpa perhitungan matang (*no mindless button mashing*).
6. **Variasi Serangan & Weapon Arts**:
   - *Light Attack Combo*: Rangkaian 2–3 tebasan cepat.
   - *Heavy / Charged Attack*: Tahan tombol serang untuk pukulan bertenaga besar dengan daya kikis poise tinggi.
   - *Sprint Attack / Roll Attack*: Gerakan tebasan unik segera setelah berlari atau selesai melakukan dodge roll.
   - *Weapon Arts / Skill*: Setiap tier senjata unik memiliki skill khusus (misal: Obsidian Sword memiliki tebasan api gelap beruntun; Fairy Staff memiliki lingkaran sihir penyembuh/penembus zirah).
7. **Visceral Game Feel & Feedback**:
   - *Hitstop (Micro-freeze)*: Jeda waktu mikro 0,05–0,1 detik saat benturan keras mengenai target untuk memberikan sensasi bobot pukulan.
   - *Directional Screen Shake*, percikan partikel benturan, dan angka damage bergaya RPG bertekstur.

**Implementasi 8.2-A (terpasang 2026-10-17)**
- **Keputusan stamina**: combat memakai **bar stamina tempur terpisah** (100, pulih 45/detik setelah jeda 0,7 detik, tampil di atas kepala pemain). Stamina harian kerja kebun dan aturan pingsan saat stamina harian 0 tidak berubah. Bar tempur habis = *Exhausted* 1,2 detik (gerak ×0,35, tidak bisa serang/roll/block). Stamina tempur tidak disimpan (tidak ada perubahan save).
- **Kontrol**: Spasi = dodge roll (atau Shift ditekan singkat sambil memegang senjata), klik kanan tahan = block, klik kanan tepat sebelum kena = parry (pedang), tahan klik kiri 0,45 detik = serangan berat, F = Weapon Art, Q = lock-on. Gamepad: RB = serang, RT = serangan berat, B tekan singkat = roll (tahan = lari), LB = block/parry, LT / L3 = Weapon Art, R3 = lock-on (diperbarui v3.24, lihat 4.3).
- **Roll**: kelas dari rasio beban perlengkapan (helmet/armor/leggings/boots × bobot tier): Fast < 0,3, Medium < 0,7, Heavy Fat-Roll. Jarak 56/46/30 px, i-frames 0,22/0,18/0,08 detik, biaya 16/20/26. Visual sementara: putaran/pipihan sprite + jejak bayangan (belum ada sheet roll).
- **Block/parry**: block hanya dari depan (±75°), damage dikurangi per senjata (pedang 75%, tongkat 55%, busur 40%), biaya 2 stamina per poin ditahan, gerak ×0,5. Jendela parry 0,12 detik dengan anti-spam 0,45 detik; parry sukses = kilat "PARRY!", hitstop, musuh Stagger 1,6 detik. Pukulan ke musuh yang Stagger dalam 26 px = Riposte ×3 (KRITIS!).
- **Poise**: musuh punya poise tersembunyi (slime hijau 18, slime biru 26, myconid 45); habis = Stagger ("Goyah!", damage ×1,5). Poise pemain 10 + 1,5 per satuan berat; pecah = serangan terputus 0,45 detik.
- **Frame data**: startup tidak bisa dibatalkan; hitbox aktif sampai rasio active_end; akhir recovery bisa dibatalkan dengan roll.
- **Variasi**: heavy (damage, jangkauan, poise lebih besar), sprint attack (lunge, 0,15 detik setelah lari), roll attack (0,35 detik setelah roll), riposte, dan 10 Weapon Art per senjata (satu per tier), mis. Obsidian Sword "Api Gelap Beruntun", Fairy Staff "Lingkaran Penyembuh Peri" (pulih 25 HP), tongkat "Sinar Penembus Zirah" (abaikan DEF).
- **Data**: aturan umum di `resources/combat/combat_rules.tres` (CombatRules), angka per senjata di `resources/combat/<senjata>.tres` (WeaponStyle), Weapon Art di `resources/combat/arts/`, poise musuh di EnemyData. Semua angka sementara untuk penyeimbangan.

#### B. Kecerdasan Buatan Musuh Tingkat Lanjut (Behavior Tree AI) [terpasang 2026-10-17]
Musuh non-boss dan elite enemy tidak lagi sekadar berjalan lurus mengejar pemain, melainkan dikendalikan oleh sistem **Behavior Tree (BT)** dinamis:
1. **Arsitektur Node Behavior Tree**:
   - Dibuat modular menggunakan struktur Composite (*Selector, Sequence, Parallel*), Decorator (*Repeater, Inverter, Cooldown, Limit*), dan Leaf (*Condition checks, Action execution*).
2. **Sistem Sensorik & Persepsi (Dynamic Perception)**:
   - *Vision Cone (Sudut & Jarak Pandang)*: Musuh memiliki sudut pandang hadap (misal 110°) dan jarak pandang efektif yang dipengaruhi pencahayaan gua/malam hari.
   - *Hearing / Acoustic Radius*: Musuh mendeteksi suara langkah lari cepat pemain, benturan penambangan beliung, atau suara senjata beradu.
3. **Hierarki Status Kesadaran (Dynamic Alert States)**:
   - `Idle / Patrol`: Musuh berpatroli acak atau menjaga pos tertentu.
   - `Suspicious / Investigate`: Jika mendengar suara atau melihat siluet sekilas, musuh berjalan waspada ke lokasi sumber gangguan.
   - `Aggro Combat`: Menyadari pemain sepenuhnya dan mengambil sikap bertempur.
   - `Flanking / Repositioning`: AI musuh kelompok secara cerdas mengatur posisi mengepung (*surround/flank*), menjaga jarak dari jangkauan pemain, atau menembak dari balik perisai kawannya.
   - `Retreat / Desperation`: Musuh ber-HP rendah dapat mundur ke belakang kawannya atau memanggil bala bantuan terdekat.
4. **Spacing & Anti-Spam Coordination**:
   - Musuh memiliki token serang (*attack ticket system*); tidak semua musuh menyerang pada milidetik yang sama, melainkan bergantian melakukan kombo, feint (serangan pancingan), atau serangan silang terkoordinasi.

**Implementasi 8.2-B (terpasang 2026-10-17)**
- **Behavior Tree**: `scripts/ai/behavior_tree.gd` berisi node Selector (reaktif, cabang prioritas tinggi menyela), Sequence (Condition dicek ulang tiap tick), Parallel, Inverter, Repeater, Cooldown, Limit, Condition, Action, dan Wait. Pohon musuh biasa di `scripts/ai/enemy_brain.gd`, urutan prioritas: mundur, bertarung (serang/feint/kejar/kepung), memeriksa gangguan, pulang, patroli.
- **Penglihatan**: kerucut pandang ke arah hadap (default 110°, myconid 120°), jarak pandang = `aggro_radius`. Gua ×0,6, malam paling gelap ×0,6 (bertahap mengikuti `DayCycle.night_intensity`). Tembok dan batu menghalangi garis pandang. Pemain dalam 22 px selalu ketahuan walau di belakang musuh. Di dalam kerucut tapi sedikit di luar jarak pandang (≤ ×1,4) = siluet sekilas (curiga).
- **Pendengaran**: lari (radius 64 px tiap 0,4 detik), beliung menghantam batu (112 px), senjata beradu saat memukul musuh, block, atau parry (96 px). Berjalan biasa tidak bersuara.
- **Status waspada**: Tenang/Patroli (sesekali menoleh), Curiga ("?", berjalan waspada ke sumber lalu menoleh kiri-kanan 3 detik), Aggro ("!"), Mengepung, Mundur. Target hilang dari pandangan 3 detik (myconid 4) = musuh mencari di posisi terakhir pemain terlihat; pemain kabur melewati `give_up_radius` = musuh pulang. Dipukul dari belakang = langsung berbalik ke penyerang.
- **Token serang**: maksimal 2 musuh menyerang satu pemain bersamaan. Musuh tanpa token mengepung di luar jangkauan pemain (attack_range + 22 px), bergeser ke sisi/belakang pemain dan menjaga jarak antar-kawan. Setelah menyerang, musuh memberi giliran 0,8 detik bila ada kawan yang menunggu.
- **Feint**: ancang-ancang palsu yang terlihat sama dengan serangan asli lalu lompat mundur; tidak bisa di-parry dan tidak melukai (memancing parry terlalu cepat). Peluang: slime hijau 0, slime biru 10%, myconid 25% (jeda 4 detik).
- **Mundur & bantuan**: HP ≤ 30% (slime biru 25%, slime hijau tidak pernah) = mundur ke belakang kawan terdekat sambil menghadap pemain selama 2,5 detik dan memanggil kawan dalam 112 px ("!!"), sekali per musuh. Setelahnya musuh nekat: ancang-ancang dan jeda serangan ×0,65. Bantuan = kawan yang sudah ada ikut aggro (tidak memunculkan musuh baru).
- **Musuh jarak jauh (18 Oktober)**: Pemanah Goblin dan Penyihir Spora mulai lantai 21, menggunakan token serangan, ancang-ancang 0,7 detik, menjaga jarak 70 px, memeriksa garis pandang sebelum menembak. Tembakan lurus berjangkauan 240 px berhenti pada tembok/batu dan pemain pertama; kawan musuh dilewati. Belum ada musuh perisai; boss memakai 8.2-C.
- **Data**: aturan umum di `resources/ai/ai_rules.tres` (AiRules), angka per musuh di grup Persepsi dan Taktik EnemyData. Debug: Ctrl+F12 menampilkan kerucut pandang (warna = status waspada), Ctrl+Shift+F7 memunculkan kawanan myconid + 2 slime biru.

**Rasa Senjata per Tier & Bidikan Jarak Jauh (terpasang 2026-10-17)**
Visual dan suara tidak mengubah angka combat. Satu-satunya bagian gameplay adalah **efek status tier tinggi** (v3.3, keputusan pemilik proyek), lihat di bawah tabel.
- **Identitas tier** (`resources/combat/tier_fx/<tier>.tres`, `WeaponTierFx`, dipakai pedang, busur, dan tongkat sihir):

| Tier | Ciri visual | Lapisan suara benturan |
|---|---|---|
| Kayu | debu, ekor pendek | 1 (kayu) |
| Tembaga | percikan oranye | 1 (timah) |
| Besi | percikan putih logam, halo kecil | 1 (logam) |
| Emas | kilau emas berkelip, cincin kejut | 2 (logam + lonceng) |
| Platinum | kilau perak-biru, gema tebasan | 2 (pelat + lonceng) |
| Crimson | bara merah naik | 2 (logam berat + pukulan) |
| Frost | serpih es, denting kaca | 2 (kaca) |
| Shadow | asap ungu-gelap | 3 |
| Fairy | debu peri merah muda-hijau, akor lonceng | 3 |
| Obsidian | api gelap + bara, dentuman bass | 3 + bass |

- **Efek status tier tinggi [keputusan 2026-10-17]** (grup "Efek status" di `WeaponTierFx`, berlaku untuk pedang, busur, tongkat, termasuk Weapon Art):

| Tier | Efek | Angka default |
|---|---|---|
| Kayu–Platinum | tidak ada (kekuatan dari ATK + Weapon Art) | – |
| Crimson | **Terbakar** | 30% per pukulan, 3 detik, tiap 0,5 detik damage 10% ATK (min 1) |
| Frost | **Dingin** | 35% per pukulan, 2,5 detik, gerak musuh ×0,6, ancang-ancang ×1,2 lebih lama |
| Shadow | **Serap Jiwa** | tiap pukulan masuk memulihkan HP 15% ATK (min 1) |
| Fairy | **Berkah Peri** | tiap pukulan masuk memulihkan 6 stamina tempur (tidak saat Exhausted) |
| Obsidian | **Api Gelap** | 40% per pukulan, 4 detik, tiap 0,5 detik damage 15% ATK, DEF musuh ×0,5 selama terbakar |

  Damage terbakar tidak memicu i-frames, dorongan, atau menyela AI, dan bisa membunuh musuh (loot normal). Efek yang sama memperbarui durasinya. Musuh berwarna jingga saat terbakar dan biru saat dingin, dengan teks dan partikel tier.
- **Eskalasi**: dari Kayu ke Obsidian, jumlah partikel benturan (6 sampai 32), panjang ekor proyektil (6 sampai 20 titik), partikel terbang (0 sampai 40/detik), cincin kejut, halo, tebal tebasan (×1 sampai ×1,8), bonus guncangan kamera (0 sampai 1,3 px), bonus hitstop (0 sampai 25 ms), lapisan suara, dan jumlah nada denting selalu naik atau tetap, tidak pernah turun. Tebasan Platinum ke atas punya busur gema kedua.
- **Bidik busur/tongkat (klik kanan ditahan)**: garis bidik bertitik yang mengalir dan makin terang, lingkar bidik di posisi mouse yang merapat, butir cahaya tier mengorbit ujung senjata. Tali busur berderit dan tongkat berdengung dengan nada yang naik selama ditarik.
- **Tarikan penuh** (`CombatRules.aim_draw_time` = 0,5 detik): kilatan, akor denting (1 nada Kayu sampai 5 nada Fairy/Obsidian), badan pemain berkilau sesaat, dan partikel tier keluar sesekali selama ditahan.
- **Melepas tembakan**: kilatan moncong, desau, dan badan tersentak mundur, semuanya makin besar per tier. Tembakan dari tarikan penuh menjadi *charged*: ekor lebih panjang dan tebal, angka damage bergaya berat, sedikit zoom kamera. Damage-nya sama. Setelah menembak, tarikan mulai lagi dari 0.
- **Suara sintetis**: derit, dengung, denting, desau, dan dentuman dibuat dari kode (`SfxSynth`), tanpa file aset baru.

#### C. Desain Pertarungan Boss yang Dinamis & Epik
Setiap wilayah kunci di Gua/Dungeon dijaga oleh **Boss Guardian** unik dengan mekanisme tempur berbobot:
1. **Boss Arena & Fog Gate**:
   - Pertarungan boss berlangsung di arena tertutup khusus dengan pintu kabut (*Fog Gate*), dilengkapi bar HP boss besar di bagian bawah layar dan latar musik orkestra bertempo dinamis.
2. **Multi-Phase Combat (Pertarungan Multi-Fase)**:
   - Boss memiliki 2 atau 3 fase pertarungan berdasarkan ambang batas HP (misal: Transisi di 50% HP).
   - Pada fase berikutnya, boss mengalami perubahan visual/aura (misal: terbakar api gelap), moveset serangan bertambah cepat, pola kombo lebih agresif, dan mendapatkan jurus pamungkas baru.
3. **Telegraphed Attacks & Visual Warning**:
   - Serangan mematikan dan serangan area (*AoE*) memiliki tanda visual (*telegraph*) yang jelas dan adil: kilatan mata merah, hentakan animasi ancang-ancang khas, atau indikator retakan tanah sebelum ledakan terjadi.
   - Pemain yang cermat mengamati ritme boss akan mampu menghindari serangan sepenuhnya menggunakan timing dodge roll atau parry.
4. **Dynamic AI Boss Counter-Tactics**:
   - *Anti-Kiting*: Jika pemain mencoba menjaga jarak dan menembak dari jauh, boss memiliki respon agresif (lompatan penghancur jarak jauh / *gap-closer dash*, atau proyektil berkecepatan tinggi).
   - *Unblockable Attack Indicator*: Serangan tertentu tidak bisa di-parry atau di-block (ditandai ikon bahaya khusus), memaksa pemain untuk menghindar (*roll/spacing*).
   - *Enrage Window*: Jika boss gagal di-stagger dalam periode tertentu, boss dapat memasuki mode buas singkat dengan peningkatan serangan.

##### Boss lantai 20: Raja Slime Emas [terpasang - 8.2-C, 17 Oktober 2026, keputusan pemilik proyek]
- **Aset**: Big Slime emas (`Enemy/Slimes/Golden/Big Slime`) diperbesar 2,5x; anak slime memakai Slime emas biasa. Data: `resources/enemies/boss_slime_king.tres` (`BossData`, turunan `EnemyData`), dipasang di `CaveData.bosses`. Kode: `Boss` (`scripts/combat/boss.gd`, turunan `Enemy`), `BossArena` (`scripts/world/boss_arena.gd`), `BossHealthBar` (`scripts/ui/boss_health_bar.gd`).
- **Statistik**: HP 450, ATK sentuh 10, DEF 4, poise 90 (terhuyung 2,4 detik), tidak terdorong.
- **Arena & pintu kabut**: lantai 20 tanpa batu/pilar. Baris 3-7 (titik tiba, tangga naik, lift) aman; melangkah melewati garis kabut di baris 8 menutup kabut menjadi tembok, boss bangun dengan raungan, bar HP besar muncul di bawah layar (nama, isi merah dengan sisa putih yang menyusul, garis ambang fase, label Fase/MURKA), dan genderang perang sintetis berbunyi (makin cepat tiap fase dan saat murka). Belum ada musik orkestra (menunggu aset).
- **Fase**: fase 2 di 50% HP, fase 3 di 20% HP. Tiap transisi = raungan (boss kebal), aura makin terang (jingga lalu merah tua) + bara. Tempo ancang-ancang 1,0 / 0,8 / 0,65; damage x1,0 / 1,15 / 1,3.
- **Jurus**:
  - *Hantaman* (tak bisa ditahan): retakan tanah + ikon bahaya muncul di titik pemain, boss melompat lalu mendarat di sana (radius 30, 22 damage). Fase 2 = 2 hantaman beruntun, fase 3 = 3.
  - *Terjangan* (bisa di-parry): kilat merah + panah arah, lalu menerjang (16 damage). Parry = boss terhuyung.
  - *Semburan* (bisa ditahan): 3 / 5 / 7 gumpalan emas menyebar (10 damage).
  - *Pecah* (fase 2+): memanggil 3 Anak Slime Emas (maks. 4 hidup), jeda 14 detik.
  - *Hujan Emas* (fase 3, jurus pamungkas): 7 retakan bertanda jatuh beruntun di sekitar pemain (18 damage, tak bisa ditahan), jeda 12 detik.
- **Serangan tak bisa ditahan**: ditandai segitiga merah berkedip (di atas boss dan di atas retakan). Menahan tetap kena damage penuh ("Tak bisa ditahan!"); roll dengan i-frame tetap lolos.
- **Anti-kiting**: pemain berada lebih jauh dari 110 piksel selama 2,5 detik = boss berteriak "Jangan lari!" lalu melompat menghantam (gap-closer) atau menyembur 1,8x lebih cepat.
- **Murka**: 25 detik tanpa di-stagger = MURKA 8 detik (damage x1,3, tempo x0,7, aura merah). Stagger memadamkan murka dan mereset hitungan.
- **Kalah / keluar**: bila semua pemain di arena keluar atau tumbang, pertarungan diulang (boss pulih penuh, kabut terbuka).
- **Hadiah pertama** (sekali): 2000 G, 5 Bijih Emas, 8 Bijih Besi, 10 Slime Gel, plus drop biasa 4-6 Slime Gel. Boss yang sudah kalah tersimpan di save v16 (`GameState.cave.bosses_defeated`); lantai 20 lalu kembali menjadi lantai tambang biasa dan lift 20 menjadi checkpoint aman.
- **Semua angka** bisa diatur di `boss_slime_king.tres` (grup Boss, Fase, Hantaman, Terjangan, Semburan, Anti-kiting, Pecah, Hujan Emas, Murka, Hadiah pertama).

---

##### Guardian lanjutan [terpasang 18 Oktober 2026; desain dan balancing sementara]

Lantai 21–100 kini bisa dicapai. Guardian berikut memakai mesin jurus boss yang sama dengan Raja Slime, dengan sprite, statistik, kombo, semburan, pemanggilan bantuan, dan hadiah berbeda. Belum memiliki animasi jurus atau moveset eksklusif baru.

| Lantai | Guardian | HP / DEF | Ciri pola | Hadiah pertama |
|---|---|---|---|---|
| 40 | Penjaga Besi (Myconid merah besar) | 850 / 8 | hantaman 2/2/3, memanggil Myconid | 4.000 G, 8 emas, 12 besi |
| 60 | Ratu Kristal (Slime biru besar) | 1.250 / 12 | semburan 5/7/9, hantaman 1/2/2 | 6.500 G, 8 platinum, 12 besi |
| 80 | Tiran Bara Beku (Myconid biru besar) | 1.800 / 16 | hantaman 2/3/4, memanggil penyihir | 9.000 G, 8 crimson, 12 besi |
| 100 | Penguasa Bayangan (Slime ungu besar) | 2.500 / 20 | hantaman 2/3/4, semburan 5/7/9, memanggil penyihir | 15.000 G, 8 obsidian, 12 besi |

Semua arena memakai fog gate, tiga fase, anti-kiting, murka, reset saat kosong, dan hadiah sekali yang tersimpan melalui save boss yang sudah ada. Sesudah menang, tangga turun langsung tersedia kecuali lantai 100. Slot `BossData.music` dan volume tersedia untuk aset musik loop; tanpa aset tetap memakai genderang sintetis. Musik berhenti saat reset/menang dan tempo naik per fase/murka. Musik orkestra masih menunggu aset. Playtest balancing combat panjang tetap diperlukan. Verifikasi sesi ini: parser, regresi gua, arena boss dan konten gua lanjutan lulus. Regresi combat umum masih gagal pada pemeriksaan `attack animations draw the weapon` (konfigurasi lapisan senjata karakter; di luar perubahan gua).

---

## 9. Gua Tambang & Dungeon [terpasang sebagian - Phase 4B-3 + keputusan]

- **Terpasang (Phase 4B-3, 17 Oktober 2026)**:
  - **Gunung** (`scenes/world/mountain.tscn`, `scripts/world/mountain.gd`): dataran batu kecil yang dicapai lewat celah utara Hill (`EnterMountain` di `hill.tscn`). Mulut Gua Tambang ada di tebing utaranya. Scene berupa node biasa (TileMapLayer, tabrakan, mulut gua) yang bisa diedit di editor. Mulut gua dimasuki otomatis saat diinjak. Akses Gua memerlukan jembatan Hutan selesai (`forest`); interaksi pertama setelah syarat terpenuhi membuka `cave` permanen tanpa biaya tambahan. Ini pilihan balancing sementara, dapat diubah di `UnlockManager.try_unlock_cave()`.
  - **Lobi gua** (lantai 0, node `Lobby` di `cave.tscn`): pintu keluar ke Gunung (dengan konfirmasi "Keluar dari gua?"), lift, **Toko Combat** (`resources/shop/combat_shop.tres`: pedang, busur, tongkat sihir, anak panah, helm, zirah, celana, sepatu tier Kayu-Emas, harga dari `ItemData.buy_price`), dan lubang turun ke lantai 1.
  - **Lantai 1-100** (`scenes/world/cave/cave.tscn`, `scripts/world/cave.gd`): satu scene untuk semua lantai, berupa node yang bisa diedit di editor (TileMapLayer `BaseLayerGround`/`CaveWalls` dengan `resources/world/cave_tileset.tres`, `Walls`, `FloorContent`, `Lobby`). Isi lantai dibangun ulang di tempat (pemain co-op di gua ikut pindah bersama); barang yang dijatuhkan di lantai sebelumnya dibersihkan saat pindah lantai. Layout batu, bijih, pilar, dan musuh diacak dengan seed `hari + lantai`: sama sepanjang hari, berganti esok hari.
  - **Tangga turun**: tiap batu yang dihancurkan berpeluang 8% memunculkan lubang tangga; tangga pasti muncul saat semua monster kalah atau semua batu habis. Injak lubangnya untuk turun (tanpa tombol interaksi). Tangga naik di titik tiba kembali ke lobi setelah konfirmasi "Naik ke lobi?". Pintu keluar lobi dan tangga naik langsung memunculkan konfirmasi saat pemain melangkah masuk ke areanya, tanpa tombol interaksi (tidak muncul sendiri saat baru tiba di titik tiba; keluar lalu masuk lagi untuk ditanya ulang). Selama konfirmasi terbuka, game dijeda saat main sendiri; saat co-op hanya pemain yang menyentuhnya yang terkunci, pemain lain tetap jalan. Keduanya juga tetap bisa dipakai dengan tombol interaksi (E / gamepad A) atau klik kanan; klik kanan yang diarahkan ke pintu/tangga di dekat pemain tetap membukanya walau sedang memegang senjata (di tempat lain klik kanan tetap membidik). Dialog konfirmasi dijawab dengan A / Enter / E (ya) dan B / Esc (batal), tanpa perlu memindah fokus tombol.
  - **Lift checkpoint** tiap 5 lantai (5–100) tersimpan permanen di save v15 (`GameState.cave`, `CaveManager`). Lift ada di lobi dan di lantai checkpoint.
  - **Lantai 20** adalah arena boss Raja Slime Emas (GDD 8.2-C) sampai boss kalah, lalu menjadi lantai tambang biasa. Tangga turun muncul setelah boss kalah; lantai 100 adalah batas akhir.
  - **Data** (`resources/cave/cave_data.tres`): tabel bijih dan musuh per rentang lantai (`CaveBand`: nama tier, ikon, warna aksen, warna ruangan). Tiap batu tambang dan kristal permata punya file sendiri di `resources/cave/ores/<item_id>.tres` (`CaveOre`: gambar di gua, beliung minimal, ketahanan, jumlah drop). Seluruh rentang sampai lantai 100 aktif.
  - **Penanda lantai**: lencana di tengah atas layar (per pemain di co-op) menampilkan nomor lantai, nama tier, dan ikon tier; ruangan gua juga diwarnai per tier.
  - **Tier lantai, bijih, dan permata [terpasang 2026-10-18; nama tier, permata, harga, dan bobot adalah pilihan sementara, bisa diubah di data]**:

    | Lantai | Tier | Bijih | Permata |
    |---|---|---|---|
    | 1-5 | Gua Batu | batu, batubara, tembaga | Kuarsa |
    | 6-10 | Gua Tembaga | batu, batubara, tembaga | Kuarsa, Topaz |
    | 11-20 | Gua Ametis | batu, batubara, tembaga | Topaz, Ametis |
    | 21-40 | Gua Besi | batu, batubara, besi | Ametis, Sitrin |
    | 41-60 | Gua Emas | batu, batubara, emas | Sitrin, Safir, Zamrud |
    | 61-80 | Gua Bara Beku | batu, platinum, crimson, frost | Safir, Zamrud, Rubi |
    | 81+ | Gua Bayangan | batu, shadow, fairy, obsidian | Rubi, Oniks, Kristal Peri |

    Mineral (kristal non-permata) ikut tampil sebagai kristal di gua: Kristal Bumi (lantai 1-20), Air Mata Beku (41-60), Kuarsa Api (61+). Pecahan Prisma hanya dari Geoda Pelangi.

    Permata adalah item bahan baru (`resources/item_data/`): Kuarsa 25 G, Topaz 40 G, Ametis 60 G, Sitrin 80 G, Safir 120 G, Zamrud 160 G, Rubi 220 G, Oniks 300 G, Kristal Peri 400 G. Kristal permata muncul sekitar 1-2 per lantai, ditambang dengan beliung dan menjatuhkan 1 permata. Bijih logam di gua kini memakai gambar batu besar berwarna dari `stone with minerals2.png` agar mudah dibedakan dari batu biasa. Bonus permata Geologist belum dibuat.
  - **Geoda dan Tanah Liat [terpasang 2026-10-18; peluang, harga, dan isi adalah pilihan sementara, bisa diubah di data]**: tiap batu yang dihancurkan di gua berpeluang menjatuhkan satu geoda sesuai tier (`CaveBand.geode_ids/geode_chances`); batu biasa juga berpeluang 6% menjatuhkan Tanah Liat (`CaveOre.bonus_item_ids`). Geoda dipecahkan di Pandai Besi (Empu Bima): saat pemain membawa geoda, layar pecah geoda muncul dulu dengan tombol "Upgrade Alat" untuk lanjut ke upgrade. Isi diundi dari `resources/cave/geodes/<id>.tres`.

    | Geoda | Lantai (peluang per batu) | Biaya pecah | Isi |
    |---|---|---|---|
    | Geoda | 1-40 (4-6%), 41-60 (2%) | 25 G | tanah liat, batubara, tembaga, besi, Kristal Bumi, Kuarsa, Topaz, Ametis, Sitrin |
    | Geoda Beku | 41-60 (6%), 61-80 (3%) | 50 G | batubara, besi, emas, frost, Air Mata Beku, Kuarsa, Safir, Zamrud |
    | Geoda Magma | 61-80 (5%), 81+ (6%) | 75 G | batubara, emas, platinum, crimson, Kuarsa Api, Rubi, Zamrud, Oniks |
    | Geoda Pelangi | 21+ (1-2%) | 100 G | semua permata dan mineral, shadow/fairy/obsidian, Pecahan Prisma (sangat langka) |

    Harga jual: Tanah Liat 10 G, Geoda 50, Geoda Beku 100, Geoda Magma 150, Geoda Pelangi 200, Kristal Bumi 50, Air Mata Beku 75, Kuarsa Api 100, Pecahan Prisma 2000.
  - **Keputusan sementara (bisa diubah di data)**: beliung minimal per bijih satu tier di bawah logamnya (batu/batubara/tembaga: Kayu, besi: Tembaga, emas: Besi, platinum: Emas, dst.); jumlah batu 18-28 dan monster 2-5 per lantai di 1-20; musuh lantai 1-5 slime hijau, 6-10 slime hijau + biru, 11-20 slime biru + myconid.
  - **Debug**: Ctrl+F5 langsung masuk lobi gua.

- **Status**: Disetujui untuk diimplementasikan [keputusan].
- **Struktur Gua**:
  - Terletak di kawasan Pegunungan yang harus di-unlock terlebih dahulu.
  - Memiliki lantai bertingkat (misal: Lantai 1–100+) dengan lift checkpoint setiap kelipatan 5 atau 10 lantai.
  - Bebatuan di gua menghasilkan batuan bijih langka:
    - Lantai 1–20: Batu biasa, Tembaga, Batubara.
    - Lantai 21–40: Besi, Batubara.
    - Lantai 41–60: Emas (*Gold Ore*).
    - Lantai 61–80: Platinum, Crimson, Frost.
    - Lantai 81+: Shadow, Fairy, Obsidian, serta permata mulia.
  - Tangga turun ditemukan secara acak dengan menghancurkan batu atau mengalahkan semua monster di lantai tersebut.
  - Layout batu dan musuh di-reset setiap hari, sedangkan lantai checkpoint lift tersimpan secara permanen.
  - **Arena Pertarungan Boss [keputusan]**: Lantai-lantai pencapaian kunci (Lantai 20, 40, 60, 80, dan 100) merupakan lantai arena khusus yang dijaga Boss Guardian dengan mekanisme multi-fase, arena kabut (*Fog Gate*), dan drop item/mineral legendaris.

---

## 10. Kendaraan & Mobilitas [keputusan + terpasang 2026-10-25]

Keputusan awal pemilik tetap berlaku: sepeda dibeli di toko desa, sapu terbang adalah item sihir tingkat tinggi yang melintasi air atau jurang pendek, dan kendaraan tidak dipakai di ruangan sempit. Koreksi pemilik 25 Oktober 2026 **[keputusan]**: kecepatan kendaraan = kecepatan lari (Shift) tanpa menahan Shift, ditambah sedikit supaya terasa berbeda. Angka lama "2x / 3x jalan" diganti karena lari di kode sudah 3x jalan.

**Cara pakai [terpasang]:** kendaraan adalah item di tas (dibeli sekali per pemain, tidak bertumpuk). Pegang di hotbar lalu tekan tombol Alat untuk naik; tombol Alat lagi = turun. Selama menumpang: tidak ada alat, serangan, lompat, atau roll; interaksi (pintu, NPC, toko) tetap bisa; ganti slot hotbar tetap bisa tanpa turun. Petunjuk tombol HUD menampilkan "Interaksi" dan "Turun". Co-op: tiap pemain punya kendaraannya sendiri.

| Kendaraan | Item | Kecepatan | Kemampuan | Cara dapat | Status |
|---|---|---|---|---|---|
| Sepeda | `bicycle` | 3,3x jalan (lari +10%) | darat | Toko desa 5.000 G (jual 2.500 G) | [terpasang; harga usulan] |
| Sapu Terbang | `flying_broom` | 3,6x jalan (lari +20%) | melayang 6 px, melintasi air dan jurang pendek | Meja Alkimia: Sapu Lidi Hias 1, Fairy Bar 2, Fairy Crystal 3, Slime Gel 10 (jual 7.500 G) | [terpasang; resep usulan] |
| Skuter Listrik | `electric_scooter` | 3,45x jalan (lari +15%) | darat | Dealer Kendaraan Modern City 25.000 G | [data terpasang, terkunci sampai `modern_city`] |
| Mobil Bak Pengangkut | `pickup_truck` | 3,75x jalan (lari +25%) | darat, pemain di dalam kabin | Dealer Kendaraan Modern City 60.000 G | [data terpasang, terkunci sampai `modern_city`] |

**Aturan area [terpasang]:** scene yang path-nya berisi `interior` atau `/cave/` melarang kendaraan (rumah, toko, gua tambang). Node `VehicleZone` (properti `allowed`) di sebuah scene menimpa aturan ini. Saat masuk ruangan, kendaraan "diparkir": pemain turun otomatis, lalu otomatis naik lagi begitu keluar ke area luar. Status menumpang tidak disimpan (tanpa perubahan save; setelah load pemain berjalan kaki).

**Terbang di atas air [terpasang]:** sapu memakai tabrakan biasa kecuali air/jurang. Air dikenali dari TileMapLayer bernama "...water...", tekstur atlas tile berisi kata "water" (mis. `Water tile.png` di BaseLayerGround Farm), custom data bool `water` di TileSet, atau node tabrakan di grup `vehicle_water` (kolam air panas/danau gua sudah masuk grup ini). Jurang pendek = node di grup `vehicle_gap` atau custom data bool `gap`; belum ada jurang di peta sekarang. Turun dari sapu ditolak di atas air ("Tidak bisa turun di atas air.").

**Implementasi:** `scripts/data/vehicle_data.gd` (VehicleData: kecepatan, air/jurang, tinggi melayang, sembunyikan pemain, scene tampilan, `required_unlock`), `resources/vehicles/*.tres`, `ItemData.vehicle`, `scripts/state/ride_state.gd` (RideState, dibuat ToolController), `scripts/system/vehicles.gd` (aturan area, gerak terbang), `scripts/world/vehicle_zone.gd`, `scripts/world/vehicle_visual.gd` + `scenes/vehicles/<id>.tscn` (Node2D + Sprite2D yang bisa diedit di editor; baris sheet bawah/atas/samping, offset duduk, urutan gambar), art sementara `assets/vehicles/<id>.png` dan ikon `resources/icons/icon_<id>.tres` dengan palet Paletta. Toko menampilkan "Sudah dimiliki" bila kendaraan ada di tas dan "Terkunci" bila area syarat belum terbuka. Tes: `tests/vehicle_regression.tscn`.

**Usulan terbuka [usulan]:** harga sepeda dan resep sapu; kemampuan khusus Mobil Bak (bak muatan/peti berjalan) dan cara membuka `modern_city` menunggu desain Modern City; kuda tunggangan tetap bagian sistem Peternakan (4.10), belum memakai sistem kendaraan; animasi duduk khusus belum ada (pemain memakai pose diam).

---

## 11. Ekspansi Kota Modern (Modern City) [keputusan]

- **Status**: Visi Utama Arsitektur *Endless Game* [keputusan].
- **Mekanisme Pembukaan**:
  - Terbuka setelah pemain menyelesaikan restorasi seluruh fasilitas utama di Nusa Vale (Balai Nadi, Jembatan, Greenhouse, fasilitas kota).
  - Jalur transportasi dibuka (misal: perbaikan rel kereta api atau terminal feri pelabuhan).
- **Fitur Modern City**:
  - Lingkungan perkotaan modern (aspal, gedung tinggi, lampu kota, toko elektronik/teknologi).
  - Pembelian mesin pertanian otomatis (Sprinkler otomatis canggih, Drone panen).
  - Kendaraan modern (Skuter listrik / Mobil bak pengangkut).
  - Pasar ekspor komoditas dengan permintaan fluktuatif berhadiah besar.
  - Memastikan permainan memiliki progresi jangka panjang tanpa batas akhir yang kaku.

---

## 12. Hubungan Sosial, Persahabatan, & Warga Desa (NPC Schedules & Friendship) [terpasang sebagian + keputusan]

**Status 24 Oktober 2026:** Wira, Ubay, Eep, Zarathia, Zarathustra, Kirana, Bahar, Joko, Ratih, Rian, Damar, Bima dan Baskoro memiliki profil resident terpusat. Seluruhnya memiliki data sosial dasar, jadwal default/hujan, dialog hati dan lima milestone event dialog; reward resep/material mencakup 13 warga. Sebagian jadwal hujan masih mengikuti jadwal normal. Kunci hati permanen, upacara dasar, household per karakter, pasangan/roommate, bantuan harian dan surat tetap tersedia. Biografi/tanggal ulang tahun/kisah yang baru diisi merupakan baseline editorial yang dapat ditinjau. Lihat [laporan migrasi dan kekurangan](NPC_CENTRALIZATION_2026-10-24.md), serta [implementasi household sebelumnya](IMPLEMENTATION_SOCIAL_ROLE_2026-10-22.md). Target sinematik, pilihan bercabang dan fitur lanjutan di bawah belum seluruhnya selesai.

### 12.1 Filosofi Desain: Desa yang Hidup, Bernyawa, dan Personal
- **Bukan Boneka Statis**: Warga desa Nusa Vale memiliki kepribadian yang khas, rutinitas harian yang berubah sesuai cuaca dan musim (*Daily Schedules*), preferensi makanan/barang kesukaan yang unik, serta cerita kehidupan masa lalu yang terungkap seiring meningkatnya rasa percaya mereka kepada pemain.
- **Sistem Tingkat Persahabatan (Friendship Hearts 0–10)**:
  - Setiap warga desa memiliki bilah persahabatan berupa **10 Hati (`♥`)** (setara 250 poin per hati, total 2.500 poin persahabatan).
  - Poin persahabatan bertambah melalui:
    - **Sapaan Harian (Daily Chat)**: +20 poin (diajak bicara satu kali per hari).
    - **Pemberian Hadiah (Gifting)**: Maksimal 2 kali per minggu + bonus hadiah hari ulang tahun (8x multiplier):
      - *Sangat Disukai (Loved)*: +80 poin (memunculkan balon hati besar `♥♥` dan dialog gembira).
      - *Disukai (Liked)*: +45 poin (senyuman hangat dan ucapan terima kasih).
      - *Biasa Saja (Neutral)*: +20 poin.
      - *Tidak Disukai (Disliked)*: -20 poin (ekspresi kecewa).
      - *Dibenci (Hated)*: -40 poin (balon marah atau sedih).
    - **Menyelesaikan Permintaan Warga (Help Wanted Board)**: +100 poin (papan pengumuman di depan Balai Nadi/Toko).
    - **Berpartisipasi dalam Festival & Tradisi THR Lebaran**: Memberikan bingkisan atau bersilaturahmi memberikan bonus hubungan desa secara massal.
  - *Peluruhan Hubungan (Decay)*: Jika pemain tidak berbicara dengan warga selama berpekan-pekan, poin persahabatan berkurang sangat sedikit (hanya -2 poin/hari jika belum mencapai 10 hati; setelah 10 hati, hubungan permanen terkunci dan tidak pernah luntur). **[terpasang v25]:** `locked` dicatat setelah poin mencapai maksimum NPC (default 10 hati/2.500 poin). Setelah terkunci, poin tidak turun karena hadiah negatif maupun decay. Reaksi hadiah dan kuota/konsumsi barang tetap berlaku. Save lama tanpa `locked` dipromosikan bila poin saat ini maksimum; penanda ini tersimpan per karakter.

---

### 12.2 Jadwal Harian & Rutinitas Warga (Dynamic NPC Schedules)
Warga desa memiliki rutinitas realistis:
1. **Siklus Jam Harian**:
   - Bangun pagi di rumah masing-masing pukul 05:30–08:00.
   - Pergi ke tempat kerja/aktivitas luar ruangan:
     - **Empu Bima**: Bekerja menempa alat di bengkel tempa kota.
     - **Pak Joko**: Meracik hidangan dan melayani pengunjung di Warung Rasa Nusa.
     - **Wira**: Berpatroli di alun-alun, mengecek jalan setapak hutan, dan berlatih fisik.
     - **Rian**: Menggembala dan memberi makan hewan ternak di padang rumput kota.
     - **Pak Bahar**: Berlayar dan memancing fajar di dermaga jembatan selatan.
     - **dr. Ratih**: Membuka Klinik Desa dan meracik salep tanaman obat herbal.
     - **Ubay**: Berjalan santai pagi di alun-alun, nongkrong di taman air mancur, dan menikmati senja di jembatan.
     - **Prof. Baskoro**: Mengajar dan meneliti flora di Universitas desa.
     - **Pak Damar**: Merancang konstruksi dan renovasi bangunan pulau.
   - Istirahat siang berkumpul di Warung Makan Pak Joko atau duduk santai di bangku taman alun-alun.
   - Pulang ke rumah menjelang malam (pukul 19:00–21:30) dan tidur.
2. **Reaksi Adaptif Cuaca & Musim**:
   - *Saat Hujan / Badai*: Warga berteduh di dalam ruangan, membuka payung jika harus melintas, atau menghabiskan sore di Warung Makan.
   - *Saat Musim Dingin*: Warga mengenakan pakaian musim dingin tebal dan lebih sering berada di dekat perapian.
   - *Hari Libur & Festival*: Rutinitas dialihkan ke alun-alun kota atau tempat diselenggarakannya pesta.

---

### 12.3 Peristiwa Hati & Kisah Naratif (Heart Events)
- **Cutscene Spesial (Heart Events 2, 4, 6, 8, 10 Hati)**:
  - Memasuki lokasi tertentu pada jam tertentu saat ambang batas hati tercapai akan memicu adegan cerita sinematik khusus (*Heart Event*).
  - Menampilkan pilihan tanggapan dialog bercabang (*Dialogue Choices*) yang mempengaruhi kepribadian karakter dan bonus persahabatan ekstra.
- **Kunci Pintu Masuk Kamar**:
  - Pada 0–1 hati, kamar pribadi NPC terkunci (*"Pintunya terkunci."*).
  - Pada 2 hati ke atas, pemain mendapatkan izin masuk ke area kamar pribadi warga.

---

### 12.4 Resep Hadiah Masakan & Bingkisan Lewat Kotak Surat

**[terpasang 22 Oktober 2026]** Kotak Surat aktif di Farm, di kiri pintu rumah (berbeda dari dekorasi `mailbox_decor`). Ambang persahabatan mengantrekan surat sekali per reward, tiba esok hari. Selesaikan semua halaman untuk menerima resep gratis dan bahan; membatalkan atau tas penuh menjaga surat tetap belum diklaim. Resep milik karakter penerima, bukan seluruh sesi co-op. Surat cerita Wira tetap dapat dibaca melalui Wira dan juga kotak surat.

Konfigurasi awal di `data/npc/social/household_rules.json`: Wira 4 hati → Omelet + 5 kayu; Ubay 4 hati → Pancakes + 2 gandum; Eep 4 hati → Salad + 2 wortel; Zarathia 6 hati → Sun Tea + 1 madu; Zarathustra 6 hati → Vegetable Mix + 2 kentang. Ini konten awal dan angka balancing yang bisa diubah lewat data; target semua warga di bawah tetap lanjutan.

- Warga yang senang dengan pemain akan mengirimkan surat kejutan di kotak surat ladang:
  - Berisi resep masakan keluarga (*Family Recipes*) untuk dimasak di dapur rumah (misal: Pak Joko mengirimkan resep Rawon Rempah dan Sayur Lodeh Istimewa).
  - Bingkisan bahan material langka (misal: Empu Bima sesekali mengirim batangan besi/emas, warga tani mengirim bibit langka).

---

### 12.5 Romansa, Pernikahan, & Teman Sekamar (Romance, Marriage, & Roommates)

**Cakupan terpasang 22 Oktober 2026:** Zarathia/Zarathustra memakai syarat hati dari data untuk dating/lamaran. Lamaran memerlukan rumah tingkat 2 dan mengantrekan upacara esok hari. Temui NPC di rumah, pilih **Mulai Upacara Pernikahan**, lalu selesaikan dialog untuk meresmikan hidup bersama; batal tidak menyelesaikan upacara. Upacara saat ini memakai dialog berhalaman, belum adegan sinematik atau artwork khusus.

Pasangan kembali ke rumah sebelum 09.00 dan mulai 18.00; rutinitas siang tetap berjalan. Satu karakter memiliki satu household, dan NPC yang sudah pindah tidak dapat ditempatkan pada household kedua. Ubay/Eep dapat diundang sebagai teman sekamar platonis pada 10 hati dengan rumah tingkat 2; ada dialog penyambutan esok hari tanpa status romansa. Household dan progres upacara tersimpan untuk karakter co-op yang sedang offline juga.

Bantuan harian saat ini: sarapan Omelet menunggu di kotak surat (maksimal satu sarapan belum diambil); pada nomor hari genap menyiram crop Farm, pada hari ganjil memberi pakan ternak dengan mengonsumsi pakan/jerami dari tas pemilik. Greenhouse tidak ikut disiram. Bantuan dijalankan sekali per hari, termasuk saat pemilik tidak sedang ikut sesi. Ini perilaku awal yang dapat diperluas, bukan AI pekerjaan bebas. Buket, pendant, gate hati 9–10 melalui buket, cutscene/undangan tamu dan aktivitas keluarga lanjutan pada target di bawah belum terpasang.

- **Karakter Lajang (Marriage Candidates)**: Tersedia beberapa kandidat warga desa yang dapat dijalin hubungan romantis.
- **Pemberian Buket Bunga (Bouquet pada 8 Hati)**: Membuka hati ke-9 dan ke-10 sebagai tanda resmi berpacaran (*Dating*).
- **Lamaran & Bunga Pengantin (Pendant Lamaran pada 10 Hati)**:
  - Rumah pemain minimal telah ditingkatkan ke Level 2 (memiliki ranjang ganda).
  - Pasangan akan pindah tinggal bersama di rumah pemain, membantu menyiram tanaman sesekali, memberi makan ternak, atau memasakkan sarapan pagi hangat.
- **Pilihan Teman Sekamar Platonic (Roommate Option)**:
  - Pemain yang tidak ingin menikah dapat mengundang sahabat non-romantis (atau satwa/makhluk unik) untuk tinggal bersama sebagai teman sekamar platonis.

---

## 13. Sistem Role, EXP, dan Skill Tree (Co-op Synergy) [keputusan + terpasang sebagian]

### 13.1 Filosofi Desain & Arsitektur EXP: Opsi B (Per-Activity EXP) dengan Sentuhan Hybrid [keputusan]
- **Classless & Open Progression**: Pemain **tidak dikunci pada satu kelas tunggal**. Setiap pemain dapat meningkatkan level dan membuka skill dari ketujuh role yang tersedia secara bebas.
- **Arsitektur Progresi EXP (Opsi B — Per-Activity dengan Sentuhan Hybrid)**:
  1. **Core Per-Activity EXP Organik (90%) — "Practice Makes Perfect"**:
     - Setiap role mengumpulkan EXP secara mandiri dari aksi langsung di dunia permainan (misal: mencangkul menaikkan EXP *Farmer*, memancing menaikkan EXP *Fisher*, menambang menaikkan EXP *Miner*, bertarung menaikkan EXP *Combat*, transaksi bazaar menaikkan EXP *The Merchant*).
     - Pendekatan ini memberikan kepuasan penguasaan keahlian yang mendalam (*sense of mastery*) dan secara alami membentuk pembagian tugas gotong royong (*division of labor*) di sesi co-op tanpa mengorbankan fleksibilitas pemain solo.
  2. **Sentuhan Sistem Hybrid Fleksibel (10%) — "Universal Pathways"**:
     - *Buku Panduan & Riset Universitas (Tomes of Knowledge)*: Pemain solo atau pemain yang ingin mengejar ketertinggalan role tertentu tanpa grinding berlebihan dapat membaca atau membeli buku studi di Perpustakaan / Universitas desa untuk memperoleh EXP/Skill Point langsung pada role pilihan.
     - *Universal Skill Point dari Balai Nadi & Festival*: Menyelesaikan paket proyek restorasi Balai Nadi atau menjuarai festival musiman menghadiahkan *Universal Skill Point (Token Talenta)* yang bebas diklaim ke cabang pohon keahlian mana pun.
     - *Santap Malam Bersama di Co-op (Family Knowledge Exchange)*: Saat seluruh anggota keluarga/teman di sesi co-op makan bersama hidangan masakan dapur di meja makan rumah sebelum tidur, terpicu buff *Knowledge Exchange* yang mentransfer sedikit limpahan EXP silang antar pemain.
- **Solo Friendly, Co-op Empowered**:
  - **Solo**: Pemain dapat memainkan seluruh peran secara mandiri dan bertahap menjadi ahli serba bisa seiring perkembangan permainan.
  - **Co-op (Split-Screen bersama Teman / Keluarga)**: Siklus waktu harian yang terbatas (06:00–05:00) mendorong pemain untuk **berbagi tugas secara alami (*division of labor*)**. Tim yang membagi peran (misal: satu pemain fokus menambang & bertarung di gua, satu pemain mengurus ladang & memasak, satu pemain mengumpulkan hasil hutan, dan satu pemain memaksimalkan perdagangan) akan merasakan efisiensi dan kepuasan bermain yang berlipat ganda dibanding bermain sendiri.

---

### 13.2 Tujuh Role Utama & Mekanisme Perolehan EXP
Setiap role memiliki progresi level tersendiri (Level 1–10). Setiap aksi spesifik memberikan EXP pada cabang role terkait:

```
[Level 1-4: Fundamental Skills] ---> [Level 5: Percabangan Spesialisasi A/B] ---> [Level 6-9: Advanced Mastery] ---> [Level 10: Master Perk A/B]
```

#### 1. Farmer (Petani)
- **Aktivitas Penghasil EXP**: Mencangkul petak tanah, menyiram air, menanam bibit, memanen tanaman, dan merawat pohon buah.
- **Fokus Skill Tree**:
  - *Level 1–4*: Pengurangan konsumsi stamina alat cangkul dan kaleng air (-10% s/d -25%); peluang 10% tanah tetap basah keesokan harinya.
  - *Level 5 (Pilihan Spesialisasi)*:
    - **A. Agronomist**: Kecepatan pertumbuhan seluruh tanaman meningkat 15%.
    - **B. Bountiful Harvest**: Peluang 20% mendapatkan panen ganda (*double yield*) dari setiap petak.
  - *Level 6–9*: Jangkauan siraman air otomatis lebih efisien; peluang panen menghasilkan kualitas Bintang Perak/Emas bernilai jual tinggi.
  - *Level 10 (Master Perk)*:
    - **A. Perpetual Orchard**: Pohon buah menghasilkan panen dua kali lebih sering dan menghasilkan buah di luar musimnya.
    - **B. Green Thumb Mastery**: Tanaman ladang memiliki 50% ketahanan terhadap pergantian musim (tidak langsung layu di hari pertama musim baru).

#### 2. Forager (Pengumpul Alam)
- **Aktivitas Penghasil EXP**: Memungut tanaman forage liar musiman, menebang pohon di hutan/ladang, menebas rumput liar dengan sabit, menggali titik cacing.
- **Fokus Skill Tree**:
  - *Level 1–4*: Peluang 20% memungut 2x hasil forage liar; peluang menjatuhkan kayu ekstra saat menebang pohon.
  - *Level 5 (Pilihan Spesialisasi)*:
    - **A. Lumberjack**: Kapak memberikan damage 2x lipat pada pohon dan tunggul; peluang kayu keras (*Hardwood*) meningkat.
    - **B. Botanist**: Semua tanaman forage yang dipungut otomatis memiliki kualitas Bintang Emas (*Highest Quality*).
  - *Level 6–9*: Deteksi visual/kompas untuk titik cacing dan forage langka di peta; peluang serat (*Fiber*) 100% dari rumput liar.
  - *Level 10 (Master Perk)*:
    - **A. Forest Whisperer**: Bibit pohon di hutan tumbuh dewasa 2x lebih cepat; pohon yang ditebang otomatis menanam bibit baru di tempatnya.
    - **B. Ancient Tracker**: Peluang menemukan artefak purba, geoda langka, dan truffle dari titik gali meningkat 300%.

#### 3. Fisher (Nelayan)
- **Aktivitas Penghasil EXP**: Menangkap ikan (EXP berskala dengan tingkat kelangkaan ikan), menangkap peti harta karun saat memancing.
- **Fokus Skill Tree**:
  - *Level 1–4*: Memperlebar ukuran barra tangkapan hijau mini-game (+10% s/d +20%); mengurangi waktu tunggu ikan menggigit kail (*Nibble Window*).
  - *Level 5 (Pilihan Spesialisasi)*:
    - **A. Angler**: Harga jual seluruh tangkapan ikan meningkat 25%.
    - **B. Master Caster**: Jarak lemparan pancing bertambah 2 petak; jendela lemparan "Sempurna!" (*Perfect Cast*) 2x lebih lebar.
  - *Level 6–9*: Peluang 15% menangkap 2 ekor ikan sekaligus dalam satu tarikan; ikan liar bergerak lebih lambat dan tenang saat mini-game.
  - *Level 10 (Master Perk)*:
    - **A. Legend Hunter**: Peluang bertemu ikan legendaris dan ikan langka malam hari meningkat drastis.
    - **B. Icebreaker Fisherman**: Kemampuan memecahkan lapisan es untuk memancing di perairan mana pun selama musim dingin.

#### 4. Combat (Ksatria / Petarung)
- **Aktivitas Penghasil EXP**: Menyerang monster di gua, mengeksekusi timed parry sukses, membunuh musuh, menaklukkan Boss Guardian.
- **Fokus Skill Tree**:
  - *Level 1–4*: Peningkatan total Attack (+5 s/d +20); pengurangan biaya stamina saat melakukan serangan kombo dan dodge roll.
  - *Level 5 (Pilihan Spesialisasi)*:
    - **A. Duelist**: Jendela timing Parry meningkat 4 frame; serangan Riposte setelah stagger menghasilkan damage 2,5x lipat.
    - **B. Berserker**: Kecepatan ayunan senjata bertambah 20%; damage meningkat saat HP berada di bawah 40%.
  - *Level 6–9*: Peningkatan jendela I-Frames saat roll; daya kikis poise musuh (*Poise Damage*) bertambah; peningkatan HP maksimum (+20 HP per level).
  - *Level 10 (Master Perk)*:
    - **A. Soulforged Champion**: Membunuh musuh memulihkan sejumlah HP dan Stamina secara instan; membuka jurus pemungkas senjata (*Weapon Arts Overdrive*).
    - **B. Unbreakable Bastion**: Mengurangi seluruh damage musuh sebesar 20%; kebal terhadap efek *stagger* dari serangan biasa.

#### 5. Miner (Penambang)
- **Aktivitas Penghasil EXP**: Memecahkan batu di ladang/hutan, menambang bijih tembaga/besi/emas di gua, memecahkan geoda.
- **Fokus Skill Tree**:
  - *Level 1–4*: Pengurangan konsumsi stamina beliung; kekuatan pukulan beliung bertambah sehingga memecahkan batu lebih cepat.
  - *Level 5 (Pilihan Spesialisasi)*:
    - **A. Prospector**: Peluang menemukan Batubara (*Coal*) berlipat ganda dari setiap batu yang dihancurkan.
    - **B. Geologist**: Bebatuan di gua memiliki peluang menjatuhkan permata mulia (*Gems*) dan geoda misterius berpasangan (x2).
  - *Level 6–9*: Peluang 25% mendapatkan bijih ganda (*Double Ore Drop*); efisiensi peleburan di Furnace 25% lebih cepat.
  - *Level 10 (Master Perk)*:
    - **A. Spelunker Master**: Tangga turun di lantai dungeon muncul 50% lebih cepat; lift checkpoint terbuka otomatis di lantai kelipatan tertentu.
    - **B. Demolition Expert**: Radius ledakan bom penambang bertambah 50% tanpa melukai pemain sendiri.

#### 6. The Merchant (Pedagang Toko)
- **Aktivitas Penghasil EXP**: Melakukan transaksi jual-beli langsung di kasir toko desa (General Store, Pandai Besi, Combat Shop, Warung Makan).
- **Fokus Skill Tree**:
  - *Level 1–4*: Diskon belanja bibit dan perkakas di toko (5% s/d 15%); nilai jual barang langsung ke toko bertambah +5%.
  - *Level 5 (Pilihan Spesialisasi)*:
    - **A. Wholesale Trader**: Membeli bibit dalam jumlah besar (kelipatan 10) memberikan diskon ekstra 20%.
    - **B. Silver Tongue**: Harga jual barang langsung ke pemilik toko bertambah 15%; membuka opsi dialog barter khusus.
  - *Level 6–9*: Toko desa menyediakan stok bibit langka dari musim lain dalam jumlah terbatas; biaya upgrade ransel dan fasilitas diskon 20%.
  - *Level 10 (Master Perk)*:
    - **A. Guild Magnate**: Membuka akses ke Pedagang Gelap / Pedagang Keliling Eksklusif yang menjual artefak dan bibit misterius setiap akhir pekan.
    - **B. Capitalist Investor**: Membuka katalog item impor modern dari kota sebelum Modern City terbuka penuh.

#### 7. The Economist (Ahli Ekonomi Makro & Logistik)
- **Aktivitas Penghasil EXP**: Mengisi kotak Shipping Bin dalam volume besar, mendanai proyek restorasi Balai Nadi, mengelola saldo tabungan kas bersama di co-op, pembukuan keuntungan harian.
- **Fokus Skill Tree**:
  - *Level 1–4*: Bonus pendapatan bersih dari Shipping Bin (+5% s/d +15%); pengurangan denda medis saat pingsan (-25% s/d -50%).
  - *Level 5 (Pilihan Spesialisasi)*:
    - **A. Village Treasurer**: Pengurangan kebutuhan bahan material pada seluruh proyek restorasi Balai Nadi sebesar 15%.
    - **B. Smart Investor**: Saldo kas bersama di co-op menghasilkan bunga simpanan harian sebesar 2% (maksimum cap harian seimbang).
  - *Level 6–9*: Kurir logistik Shipping Bin menjemput barang 2x sehari; denda pingsan sepenuhnya dihapus jika pingsan di dalam batas area ladang.
  - *Level 10 (Master Perk)*:
    - **A. Commodity Tycoon**: Membuka papan bursa kontrak komoditas harian (misal: "Permintaan 50 Jagung dengan pembayaran 3x lipat harga pasar").
    - **B. Shared Prosperity**: Memberikan aura buff pasif di sesi co-op: seluruh pemain dalam tim mendapatkan +10% efisiensi stamina dan +10% bonus pendapatan dari seluruh aktivitas.

---

### 13.3 Antarmuka & Manajemen Skill di Co-op
- **Tab Keahlian (Skills Tab)**: Terintegrasi pada menu ransel (`I` / Gamepad `B` atau `Start`), menampilkan 7 panel role dengan progres bar EXP, level aktif, dan bagan Skill Tree.
- **Notifikasi Level Up**: Layar rekap tidur malam menampilkan animasi "Level Up!" lengkap dengan perolehan stat baru dan pilihan pemilihan perk spesialisasi.
- **Sinergi Tim Co-op**: Di menu Co-op, buku status menampilkan ringkasan profil keahlian pemain lain sehingga anggota keluarga dapat saling berkoordinasi untuk membagi tugas secara optimal setiap pagi.

### 13.4 Implementasi Role & EXP [terpasang 2026-10-19]

**Tindak lanjut 22 Oktober 2026:** Kurir Logistik (Economist Lv6) kini membayar Shipping Bin pada 12.00/17.00 dengan slot harian tersimpan, tidak membayar ulang setelah reload atau settlement pagi. Forest Whisperer menanam ulang jenis pohon yang ditebang sebagai bibit tersimpan; muncul pada sinkronisasi spawner berikutnya (hari berikutnya/kunjungan ulang) dan tetap tumbuh 2× lebih cepat. EXP role yang tidak dikenal ditolak, EXP sangat besar dibatasi sebelum konversi integer.

Regresi mencakup ketujuh role pada ambang Lv1–10, level aktif sesudah tidur, cabang A/B yang tersedia/ditunda, pilihan permanen, stat dan serialisasi, isolasi progres co-op, efek bersama memakai nilai maksimum pemain aktif, rod pribadi tanpa mengubah Resource bersama, damage kapak/growth/replant, serta transaksi kurir/save/reload. Pengujian ini tidak menggantikan playtest semua efek probabilistik dan semua kombinasi combat.

**10 perk Resource masih ditunda karena memerlukan sistem/konten baru:** Farmer—Bintang Perak, Bintang Emas, Perpetual Orchard; Forager—Botanist, Kompas Alam; Miner—Demolition Expert; Merchant—Stok Langka, Guild Magnate, Capitalist Investor; Economist—Commodity Tycoon. Sistem kualitas crop/forage, orchard permanen, peta penanda, bom, katalog/pedagang eksklusif dan kontrak komoditas belum diselesaikan dalam cakupan ini. Ide Overdrive dan lift otomatis di rancangan juga belum terpasang. Label “Segera hadir” tidak dihapus untuk fitur yang belum mempunyai efek.


Keputusan pemilik proyek (2026-10-19, semua opsi "a"): (1) hanya perk yang sistemnya sudah ada yang dipasang, sisanya tampil "Segera hadir" di pohon; (2) kurva EXP di bawah; (3) pilihan cabang A/B Lv5/Lv10 di layar rekap tidur dengan animasi "Level Up!"; (4) tiap pemain co-op punya EXP dan level sendiri, EXP masuk ke pemain yang beraksi; (5) buku riset (Perpustakaan) dan Token Talenta (Balai Nadi) dipasang sekarang, token festival dan Santap Malam Bersama menyusul.

- **Kode dan data** [terpasang]: `scripts/system/skill_system.gd` (aturan + efek perk), `player_skills.gd` (progres per pemain di `PlayerData.skills`), `skill_manager.gd` (anak GameState, naik level saat tidur), `scripts/ui/inventory_skills.gd` (tab Keahlian), `scripts/ui/level_up_ui.gd` (rekap). Data: `resources/skills/skill_rules.tres` (semua angka EXP), `resources/skills/roles/<role>.tres` (7 `RoleData` berisi `RolePerk` per level, efek berupa kunci stat). Tes: `tests/role_exp_regression.tscn`.
- **Kurva EXP** [keputusan]: total EXP Lv1..Lv10 = 100, 380, 770, 1300, 2150, 3300, 4800, 6900, 10000, 15000.
- **Naik level** [terpasang]: EXP masuk langsung; saat ambang tercapai muncul notifikasi "siap naik ke Lv N, tidur untuk membuka keahlian". Level aktif saat hari berganti (tidur atau pingsan), lalu layar rekap muncul setelah laporan Shipping Bin ditutup. Cabang A/B yang dilewati ("Nanti saja") tetap bisa dipilih di tab Keahlian; pilihan permanen. Cabang yang seluruh perknya "Segera hadir" tidak bisa dipilih.
- **Sumber EXP** [terpasang; balancing 22 Oktober, angka pada `SkillRules`]: Farmer cangkul 1/petak, siram baru 1/petak, tanam 3/bibit, panen 15% nilai total hasil dasar per petak (4–40; bonus panen ganda tidak menggandakan EXP). Menyiram ulang tanah basah tetap memakai air/stamina, tetapi tidak memberi EXP tambahan. Forager forage 7, pohon 8, rumput 1, titik gali 5. Fisher per rarity 8/12/20/35/65. Combat pukulan 1, parry 4, bunuh musuh 35% HP maks (3–65), boss 200. Miner batu/bijih 20% nilai hasil (3–35), geoda 6. Merchant 1 EXP/10 G transaksi, maksimal 100 per transaksi. Economist 1 EXP/15 G kiriman dan sumbangan. Kurva level dan progres EXP yang sudah tersimpan tidak diubah; sumber EXP baru berlaku untuk aktivitas berikutnya.
- **Jalur hybrid** [terpasang]: 7 buku riset (`skill_book_<role>`, 1500 G, +250 EXP role, [usulan]) dijual di meja Perpustakaan kota (`resources/shop/library_books.tres`); dibaca dengan memakai buku dari hotbar. Menyelesaikan paket Balai Nadi memberi penyumbang terakhir 1 Token Talenta; token ditukar di tab Keahlian dengan EXP tepat sampai level berikutnya (aktif setelah tidur).
- **Co-op** [terpasang]: progres per pemain (P1 di blok `player`, karakter co-op di `coop_players`). Efek dunia bersama memakai nilai tertinggi di antara pemain sesi ini: tanah tetap basah, Agronomist, Green Thumb, Forest Whisperer, Spelunker, Village Treasurer, Smart Investor, Shared Prosperity. Tab Keahlian menampilkan role tertinggi rekan; tab Status menampilkan level ketujuh role.
- **Penyesuaian terhadap 13.2** [usulan]: Duelist riposte +50% (riposte dasar sudah 3x, jadi 4,5x); Lumberjack 2x damage kapak ke pohon (kayu keras menyusul); Agronomist = peluang 15% tiap malam tanaman tumbuh 1 hari ekstra; Berserker damage +30% saat HP < 40%; Soulforged memulihkan 10 HP dan 10 stamina tempur per musuh tumbang; Smart Investor 2% uang bersama per pagi, maks 500 G; Shared Prosperity berlaku untuk stamina harian dan Shipping Bin saat lebih dari 1 pemain; Ancient Tracker = bobot barang gali langka (bobot < 1) x4; Merchant/Economist Lv9 belum punya perk.
- **Segera hadir** (10 perk Resource tampil abu-abu): Farmer Bintang Perak/Emas, Perpetual Orchard; Forager Botanist, Kompas Alam; Miner Demolition Expert; Merchant Stok Langka, Guild Magnate, Capitalist Investor; Economist Commodity Tycoon. Overdrive, lift otomatis dan barter masih ide desain; tidak semuanya memiliki node perk tersendiri.
- **Save v22** [terpasang]: dict `skills` = `{"points": {role: EXP}, "levels": {role: level aktif}, "choices": {"role:5": "a"/"b"}, "tokens": int}`. Save lama tanpa key ini = semua role Lv0; nilai rusak diabaikan.

---

## 14. Sistem Lapak Dagang & Pekan Bazaar Interaktif (Inspirasi Grand Bazaar) [keputusan]

### 14.1 Konsep & Jadwal Bazaar
- **Gameplay Dagang Real-Time**: Terinspirasi langsung dari mekanisme *Story of Seasons: Grand Bazaar*. Fitur ini **bukan cutscene pasif**, melainkan simulasi perdagangan langsung di mana pemain berdiri aktif di balik lapak, menarik perhatian pembeli, dan mengelola transaksi secara interaktif.
- **Dua Format Berdagang**:
  1. **Pekan Grand Bazaar Nusa Vale (Weekly Market Day)**:
     - Diselenggarakan setiap akhir pekan (misal: setiap hari Minggu pukul 09:00–18:00) di Alun-Alun Kota (Town Square).
     - Menjadi pusat keramaian terbesar desa di mana seluruh warga, turis luar desa, dan pedagang keliling berkumpul.
  2. **Kios Ladang Harian (Farmstand Kiosk)**:
     - Pemain dapat memasang stan dagang kecil di depan gerbang ladang untuk menjual produk harian secara langsung ke NPC tetangga yang sedang jalan-jalan santai.

---

### 14.2 Mekanisme Etalase & Display Produk
- **Penataan Meja Etalase (Stall Counters)**:
  - Pemain menata produk dagangan secara bebas di slot etalase (dimulai dari 3 slot, dapat di-upgrade menjadi 6, 9, hingga 12 slot).
  - Tipe barang yang bisa dijual: hasil panen segar, ikan tangkapan, makanan olahan dapur, batangan logam, permata hasil tambang, obat-obatan, dan kerajinan tangan.
- **Kualitas Barang & Margin Harga**:
  - Barang dengan kualitas Bintang Perak/Emas memiliki daya pikat visual yang lebih kuat.
  - Pemain dapat menetapkan harga jual: harga standar pasar (100%), harga diskon obral (80% untuk cuci gudang cepat), atau harga premium (120%–150% untuk barang langka dan hasil olahan berkualitas tinggi).

---

### 14.3 Memanggil Pembeli & Mekanik Lonceng (Bazaar Bell / Call-Out)
- **Arus Pengunjung & Tingkat Minat (Interest Gauge)**:
  - NPC warga dan pengunjung berjalan melintasi koridor pasar dengan status kesadaran dan minat tertentu.
  - Setiap NPC memiliki preferensi produk (misal: Ibu Desa menyukai sayuran segar, Kakek menyukai ikan langka, Pengrajin mencari logam dan kayu).
- **Aksi Membunyikan Lonceng (Bazaar Bell)**:
  - Pemain berdiri di stan dan menekan tombol interaksi panggil (Spasi / Gamepad `A`) untuk membunyikan **Lonceng Lapak (*Bazaar Bell*)** atau berseru menawarkan dagangan (*"Ayo mampir! Sayur dan ikan segar baru dipanen hari ini!"*).
  - Gelombang dentingan lonceng memancar dalam radius suara berlingkar:
    - NPC yang terkena radius lonceng akan memunculkan ikon tanda seru (!), berbelok arah, dan mendekat ke lapak pemain.
    - Timing membunyikan lonceng yang tepat (tidak terlalu jarang dan tidak spam berlebihan) menjaga kerumunan tetap ramai di depan lapak tanpa membuat pembeli merasa terganggu.

---

### 14.4 Interaksi Penawaran, Tawar-Menawar, & Transaksi Kasir
- **Minat Pembeli & Balon Pikiran**:
  - Pembeli yang mendekat akan mengamati etalase dan memunculkan balon pikiran (misal: mencari tomat, tertarik dengan ikan lele, atau mengeluhkan harga).
- **Mekanisme Kasir & Tawar-Menawar (Haggling Mini-System)**:
  - Ketika pembeli berdiri di depan meja kasir dan berniat membeli, pemain berinteraksi langsung:
    1. **Transaksi Cepat (Quick Sell)**: Pembeli setuju dengan harga etalase, pemain menekan tombol kasir, barang berpindah, dan koin langsung masuk.
    2. **Tawar-Menawar (Haggling)**: Beberapa pembeli akan menawar harga barang (*"Bolehkah saya beli 2 labu ini dengan harga 150 G?"*). Pemain dapat memilih:
       - *Setuju*: Menjual dengan harga tawar pembeli (meningkatkan kepuasan pembeli dan reputasi lapak).
       - *Bujuk Rayu (Charm Bargain)*: Menggunakan keahlian role *The Merchant* untuk meyakinkan pembeli bahwa barang tersebut sangat segar dan bernilai tinggi.
       - *Tolak Santai*: Menolak tawaran tanpa menyinggung pembeli.
    3. **Rekomendasi Silang (Cross-Selling)**: Pemain menawarkan produk pendamping (misal: pembeli membeli gandum, pemain merekomendasikan mentega/telur untuk bonus penjualan ekstra).
- **Efek Transaksi Sukses**:
  - Dentingan mesin kasir yang renyah, semburan animasi koin beterbangan ke dompet, ekspresi gembira pembeli (ikon senyum hati), serta EXP instan untuk role *The Merchant* dan *The Economist*.

---

### 14.5 Sinergi Gotong Royong Co-op di Lapak
Mode Co-op split-screen membuat sesi Pekan Bazaar sangat hidup dan seru melalui pembagian tugas:
- **Pemain 1 (The Barker / Lonceng Panggil)**: Berdiri di garis depan stan, membunyikan lonceng secara ritmis, dan memikat arus pengunjung dari lorong pasar utama.
- **Pemain 2 (The Cashier / Kasir Utama)**: Berdiri di meja kasir, melayani pembayaran secepat mungkin agar antrean tidak terlalu panjang (jika antrean terlalu lama, pembeli bisa jengkel dan pergi).
- **Pemain 3 & 4 (The Restocker / Logistik Gudang)**: Memantau slot etalase yang mulai kosong dan berlari ke peti gudang atau ladang untuk mengisi kembali tumpukan produk baru sebelum bazaar usai.

---

### 14.6 Progresi & Tingkat Lapak (Stall Upgrades)
Pemain dapat meng-upgrade stan dagangnya di bengkel pertukangan desa:
- **Level 1 — Meja Kayu Sederhana**: 3 slot etalase, lonceng tangan kecil, jangkauan panggil pendek.
- **Level 2 — Kios Tenda Berkanopi**: 6 slot etalase, kanopi warna-warni, lonceng kuningan dengan radius panggil sedang, pembeli lebih sabar mengantre.
- **Level 3 — Stan Toko Berornamen**: 9 slot etalase, spanduk promosi magnet pengunjung, lonceng bergaung luas, fasilitas pendingin etalase (ikan dan makanan tidak cepat basi).
- **Level 4 — Paviliun Grand Bazaar Megah**: 12 slot etalase, dekorasi mewah, lonceng emas keraton bergaung ke seluruh sudut alun-alun, menarik turis VIP dan pengusaha kaya dari Kota Modern (*Modern City*).
- **Papan Target Omzet (Bazaar Goals)**: Setiap akhir pekan, Balai Nadi mengumumkan target total penjualan pasar desa. Menembus rekor omzet membuka penghargaan khusus desa, peringkat reputasi Nusa Vale naik kelas, dan membuka katalog bibit langka baru.

---

## 15. Sistem Festival & Minigame Interaktif Semi-Chaos [keputusan]

### 15.1 Filosofi Desain: Interaktif Penuh & Energi Party Semi-Chaos
- **Bukan Sekadar Cutscene**: Terinspirasi dari keseruan festival klasik (*Harvest Moon: Back to Nature*, *Coral Island*) yang dipadukan dengan dinamika kompetitif penuh tawa ala *Super Mario Party Jamboree*, *Party Animals*, dan *LEGO Party*. Seluruh festival mengharuskan pemain **menekan tombol secara aktif (*skill, timing, button mashing*)**, bukan sekadar menonton cutscene atau dialog otomatis.
- **Sensasi "Semi-Chaos" & Party Physics**:
  - Terdapat unsur fisika kocak: dorong-dorongan (*nudging/bumping*), karakter tersandung (*stumble/tumble*), terpeleset kulit pisang, proyektil tomat/salju beterbangan, dan rintangan dinamis yang memicu tawa saat bermain bersama teman dan keluarga di mode split-screen co-op.
  - Pemain dapat bersaing langsung (PvP party 2–4 pemain) atau bekerja sama mengalahkan NPC desa untuk menyapu bersih podium juara.

---

### 15.2 Kalender Festival Musiman & Mekanisme Minigame

#### A. Musim Semi (Spring)
1. **Festival Balap Lari Desa (Village Sprint Derby)**:
   - *Lokasi*: Lintasan jalan setapak melingkar dari alun-alun kota menuju pinggiran hutan.
   - *Mekanisme Gameplay*:
     - Tombol lari ditekan berirama (*rhythmic tapping*) untuk memacu kecepatan, diimbangi dengan mengelola bilah stamina lari (*Sprint Meter*).
     - *Elemen Semi-Chaos*: Lintasan dipenuhi rintangan dinamis—kubangan lumpur yang memperlambat, kulit pisang licin yang membuat terpeleset bergulingan, dan kawanan ayam yang tiba-tiba menyeberang. Pemain dapat saling menyenggol (*body check*) lawan ke arah kubangan lumpur untuk merebut posisi terdepan!
2. **Festival Balap Karung (Sack Race Stumblefest)**:
   - *Lokasi*: Lapangan rumput ladang festival.
   - *Mekanisme Gameplay*:
     - Menggunakan sistem **Rhythm Jump Timing**: menekan tombol lompat tepat saat lingkaran ritme bertepatan dengan garis ketukan.
     - *Ketukan Sempurna (Perfect)*: Karakter meluncur melompat jauh ke depan dengan suara pegas gembira.
     - *Ketukan Meleset*: Karakter kehilangan keseimbangan, melompat miring, dan tersandung lucu ke tanah (*ragdoll stumble*), harus menekan tombol bangun cepat (*mash to recover*).

#### B. Musim Panas (Summer)
3. **Festival Renang Bahari (Ocean Swimming Gala)**:
   - *Lokasi*: Pesisir Pantai Nusa Vale (*Beach*).
   - *Mekanisme Gameplay*:
     - Menekan tombol kayuhan tangan secara bergantian (Kiri / Kanan atau `A` / `D`) dengan ritme kayuhan stabil.
     - Mengatur **Bilah Napas (Breath Meter)**: Pemain harus menyelam menembus deburan ombak besar pemecah kecepatan. Jika tidak menyelam saat ombak datang, pemain akan terdorong mundur oleh gelombang. Terdapat gelembung arus air di lintasan yang memberikan dorongan turbo (*speed boost*).
4. **Festival Perang Tomat (Tomato Splatfest Brawl)**:
   - *Lokasi*: Arena alun-alun kota yang dibatasi benteng bal jerami.
   - *Mekanisme Gameplay*:
     - Pemain dan warga desa terbagi dalam 2 tim (atau Free-for-All 4 pemain).
     - Berlari mengambil persediaan tomat matang dari keranjang, membidik dengan mouse/analog stik, lalu melempar (*Throw*).
     - *Elemen Semi-Chaos*: Tomat yang mengenai lawan meledak dengan suara *SPLAT!*, meninggalkan noda merah di pakaian, dan memicu efek knockback terpental ke belakang. Pemain dapat bersembunyi di balik tong kayu atau melakukan lemparan pantul. Tim dengan skor eliminasi terbanyak dinyatakan menang.

#### C. Musim Gugur (Fall)
5. **Derby Balap Kuda (Autumn Horse Racing Cup)**:
   - *Lokasi*: Lintasan pacuan kuda melingkar di perbukitan desa.
   - *Mekanisme Gameplay*:
     - Pemain menunggangi kuda peliharaan sendiri (kecepatan awal dan stamina dasar dipengaruhi tingkat kasih sayang peternakan).
     - Memacu laju kuda dengan cambukan ritmik (*Whip Boost*). Jika mencambuk terlalu sering saat kuda lelah, kuda akan meringkik panik dan berhenti sesaat.
     - Mengendalikan kemudi di tikungan tajam dan menekan tombol lompat tepat waktu saat melewati rintangan pagar kayu balap.
6. **Adu Ayam Sumo (Rooster Sumo / Chicken Cluck Brawl)**:
   - *Lokasi*: Panggung ring jerami bundar di tengah festival panen (terinspirasi dari HM: Back to Nature).
   - *Mekanisme Gameplay*:
     - Dua ayam jago petarung lucu saling berhadapan di atas ring jerami.
     - Pemain berdiri di pinggir ring dan menekan tombol sorak pemandu berirama: *"KUKURUYUK!"* / *"SORAK!"*.
     - Ketukan sorak yang bertenaga membuat ayam pemain membusungkan dada, berkokok gagah, dan mengepakkan sayap, memicu gelombang angin (*Cluck Gust*) yang mendorong ayam musuh mundur selangkah demi selangkah.
     - *Elemen Semi-Chaos*: Terkadang ayam salah tingkah karena demam panggung—tiba-tiba bertelur di tengah ring, mematuk cacing di celah jerami, atau berbalik mengejar wasit pertandingan, memicu gelak tawa penonton!
7. **Lomba Ketangkasan Hewan Peliharaan (Pet Agility Race)**:
   - *Lokasi*: Lintasan rintangan taman desa.
   - *Mekanisme Gameplay*:
     - Melombakan hewan peliharaan (anjing, kucing, atau kapibara).
     - Pemain berlari berdampingan di luar lintasan sambil membunyikan peluit ritmis dan melemparkan camilan (*treats*) untuk memandu pet melewati jembatan titian goyang, terowongan pipa sempit, slalom tiang bendera, dan lompatan lingkaran cincin.

#### D. Musim Dingin (Winter)
8. **Perang Benteng Salju (Snowball Fortress Brawl)**:
   - *Lokasi*: Lapangan tertutup salju tebal di depan Balai Nadi.
   - *Mekanisme Gameplay*:
     - Pemain memadatkan salju menjadi bola salju, atau menggelindingkannya menjadi bola salju raksasa.
     - Melemparkan bola salju dengan efek knockback beku, menghancurkan benteng es tim lawan, dan merebut bendera festival lawan di tengah badai salju riang.
9. **Lomba Mancing Es Cepat (Ice Fishing Derby)**:
   - *Lokasi*: Danau ladang yang permukaannya membeku dan dilubangi khusus untuk kompetisi.
   - *Mekanisme Gameplay*:
     - Batas waktu ketat 3 menit. Memancing ikan es sebanyak dan seberat mungkin dengan mini-game pancing berkecepatan tinggi.

---

### 15.3 Hari Raya & Perayaan Khusus (Festive Holidays) [keputusan]
Selain kompetisi mini-game musiman, Nusa Vale merayakan hari besar keagamaan dan pergantian tahun dengan perpaduan tradisi budaya Nusantara dan kehangatan komunitas:

#### 1. Hari Raya Idul Fitri (Pesta Lebaran Desa Nusa Vale)
- *Jadwal & Atmosfer*: Diselenggarakan setiap tahun sekali (misal: pertengahan musim Semi/Gugur). Alun-alun desa dihias gerbang janur kuning, lampu colok obor bambu yang temaram hangat, serta lantunan suara bedug yang semarak. Seluruh warga mengenakan pakaian adat rapi dan suasana desa dipenuhi kedamaian dan kehangatan.
- *Mekanisme Gameplay & Minigame Interaktif*:
  1. **Pawai & Tabuh Bedug Ritmik (*Bedug Rhythm Minigame*)**:
     - Pemain bersama warga menabuh bedug raksasa di tengah alun-alun mengikuti ketukan tempo ritme tabuhan takbiran/perayaan.
     - Timing ketukan yang sinkron dan berenergi meningkatkan bilah semarak pesta (*Festive Joy Meter*), memicu sorak gembira warga dan letusan kembang kelapa kertas warna-warni.
  2. **Tradisi Silaturahmi & Anjangsana (Halal bi Halal)**:
     - Pemain berkeliling mengunjungi rumah-rumah warga desa untuk saling bermaaf-maafan.
     - Setiap rumah menyuguhkan hidangan khas Lebaran (Opor Ayam, Rendang Daging, Ketupat Janur, serta toples Nastar & Kastengel).
     - Mencicipi hidangan ini memulihkan 100% Stamina & HP serta memberikan buff berkah harian (*Blessing of Harmony*: regenerasi stamina lebih cepat dan keberuntungan panen bertambah).
  3. **Bagi-Bagi THR (Amplop Berkah Persahabatan)**:
     - Anak-anak kecil desa berlarian riang di jalanan. Pemain dapat berinteraksi membagikan kue toples atau amplop uang saku THR kecil (misal: 100 G per anak).
     - Tindakan ini meningkatkan poin relasi persahabatan desa (*Friendship Hearts*) dengan para orang tua dan anak secara instan dan drastis!
  4. **Lomba Anyam Ketupat Cepat (*Ketupat Weaving Challenge*)**:
     - Mini-game *button-combo* cepat adu ketangkasan menganyam daun kelapa muda menjadi bungkus ketupat bersama ibu-ibu desa untuk memperebutkan hadiah bumbu rempah langka.

#### 2. Hari Natal / Pesta Bintang Musim Dingin (Christmas / Winter Star Festival)
- *Jadwal & Atmosfer*: Tanggal 25 Musim Dingin. Pohon cemara raksasa di alun-alun kota berhiaskan lampu kristal es yang berkilau di bawah rintik salju putih, diiringi lagu lonceng musim dingin.
- *Mekanisme Gameplay & Minigame Interaktif*:
  1. **Tradisi Tukar Kado Rahasia (*Secret Santa*)**:
     - Seminggu sebelum festival, pemain menerima surat undian rahasia berisi nama warga yang menjadi target kado pemain.
     - Pemain membungkus kado favorit warga tersebut di meja kado. Pada malam perayaan, pemain menyerahkan kado dan menerima bingkisan kejutan balasan yang berisi bibit langka atau artefak kuno dari warga misterius desa.
  2. **Memburu Kado Salju (*Snow Gift Hunt Minigame*)**:
     - Mini-game seru di mana pemain dan warga desa berlari menembus tumpukan salju mencari kotak kado warna-warni yang terkubur sebelum waktu 2 menit habis.

#### 3. Malam Tahun Baru (New Year's Eve / Countdown Gala)
- *Jadwal & Atmosfer*: Tanggal 28 Musim Dingin pukul 20:00–00:00 (malam puncak penutupan tahun game).
- *Mekanisme Gameplay & Minigame Interaktif*:
  1. **Pesta Hitung Mundur (Midnight Countdown)**: Seluruh warga desa dan pemain berkumpul di puncak bukit desa atau dermaga pantai menghadap cakrawala malam.
  2. **Pertunjukan Kembang Api Interaktif (*Fireworks Rhythm Show*)**:
     - Pemain menyalakan kembang api spektakuler ke angkasa menggunakan tombol ritmik berurutan.
     - Ketukan akurat memicu ledakan kembang api raksasa aneka bentuk (bintang emas, siluet padi, dan bunga mekar) yang menerangi seluruh desa Nusa Vale.
  3. **Layar Kilas Balik Tahunan (*Annual Co-op & Farm Recap*)**:
     - Pergantian tahun menampilkan montase statistik tahunan yang membanggakan: total omzet G yang diraup, jumlah tanaman yang dipanen, ikan terbesar yang ditangkap, lantai terdalam gua yang ditaklukkan, serta foto kenangan potret bersama seluruh anggota co-op.

---

### 15.4 Sinergi Co-Op Split-Screen & Hadiah Festival
- **Mode Pesta Bersama (Party Multiplayer)**:
  - Di sesi co-op 2–4 pemain, seluruh pemain ikut bertanding di lintasan atau perayaan yang sama secara simultan di layar terbagi.
  - Pemain bisa bersaing sengit satu sama lain (PvP memperebutkan posisi 1) atau saling membantu menghalangi NPC unggulan desa.
- **Piala, Hadiah, & Prestasi Desa**:
  - *Juara 1*: Mendapatkan **Trofi Emas Bergengsi** (bisa dipajang di atas meja interior rumah), selempang juara festival, hadiah uang tunai besar (5.000–20.000 G), dan resep masakan eksklusif festival.
  - *Suntikan EXP Role*: Setiap keikutsertaan festival memberikan bonus EXP melimpah untuk role terkait (*Farmer, Fisher, Combat, Forager*).
  - *Reputasi Desa*: Kemenangan pemain meningkatkan popularitas desa Nusa Vale dan membuka kedatangan turis baru dari Kota Modern (*Modern City*).

---

## 16. Sistem Ekonomi Dinamis, Pajak, dan Penyerapan Uang (Dynamic Economy & Money Sinks) [keputusan]

### 16.1 Filosofi Desain: Keseimbangan Finansial dalam Nuansa Cozy
- **Cozy yet Economically Grounded**: Nusa Vale menggabungkan kenyamanan game bertani santai (*cozy farming*) dengan prinsip ekonomi yang masuk akal namun adil dan tidak membuat stres (*accessible, forgiving economic simulation*).
- **Kurva Finansial yang Seimbang**:
  - *Early Game*: Uang berharga dan langka. Setiap koin dihitung untuk membeli bibit awal, ransel, dan upgrade alat dasar.
  - *Mid Game*: Cash flow mulai stabil lewat hasil tani musiman, tangkapan ikan, dan pekan bazaar. Pemain mulai menghadapi biaya tagihan pemeliharaan ladang dan investasi proyek desa.
  - *Late Game*: Produksi barang melimpah tidak membuat pemain "kebingungan uang menganggur" (*post-scarcity boredom / hyper-inflation paralysis*), karena tersedia mekanisme penyerapan uang skala besar (**Money Sinks**) yang bernilai prestisius dan berdampak nyata bagi dunia game.

---

### 16.2 Mekanisme Pasar Dinamis: Hukum Penawaran & Permintaan (Supply & Demand)
Dunia ekonomi desa bereaksi secara dinamis terhadap volume penjualan pemain:
1. **Fluktuasi Harga Komoditas Berdasarkan Volume Penjualan**:
   - Setiap komoditas memiliki indeks kejenuhan pasar lokal (*Local Market Saturation Index*).
   - **Over-Supply (Pasokan Berlebih)**: Jika pemain menjual satu komoditas secara masif dan berulang (misal: panen monokultur 300 Stroberi berturut-turut, atau membabat habis 500 kayu ke pasar desa):
     - Pasar mengalami kejenuhan (*market saturation*).
     - Harga jual komoditas tersebut turun secara dinamis (-10% s/d -40% dari harga dasar) karena pasar desa kelebihan stok.
   - **Scarcity & High Demand (Kelangkaan & Permintaan Tinggi)**:
     - Komoditas yang jarang dijual atau sangat dibutuhkan desa (misal: rempah penghangat di musim dingin, ikan musiman langka, atau permintaan mendesak di Papan Balai Nadi) mengalami lonjakan harga beli (+20% s/d +50%).
   - **Pemulihan Pasar (Market Normalization)**:
     - Jika pemain menghentikan penjualan komoditas yang jenuh selama beberapa hari, stok pasar akan diserap oleh warga desa/kurir ekspor dan harganya kembali normal secara bertahap.
2. **Papan Buletin Tren Ekonomi Mingguan (Market Bulletin & Trends)**:
   - Ditempatkan di depan Balai Nadi dan Toko Kota.
   - Mengumumkan tren pasar: komoditas yang sedang *Booming* (harga naik), komoditas yang sedang *Surplus* (harga turun), dan ramalan tren pekan depan. Hal ini mendorong pemain untuk menerapkan **rotasi tanaman (*crop rotation*)** dan diversifikasi usaha, bukan hanya menanam satu bibit yang paling cepat panen.

---

### 16.3 Reaksi Ekologis Dunia Terhadap Perilaku Eksploitasi Sumber Daya (Living Ecological Reaction)
Pemain didorong untuk tidak bersikap impulsif atau mengeksploitasi alam secara serakah:
1. **Deforestasi Berlebihan (Over-Logging Reaction)**:
   - Jika pemain membabat habis seluruh pepohonan hutan dalam waktu singkat:
     - Pasokan kayu membanjiri pasar $\rightarrow$ harga jual kayu anjlok tajam.
     - Ekosistem hutan terganggu: hewan liar menjauh, kemunculan jamur dan tanaman forage langka menurun drastis selama beberapa pekan sampai pohon-pohon kembali rimbun.
2. **Monokultur vs Polikultur (Kelelahan Tanah / Soil Fatigue)**:
   - Menanam satu jenis tanaman yang sama terus-menerus di petak yang sama menyebabkan kelelahan unsur hara tanah (*soil fatigue*), memperlambat laju panen dan memperbesar risiko hama.
   - Melakukan rotasi tanaman (misal: menanam legum/kacang-kacangan penyubur tanah diselingi sayuran akar dan buah) mempertahankan kesuburan tanah dan menghasilkan kualitas panen Bintang Emas lebih tinggi.
3. **Over-Fishing (Penangkapan Ikan Berlebihan)**:
   - Menangkap terlalu banyak ikan di satu kolam/sungai dalam satu hari membuat sisa ikan menjadi lebih waspada (waktu gigitan pancing melambat), mendorong pemain berpindah spot pancing secara alami.

---

### 16.4 Pajak, Tagihan, dan Biaya Peluang (Taxes, Bills, & Opportunity Cost)
1. **Tagihan Utilitas & Iuran Pemeliharaan (Weekly Utility Bills)**:
   - Setiap akhir pekan (Sabtu malam), pemain menerima lembar tagihan transparan di kotak surat rumah:
     - *Iuran Pemeliharaan Ladang & Saluran Air*: Biaya proporsional dengan jumlah petak ladang aktif dan struktur bangunan yang terpasang (misal: 100–500 G per pekan).
     - *Iuran Fasilitas Komunitas*: Sumbangan kebersihan dan keamanan desa.
   - Membayar tagihan tepat waktu memberikan reputasi warga teladan (*Good Citizen Buff*).
2. **Pajak Progresif Kekayaan Desa (Wealth Contribution Bracket)**:
   - Hanya berlaku saat saldo pemain menembus ambang batas kemakmuran tinggi (misal: saldo kas di atas 100.000 G), dikenakan kontribusi pajak kas Balai Nadi sebesar persentase kecil (2–5%) yang langsung dialokasikan ke kas pembangunan fasilitas umum desa.
3. **Biaya Peluang (Opportunity Cost Simulation)**:
   - *Waktu & Energi Harian*: Memilih menghabiskan hari untuk menambang mineral di gua berarti melepas peluang merawat ladang secara manual atau membuka lapak di pekan bazaar.
   - *Komoditas Mentah vs Olahan*: Menjual hasil mentah memberi uang cepat, namun mengolahnya menjadi masakan di dapur, manisan di toples, atau batangan di furnace menghasilkan nilai tambah berkali lipat dengan biaya waktu proses.

---

### 16.5 Penyerapan Uang Skala Besar (Late-Game Money Sinks)
Mencegah fenomena pemain memiliki jutaan koin tanpa tujuan belanja (*avoiding post-scarcity boredom*):
1. **Sertifikat Hak Kelola & Perluasan Lahan (Land Deeds & Expansion)**:
   - Membeli hak kelola Pulau Nelayan Pribadi (50.000 G), Perkebunan Bukit Anggur (100.000 G), dan Lembah Kaca Hutan (250.000 G).
2. **Renovasi Hunian Megah & Dekorasi Kemewahan**:
   - Memperluas rumah menjadi Mansion bertingkat dengan ruang bawah tanah penyimpanan anggur, akuarium raksasa, dan perabotan berlapis emas/kristal (20.000–80.000 G per ruangan).
3. **Teknologi Otomatisasi Pertanian Canggih (High-Tech Farming & Maintenance)**:
   - Membeli mesin-mesin canggih dari Kota Modern (*Modern City*):
     - *Jaringan Sprinkler Otomatis Bertekanan*: Menyiram ladang secara otomatis tanpa tenaga manual (15.000 G per set).
     - *Drone Pemanen Cerdas*: Memungut hasil panen matang otomatis ke dalam gudang (50.000 G).
     - *Traktor Mini Desa*: Membajak ladang 3x3 dalam sekali jalan (75.000 G).
     - Seluruh mesin canggih memiliki biaya suku cadang dan pemeliharaan berkala (*Upkeep Cost*).
4. **Investasi Mega Proyek Komunitas & Infrastruktur Modern City**:
   - Menjadi investor utama proyek perbaikan stasiun kereta api cepat menuju Modern City (100.000 G).
   - Mendanai laboratorium riset Universitas desa (75.000 G) untuk membuka bibit mutasi hibrida lintas musim.
   - Membangun patung monumen emas pendiri desa Nusa Vale di tengah alun-alun kota (200.000 G).
5. **Lelang Barang Antik Akhir Musim (Seasonal Antique Auction)**:
   - Setiap akhir musim, Balai Nadi menyelenggarakan lelang lelang barang langka: artefak purba, lukisan maestro, bibit legendaris yang tidak dijual di toko mana pun, di mana pemain bertarung harga melawan pengusaha kaya luar kota.

---

## 17. Keputusan yang Telah Ditetapkan (Status Rekapitulasi)

Seluruh 18 poin keputusan yang sebelumnya terbuka kini telah berstatus **[keputusan resmi]**:

1. **Status Area**: Menggunakan `UnlockManager` sebagai *single source of truth* [terpasang].
2. **Furnace & Tool Upgrade Station**: Tersedia sebagai resep Crafting, serta penempaan upgrade alat resmi dipusatkan melalui interaksi langsung dengan NPC Pandai Besi (Empu Bima) di bengkel kota [terpasang].
3. **Sumber Bijih Emas ke Atas**: Berada di area Gunung dan lantai Gua tambang yang harus di-unlock terlebih dahulu.
4. **Bahasa & Display Name**: Menggunakan Bahasa Indonesia sebagai bahasa utama, dengan sistem arsitektur lokalisasi (Pengaturan opsi ID/EN).
5. **Musim Dingin**: Ladang luar ruangan memiliki varietas tanaman khusus musim dingin.
6. **Pohon Buah**: Pohon permanen bertahap yang menghasilkan buah musiman berulang kali tanpa perlu tanam ulang.
7. **Shipping Bin**: Uang dibayarkan saat tidur malam atau dijemput NPC kurir di sore hari (bukan langsung bayar instan).
8. **Denda Pingsan**: jalur batas waktu hanya menerapkan bangun 08:00/stamina 50%, tanpa potongan uang/item [terpasang]. Jalur HP habis: transisi Klinik, biaya 10% uang (maks 1.000 G), 2 tumpukan barang acak berkurang separuh, bangun di rumah [terpasang, Phase 4B-1].
9. **Ikan Musiman**: Menambahkan atribut daftar musim (`seasons`) pada `FishData`.
10. **Air Beku Musim Dingin**: Memancing luar ruangan diblokir saat musim dingin, kecuali di spot khusus yang di-unlock.
11. **Parameter Forage & Biaya Stamina 0**: Disetujui dan disahkan.
12. **Harga Batangan Logam**: Naik secara progresif per tier (Copper 40 G hingga Obsidian 1.500 G).
13. **Upgrade Alat**: Dilakukan via interaksi NPC Pandai Besi (Empu Bima) di kota [terpasang].
14. **Efek Tier Alat**: Diverifikasi dan valid sesuai spesifikasi di `TOOL_PROGRESSION.md`.
15. **Storytelling & Endgame**: Diadopsi premis restorasi desa keluarga dan ekspansi *endless game* menuju Kota Modern (*Modern City*).
16. **Lokasi Balai Nadi**: Terletak permanen di Kota dengan pintu masuk permanen; proyek restorasi desa selanjutnya menggunakan sistem yang sama.
17. **Toko Combat**: Terletak di area pintu masuk Gua tambang; menjual 80 item perlengkapan tempur dengan harga seimbang untuk *late-game*.
18. **Fitur Fase 4 (Combat/Soulslike, Boss AI, Cooking, Gathering, Cave, Kendaraan, Role/Skill Tree, Grand Bazaar, Festival Semi-Chaos, Dynamic Economy & Money Sinks)**: 
    - Untuk fase **MVP**: cakupan combat dasar (HP bar, melee/ranged/magic, knockback, 80 equipment, toko combat) disahkan cukup.
    - Untuk fase **Lanjutan**: roadmap resmi disahkan mengadopsi sistem pertarungan **2D Top-Down Soulslike** (stamina-driven, dodge roll i-frames, parry/riposte, poise/stagger, frame commitment) serta kecerdasan buatan musuh berbasis **Behavior Tree AI** dan pertarungan boss multi-fase yang dinamis.
    - **Sistem Role, EXP, dan Skill Tree**: Diadopsi 7 role utama (*Farmer, Forager, Fisher, Combat, Miner, The Merchant, The Economist*) dengan arsitektur **Opsi B (Per-Activity EXP dengan Sentuhan Hybrid)**: 90% EXP didapat dari aktivitas spesifik masing-masing peran, dipadukan 10% jalur fleksibel (Buku Riset Universitas, Token Talenta Balai Nadi/Festival, dan santap malam bersama di co-op).
    - **Sistem Lapak Dagang & Pekan Bazaar (Grand Bazaar)**: Diadopsi mekanisme lapak interaktif real-time, menata etalase, membunyikan lonceng penarik kerumunan, tawar-menawar langsung, dan sinergi penjaga lapak co-op.
    - **Sistem Festival & Hari Raya Budaya**: Diadopsi rangkaian festival musiman semi-chaos dan perayaan besar hari raya: **Hari Raya Idul Fitri (Pesta Lebaran Nusantara)**, Hari Natal (Winter Star Festival), dan Malam Tahun Baru (Fireworks Countdown Gala).
    - **Sistem Ekonomi Dinamis & Money Sinks**: Diadopsi hukum penawaran & permintaan (*supply & demand*), reaksi ekologis dunia terhadap eksploitasi berlebihan, tagihan mingguan, pajak kekayaan, biaya peluang, serta penyerapan uang skala besar (ekspansi pulau, mansion, mesin otomatis, mega proyek kota modern, lelang langka).

---

## 18. Keputusan Terbuka Lanjutan (Fase Berikutnya) [usulan]

Dengan disahkannya keputusan utama di atas, butir keputusan teknis turunan yang dapat disempurnakan pada sesi berikutnya:
1. **Nama & Jadwal NPC Kurir**: Menentukan nama karakter kurir logistik (misal: "Pak Pos Joko" atau "Budi") dan jam pasti penjemputan kotak Shipping Bin.
2. **Pilihan Tanaman Musim Dingin**: Menentukan daftar 3–4 varietas tanaman dingin awal beserta durasi panennya (misal: Snow Yam 6 hari, Winter Radish 4 hari, Snow Cabbage 8 hari).
3. **Layout Balai Nadi di Town**: akses sudah terpasang; penyempurnaan posisi bangunan berikutnya mengikuti layout kota, bukan blocker implementasi pintu.
4. **Behavior Tree Framework Godot**: Memilih implementasi Behavior Tree di GDScript (library plugin Beehave / LimboAI / custom node-based GDScript).
5. ~~**Format Penyimpanan EXP & Skill Tree di Save Game**~~: selesai di save v22, lihat 13.4.
6. **Layout Alun-Alun Pekan Bazaar**: Menentukan posisi deretan stan pemain dan rute jalan NPC pembeli di alun-alun kota pada scene `town.tscn`.
7. **Tanggal Pasti Kalender Hari Raya**: Menetapkan tanggal kalender (1–28) per musim untuk Hari Raya Idul Fitri, Natal (25 Dingin), dan Malam Tahun Baru (28 Dingin).
8. **Formula Numerik Fluktuasi Pasar**: Menentukan batas ambang kuantitas penjualan harian (misal: threshold > 50 item) sebelum harga pasar mengalami penurunan 10%.
9. **Kendaraan lanjutan**: harga sepeda/resep sapu, fungsi bak muatan Mobil Bak, dan syarat membuka `modern_city` (bagian 10).

---

## 19. Changelog

- **2026-10-26 (Versi 3.36)**: Audit balancing dan regresi ([AUDIT_2026-10-26.md](AUDIT_2026-10-26.md)). Madu dihapus dari stok General Store (loop beli madu → Keg → Mead); madu kini dari Beehive, dan Beehive pertama dari hadiah Dana Pasar. Fish Smoker tidak lagi menerima ikan asap. Pohon buah Greenhouse berbuah di luar musim (cek musim memakai area petak). Tes ekonomi/peternakan diperbaiki, tes arbitrase toko → mesin ditambahkan, lima tes fitur baru didaftarkan di runner. Status save v26 dikoreksi. Temuan nilai olahan, durasi mesin, pohon buah dan harga logam menunggu keputusan pemilik.
- **2026-10-25 (Versi 3.35)**: Balai Nadi dilengkapi (bagian 4.9.1): 18 paket baru sehingga 21 paket di Balai Utama + 4 sayap, paket "pilih N dari M" (`slots_required`), hadiah barang per paket, bonus permanen saat sayap lengkap (keputusan pemilik: Alam tumbuh ±10% lebih cepat, Karya upgrade alat -10%, Niaga jual +5%, Pengetahuan geoda ×1,25) + 2 Token Talenta, tahap "Jantung Desa". Tanpa perubahan save (tetap v26).

- **2026-10-25 (Versi 3.33)**: Peternakan lanjutan (bagian 4.10.9–4.10.11, keputusan pemilik: semua usulan): kerbau (susu tiap 2 hari, Keju Kerbau), kapibara (bonus kasih sayang sekandang), kuda tunggangan 1,6–1,8× (maks 1), pembiakan Barn 4 hati, Inkubator di Kandang Unggas, anak hewan, Bulu Bebek. Sprite placeholder recolor sapi. Save v26.

- **2026-10-25 (Versi 3.32)**: Kendaraan (bagian 10) terpasang: sepeda (toko desa), sapu terbang (Meja Alkimia, melayang di atas air), serta data skuter listrik dan mobil bak yang terkunci sampai Modern City. Kecepatan mengikuti keputusan pemilik: lari tanpa Shift ditambah sedikit (sepeda +10%, sapu +20%). Kendaraan diparkir otomatis saat masuk ruangan/gua. Tanpa perubahan save (tetap v25).

- **2026-10-22 (Versi 3.30)**: Baseline balancing progres/ekonomi: Tembaga/Besi/Emas 350/1.000/2.300 G; tas 1.500/7.500 G; rumah 3.500/12.000/30.000 G dengan bahan bertahap dan bonus stamina +30/+40 (target 200 bersama tiga Biji Daya); 136 harga masakan dihitung dari bahan dan dibatasi terhadap arbitrase, jual kembali 39 benih menjadi 40%; EXP aktivitas diselaraskan dan siram ulang tidak memberi EXP; damage musuh/boss mengikuti armor dan kelompok awal diperkecil. Tambah audit deterministik, simulasi kas solo/co-op, serta regresi harga/EXP/stamina/gua. Format save tetap v25; status playtest umum lulus tidak diubah.

- **2026-10-22 (Versi 3.29)**: Catat konfirmasi pemilik bahwa stabilitas/playtest loop inti solo/co-op sudah dilakukan dan lulus. Tutup milestone tersebut dalam rekomendasi prioritas, tetapkan balancing progres/ekonomi sebagai langkah berikutnya, dan tambahkan `PLAYTEST_STATUS.md` serta catatan `AGENTS.md` untuk mencegah pengulangan rekomendasi. Pengujian perubahan baru/regresi tetap berlaku.

- **2026-10-22 (Versi 3.28)**: HerbalHouse menuju interior yang tersedia dan transisi diuji solo/co-op; persahabatan maksimum dikunci permanen; rumah tangga/upacara dialog, pasangan/roommate, bantuan harian dan surat resep/bingkisan; Kurir Logistik dua pembayaran/hari, Forest Whisperer tanam ulang; tes progres/cabang/co-op/save ditambahkan ke runner. Save v25; dokumentasi membedakan cakupan selesai dan 10 perk yang masih memerlukan sistem baru.

- **2026-10-22 (Versi 3.27)**: Sinkronisasi hasil inspeksi workspace: matriks status dan tingkat bukti, save v24, Gunung/Gua/Hill/Deep Forest, 137 resep/22 alat cooking, 96 equipment berslot, Beehive/Sawmill/Alchemy/Anvil, Role/EXP, heart event/surat/romansa sebagian, serta musik/horor. Catat target pintu HerbalHouse yang hilang, selisih kunci 10 hati, batas verifikasi, dan backlog tanpa mengubah keputusan desain atau kode gameplay. Lihat audit 22 Oktober.

- **2026-10-19 (Versi 3.26)**: Role & EXP (bagian 13.4, keputusan pemilik proyek semua opsi "a"): 7 role Lv1-10 per pemain dengan EXP dari aksi, level aktif saat tidur, layar rekap "Level Up!" dengan pilihan cabang A/B di Lv5/Lv10, tab Keahlian di tas, perk yang sistemnya ada dipasang (sisanya "Segera hadir"), 7 buku riset di Perpustakaan, Token Talenta dari paket Balai Nadi. Save v22 menyimpan `skills` per pemain. Tes `tests/role_exp_regression.tscn`.

- **2026-10-19 (Versi 3.25)**: Co-op drop-in ala Stardew (bagian 4.14): gamepad yang belum dipakai menekan Start saat bermain untuk ikut tanpa ke main menu, memilih karakter co-op save ini atau membuat karakter baru di layar kustomisasi; tahan Start (atau P1 lewat menu pause) untuk keluar, sisa P1 kembali main sendiri di tempat. Tanpa kabin. Gamepad P1 tetap milik P1. Save v21: daftar karakter co-op dengan id.
- **2026-10-19 (Versi 3.24)**: Kontrol & Konteks Input (bagian 4.3): router input satu pintu, konteks per barang yang dipegang (Lapangan/Combat dekat/Combat jauh/Di udara/Menu/Dialog), lompat + lompat ganda + tebar benih seperti Grand Bazaar, lock-on, prompt tombol dinamis, petunjuk tombol HUD, dan atur ulang tombol di Pengaturan. Perubahan tombol dari versi sebelumnya: keyboard Q kini lock-on (tangkis pindah ke klik kanan saat memegang pedang); gamepad LT bukan lagi tangkis (kini LB), RT saat memegang senjata = serangan berat, B saat memegang senjata = roll/lari. Tanpa perubahan save.
- **2026-10-19 (Versi 3.23)**: Tint siang/sore/malam berlaku global (bagian 4.1 "Tint Waktu Global"). Semua scene dunia otomatis ikut, termasuk interior (50%), Gunung, dan Bukit; gua tetap tanpa tint. CanvasModulate milik scene kini jadi warna dasar yang dikalikan warna waktu (sebelumnya ditimpa). Node opsional `SceneLighting` untuk override per scene. Tanpa perubahan save.
- **2026-10-19 (Versi 3.22)**: Perbaikan flicker saat pindah scene di sore/malam: warna CanvasModulate dipasang begitu scene masuk tree (sebelumnya baru setelah transisi selesai karena game dijeda), efek layar horor langsung pada nilai sekarang tanpa fade-in, rasa takut terbawa antar scene, dan lampu dekorasi langsung menyala. DayCycle tidak lagi mencari CanvasModulate di seluruh scene tiap frame. Tanpa perubahan save.
- **2026-10-19 (Versi 3.21)**: Penunggu malam (4.1): Kuntilanak (melayang) dan Pocong (melompat) yang hanya bergerak saat tidak dilihat, berpindah ke belakang pemain bila ditatap terlalu lama, diusir cahaya, dan memicu jumpscare + energi berkurang saat menyentuh. Sprite, wajah jumpscare, dan suara baru. Tanpa perubahan save.
- **2026-10-19 (Versi 3.20)**: Horor Tengah Malam (4.1): meter Rasa Takut per pemain (naik di gelap, turun dekat cahaya), detak jantung + denyut merah + guncangan, shader 00.00–05.00 (warna pudar, grain, aberration, glitch), dan 8 kejadian ganjil berbasis data (siluet, bisikan, langkah kaki pengikut, lampu berkedip, mata merah, gagak). NightHorror kini scene node yang bisa diatur di editor. Tanpa perubahan save.
- **2026-10-18 (Versi 3.19)**: Crafting lanjutan bagian 2 (4.13): 15 dekorasi farm baru (sumur, air mancur, ayunan, jungkat-jungkit, papan petunjuk, tikar piknik, lampu kembar, jemuran, rumah anjing, dua penunjuk angin, lentera resin, pohon Natal, kotak pasir, sapu lidi), Ramuan Penyembuh Besar, Cincin dan Kalung Prisma. Bahan yang tadinya menganggur kini dipakai: resin, sirup maple, tulang tua, wol, pecahan prisma. Tanpa perubahan save.
- **2026-10-18 (Versi 3.18)**: Crafting lanjutan (bagian 4.13): 70 resep senjata/armor/panah Tembaga sampai Obsidian, Peti Fairy dan Peti Obsidian, 14 dekorasi farm, Sarang Lebah (madu + lilin lebah), Penggergajian (papan kayu), Meja Alkimia (4 ramuan), Landasan Tempa (10 cincin + 10 kalung), sarung tangan dan tabung panah, bahan Tali Sulur/Kulit Olahan/Umpan Buatan. Slot Kalung, Cincin, dan Aksesori di menu Equipment aktif; ATK perlengkapan ikut combat. Save v20. Tes `tests/crafting_expansion_regression.tscn`.
- **2026-10-18 (Versi 3.16)**: Performa scene farm (tanpa perubahan desain atau save). Spawner forage/rumput/pohon memakai cache ruang terpakai per frame, jadi masuk farm tidak lagi macet belasan detik. Kanopi pohon hanya disalin saat animasinya berubah, shader pemisah batang/kanopi dipakai bersama, dan mask poligon pinus dipanggang ke tekstur saat game jalan (poligon di editor tetap sumbernya). Probe: tests/farm_perf_probe.tscn; tes: forage_cache_regression, pine_bake_regression.
- **2026-10-18 (Versi 3.15)**: Umpan pancing kini dibuat lewat crafting (keputusan pemilik proyek): Umpan (cacing), Umpan Serangga (jangkrik + ulat), Umpan Kilau (kunang-kunang + ngengat sutra). Serangga dan cacing mentah tidak lagi dipakai otomatis sebagai umpan. Tanpa perubahan save.
- **2026-10-18 (Versi 3.14)**: Phase 4A-3 Gathering (bagian 7): jaring serangga Kayu (crafting) sampai Emas (Toko Umum, tukar jaring sebelumnya), 15 serangga per musim/waktu/area termasuk gua, serangga sebagai umpan pancing otomatis, Paket Serangga Balai Nadi dengan hadiah 3 Tapper, tapper (crafting) di pohon maple/pinus/birch/mahoni, biji pohon untuk menanam pohon di Ladang, dan forage musiman Kota/Gunung/Pantai. Save v18 menyimpan tapper.
- **2026-10-18 (Versi 3.12)**: Tangga naik dan pintu keluar gua menampilkan konfirmasi langsung saat disentuh (tanpa interaksi). Solo: game dijeda; co-op: hanya pemain yang menyentuh yang terkunci. Tanpa perubahan save.
- **2026-10-18 (Versi 3.11)**: Perbaikan pintu keluar dan tangga naik gua: klik kanan sekarang berfungsi walau memegang senjata (bila kursor di pintu/tangga dan pemain di dekatnya), dan dialog konfirmasi bisa dijawab langsung dengan gamepad A/B atau Enter/E/Esc. Tes `tests/cave_exit_input_regression.tscn`. Tanpa perubahan save.
- **2026-10-18 (Versi 3.10)**: Geoda (Geoda, Geoda Beku, Geoda Magma, Geoda Pelangi) jatuh dari batu gua sesuai tier dan dipecahkan di Pandai Besi. Item baru: Tanah Liat (dari batu biasa), mineral Kristal Bumi, Air Mata Beku, Kuarsa Api, dan Pecahan Prisma. Data geoda di `resources/cave/geodes/`. Tanpa perubahan save.
- **2026-10-18 (Versi 3.9)**: Gua Tambang: scene gua menjadi node yang bisa diedit (TileMapLayer, Lobby, FloorContent). Mulut gua dan lubang turun dimasuki otomatis; pintu keluar lobi dan tangga naik meminta konfirmasi. Lencana lantai dengan nama, ikon, dan warna per tier; ruangan diwarnai per tier; barang jatuh dibersihkan saat pindah lantai. Batu tambang dan permata dipisah menjadi file `resources/cave/ores/*.tres`; 9 permata baru (Kuarsa sampai Kristal Peri) tersebar per tier lantai; bijih memakai gambar batu besar berwarna. Tanpa perubahan save.
- **2026-10-18 (Versi 3.8, lanjutan)**: Scene Gunung (`mountain.tscn`) kini berupa node biasa yang bisa diedit di editor: TileMapLayer lantai/dinding (tileset `resources/world/mountain_rock_tileset.tres`), tabrakan batas, mulut gua, jalan ke Hill, papan nama, dan kolam air panas (tampil di editor). Perbaikan: mulut Gua Tambang di Gunung sekarang bisa dimasuki saat pemain berdiri menempel di depannya. Tanpa perubahan save.
- **2026-10-18 (Versi 3.8)**: Kontrol gamepad disamakan dengan Stardew Valley (4.3): B/Start = tas, Y = tab Crafting, A = interaksi, X = alat, LB/RB = slot (di tas: ganti tab). Lari dipindah dari B ke RT (tekan singkat sambil memegang senjata = roll), RT tidak lagi memakai alat. Teks rencana Tab Keahlian dan Lonceng Lapak disesuaikan (tas = B/Start, interaksi = A). Tanpa perubahan save.
- **2026-10-18 (Versi 3.7)**: Spot pancing musim dingin (pilihan pemilik proyek: keduanya): Kolam Air Panas di Gunung dan Danau Bawah Tanah di Gua lantai 10, keduanya tidak membeku, dengan tabel ikan sendiri. Tanpa perubahan save.
- **2026-10-18 (Versi 3.6)**: Fishing 4A-1 dituntaskan: musim ikan (`FishData.seasons`, kosong = sepanjang tahun) dan air beku di Musim Dingin (`FishingSpot.freezes_in_winter`). Perbaikan lokasi ikan mas. Data bijih per lantai di `cave_data.tres` dipulihkan setelah tertimpa editor. Tes `tests/fishing_season_regression.tscn`. Tanpa perubahan save.
- **2026-10-17 (Versi 2.9)**: Phase 4B-3. Kawasan Gunung di utara Hill dengan mulut Gua Tambang; lobi gua berisi Toko Combat, lift, dan lubang ke lantai 1; lantai 1-20 acak harian (batu, batubara, tembaga, pilar, slime/myconid); tangga turun dari batu acak atau setelah semua monster kalah; lift checkpoint tiap 5 lantai disimpan (save v15). Boss lantai 20 menyusul.
- **2026-10-17 (Versi 2.9.1)**: Perbaikan pickup. Saat memegang alat atau senjata, mengambil item tidak lagi memindah slot hotbar dan tidak memutar gesture ambil (input tidak terkunci saat combat). Gesture ambil item lainnya diputar 2x lebih cepat.
- **2026-10-17 (Versi 3.0)**: Combat Soulslike 8.2-A. Bar stamina tempur terpisah + Exhausted, dodge roll dengan i-frames dan kelas beban perlengkapan, block/parry/riposte, poise dan stagger untuk pemain dan musuh, frame data (startup terkunci, recovery bisa dibatalkan roll), serangan berat (tahan klik kiri), sprint/roll attack, dan Weapon Art per tier (tombol F). Tanpa perubahan save.
- **2026-10-18 (Versi 3.5)**: Upgrade Rumah di Wira (bagian 4.12): 3 tingkat data-driven (`HouseLevelData`), dibayar di depan dan selesai setelah 2-3 hari, tingkat 1 membuka ruang dapur yang sudah ada (renovasi dipindah dari toko Dapur Nusantara), tingkat 2-3 menambah stamina maksimum. Pintu Dapur di rumah dipasang dari kode. Save v17 menyimpan tingkat rumah dan pesanan; save lama dengan dapur terbeli menjadi tingkat 1. Catatan: carpenter aktif di kode adalah Wira (`data/npc/wira.json`, service carpenter), bukan Pak Damar.
- **2026-10-17 (Versi 3.4)**: Boss 8.2-C lantai 20 Raja Slime Emas (pilihan pemilik proyek): arena dengan pintu kabut, bar HP boss besar, 3 fase dengan aura, hantaman/Hujan Emas bertelegraf yang tak bisa ditahan (ikon bahaya), terjangan yang bisa di-parry, semburan, anak slime, anti-kiting, murka, genderang sintetis, hadiah pertama 2000 G + bijih. Save v16 menyimpan boss yang sudah kalah.
- **2026-10-17 (Versi 3.3)**: Efek status senjata tier tinggi (keputusan pemilik proyek): Crimson Terbakar, Frost Dingin, Shadow Serap Jiwa, Fairy Berkah Peri, Obsidian Api Gelap (terbakar + DEF musuh setengah). Kayu sampai Platinum tanpa efek status. Tanpa perubahan save.
- **2026-10-17 (Versi 3.2)**: Rasa senjata per tier dan bidikan jarak jauh. Tiap tier bahan (Kayu..Obsidian) punya warna, partikel, ekor, tebasan, dan lapisan suara sendiri yang meningkat bertahap. Bidik busur/tongkat kini punya garis bertitik, lingkar bidik, derit/dengung yang naik, tarikan penuh dengan denting akor, dan tembakan charged (hanya visual). Tanpa perubahan angka combat dan tanpa perubahan save.
- **2026-10-17 (Versi 3.1)**: AI musuh 8.2-B. Behavior Tree modular (Selector, Sequence, Parallel, Inverter, Repeater, Cooldown, Limit, Condition, Action), kerucut pandang dengan cahaya gua/malam dan garis pandang, pendengaran (lari, beliung, senjata beradu), status waspada (tenang, curiga, aggro, mengepung, mundur), token serang bergiliran, feint, dan mundur + panggil bantuan. Perbaikan data yang tertimpa editor: daftar bijih per band di cave_data.tres. Tanpa perubahan save.

- **2026-10-17 (Versi 2.8)**: Phase 4B-1 Combat. HP 100 per pemain (save v14), bar HP di HUD, rumus `max(1, ATK - DEF)`, serangan pedang/busur/tongkat dari hotbar (klik kiri serang, tahan klik kanan bidik), anak panah sebagai amunisi, i-frames 0,8 detik + knockback, musuh target dari aset enemy, kalah lewat transisi Klinik dengan denda uang/barang lalu bangun di rumah. Slot equipment weapon diganti senjata di hotbar. Perbaikan: senjata kini tergambar di animasi serang (layer Sword/Bow per tier, Healer Staff), slime menjatuhkan Slime Gel, suara pukulan slime memakai impactSoft. Pose bidik busur dan tongkat sihir saat klik kanan ditahan. Combo 3 pukulan untuk pedang, busur, dan tongkat sihir. Juice combat, efek bar HP/stamina, dan pingsan saat stamina 0. Perbaikan posisi bar HP/stamina (sejajar di kanan bawah) dan kaki melangkah saat membidik sambil berjalan. Phase 4B-2: AI musuh (patroli, kejar, ancang-ancang, terjang/ayun, tertegun, pulang).

- **2026-10-15 (Versi 2.7)**: audit dependensi dan cashflow progres awal; sumber bijih Forest yang pulih dan terhubung ke entrance; endapan besi kecil untuk jalur Tembaga → Besi; margin batu awal; informasi manfaat/sisa uang di UI upgrade; perbaikan callback pickup setelah HUD dibebaskan.

- **2026-10-15 (Versi 2.6)**: penyiraman menghabiskan stamina/air juga pada tanah basah; tanah kosong reset setiap pergantian hari; pembatas ukuran/tier pohon dan batu, variasi batu serta feedback kebutuhan alat; perbaikan regresi transisi Balai; panduan editor crafting dan animasi karakter.

- **2026-10-15 (Versi 2.5)**: audit status implementasi; koreksi viewport, stamina/Biji Daya, biaya Balai Nadi, versi save, dan pemisahan pingsan waktu dari target denda dungeon. Tambahkan matriks fitur aktual, batas implementasi dan laporan progres.

- **2026-10-13 (Versi 2.3)**:
    - Interior Barn/Coop memakai aset milik proyek, palung, sarang, papan pengelolaan, lorong tengah, dan kapasitas 4/8/12.
    - Pintu bangunan/ruangan menggunakan klik kanan; pembelian semua hewan dipindah ke layanan Toko Ternak Rian.
    - Mesin memakai VFX dan loop SFX spasial selama berjalan; placement berhasil menampilkan debu/sparkle. Audit durasi dan perbaikan persistensi dijelaskan dalam [PROCESSING_AUDIT.md](PROCESSING_AUDIT.md).

- **2026-10-13 (Versi 2.2)**:
  - Implementasi core loop peternakan untuk ayam/bebek dan sapi/kambing/domba, termasuk kualitas produk, kebersihan, kesehatan, merumput, jerami/silo, upgrade/auto-feeder, serta pengolahan mayones/keju/kain.
  - Menggunakan aset hewan dan bangunan milik pengguna; melengkapi ikon alat, rumput pakan, dan sprite Mesin Mayones. Menambahkan regresi data dan interaksi di ladang; panduan aktual ada di `LIVESTOCK_CORE_LOOP.md`.

- **2026-10-13 (Versi 2.1)**:
  - Menjabarkan core loop peternakan dari cek kebutuhan, pakan, perawatan, panen, alokasi hasil, hingga persiapan hari berikutnya.
  - Memisahkan fondasi ayam yang terpasang dari usulan merumput, kebersihan, kesehatan, kualitas produk, progresi, serta aturan co-op/save dan kriteria penerimaan (bagian 4.10.1–4.10.8).

- **2026-10-13 (Versi 2.0)**:
  - **Sistem NPC Dinamis, Jadwal Harian & Waypoint Pathing (Full NPC Ecosystem)** [terpasang]:
    - Framework terpadu `VillageNPC` (`scripts/world/village_npc.gd`) mendukung siklus jadwal waktu `DayCycle`, waypoint navigation, animasi 4-arah (Idle down/up/side dan Walk down/up/side), anti-stuck protection, serta kotak dialog berpotret (`NPCDialogUI`).
    - Penambahan warga desa baru dan standardisasi nama Indonesia:
      - **Ubay (`UbayNPC.tscn`)**: Pemuda ceria Nusa Vale yang gemar bersantai di alun-alun, nongkrong di taman air mancur, dan menikmati senja di jembatan.
      - **Rian (`RianNPC.tscn`)**: Peternak muda yang telaten merawat hewan ternak dan satwa padang rumput.
      - **Pak Bahar (`BaharNPC.tscn`)**: Nelayan sepuh di dermaga jembatan selatan yang menguasai seni memancing dan ramalan pasang surut.
      - **dr. Ratih (`RatihNPC.tscn`)**: Tabib klinik desa yang meracik obat herbal dari tanaman liar berkhasiat.
      - **Pak Joko (`ChefNPC.tscn`)**: Koki Warung Rasa Nusa yang ramah menyajikan kuliner hangat.
      - **Wira (`ToriNPC.tscn`)**: Penjelajah rimba berjiwa petualang.
      - **Empu Bima (`BlacksmithNPC.tscn`)**: Ahli tempa perkakas dan peningkatan alat kebun.
      - **Prof. Baskoro (`university.tscn`)**: Dosen peneliti ekologi dan botani pulau.
      - **Pak Damar (`CarpenterNPC.tscn`)**: Tukang kayu dan arsitek konstruksi desa.
    - Integrasi penuh di scene `town.tscn` dengan rute jalan yang hidup, interaksi dialog kontekstual waktu, dan suite tes regresi otomatis (`tests/npc_regression.tscn`).
- **2026-10-12 (Versi 1.9)**:
  - **Penyelesaian Eksekusi Tahap 0 (Technical Debt)** [terpasang]:
    - **NPC Pandai Besi Interaktif (`BlacksmithNPC.tscn`)**: Pemain kini harus berinteraksi langsung dengan NPC Pandai Besi Empu Bima di samping landasan tempa (`town.tscn`) untuk membuka antarmuka upgrade alat (`tool_upgrade_ui.gd`), bukan melalui stasiun kosong.
    - **Lemari Pakaian (`Wardrobe.tscn`)**: Terpasang di interior rumah pemain (`interior_house.tscn`) untuk mengganti penampilan karakter kapan saja.
    - **Sinkronisasi Area Hutan (`forest_entrance.gd`)**: Transisi pintu masuk hutan kini disinkronkan menggunakan `UnlockManager.is_unlocked("forest")` sebagai *single source of truth*.
    - **Verifikasi Integritas**: Seluruh suite pengujian otomatis (`tools/verify_mvp.ps1`) lulus 100% tanpa regresi.
  - Penambahan 4 pilar fundamental Life-Sim / Farming RPG:
    - **Sistem Peternakan & Satwa (Bagian 4.10)**: Kandang Coop & Barn, Silo jerami, sapi, kambing, domba, unggas, kuda, kerbau lumpur, sistem pakan & affection hati.
    - **Mesin Pengolah Pasca-Panen (Bagian 4.11)**: Mayonnaise Maker, Cheese Press, Preserves Jar, Keg, Loom, Oil Maker, Fish Smoker.
    - **Sistem Cuaca Harian Dinamis (Bagian 4.1)**: Cerah, Hujan penyiram otomatis, Badai petir baterai, Kabut, Salju & Badai salju.
    - **Sistem Sosial, Persahabatan, & Warga Desa (Bagian 12)**: Friendship 10 Hati, sistem hadiah loved/hated, jadwal harian adaptif cuaca, Heart Events naratif, resep lewat surat, romansa/pernikahan/teman sekamar.
  - Penetapan resmi arsitektur progresi EXP Role menggunakan **Opsi B: Per-Activity EXP dengan Sentuhan Sistem Hybrid**:
    - 90% EXP diperoleh secara tematik dari aksi langsung masing-masing role (mencangkul = Farmer, memancing = Fisher, menambang = Miner, menangkis/menyerang = Combat, transaksi = Merchant, dll.) untuk menumbuhkan penguasaan keahlian alami dan pembagian peran gotong royong co-op keluarga.
    - 10% jalur universal fleksibel: Buku Panduan/Riset Perpustakaan & Universitas, Universal Skill Token dari Balai Nadi & Festival, serta transfer limpahan ilmu saat santap makan malam bersama di rumah co-op.
- **2026-10-12 (Versi 1.7)**:
  - Penambahan **Bagian 15: Sistem Ekonomi Dinamis, Pajak, dan Penyerapan Uang (Dynamic Economy & Money Sinks)**:
    - Keseimbangan kurva ekonomi dari early-game (kelangkaan modal) hingga late-game (kemakmuran terarah).
    - Mekanisme fluktuasi harga berdasarkan hukum penawaran & permintaan (*Supply & Demand*): over-supply memicu penurunan harga komoditas jenuh, barang langka/permintaan desa memicu lonjakan harga, serta papan buletin tren pasar mingguan.
    - Reaksi ekologis dunia terhadap eksploitasi impulsif: deforestasi berlebihan menurunkan harga kayu dan kelangkaan forage hutan, monokultur memicu kelelahan tanah (*soil fatigue*), dan over-fishing mendorong rotasi perairan.
    - Sistem tagihan mingguan (*utility bills*), pajak progresif kekayaan kas Balai Nadi, dan simulasi biaya peluang (*opportunity cost*).
    - Desain 5 pilar penyerapan uang skala besar (*Late-Game Money Sinks*): sertifikat perluasan lahan pulau/bukit, mansion mewah, mesin otomatisasi berbiaya perawatan, mega proyek infrastruktur kereta Modern City, dan lelang barang antik akhir musim.
- **2026-10-12 (Versi 1.6)**:
  - Penambahan **Bagian 14.3: Hari Raya & Perayaan Khusus (Festive Holidays)**:
    - **Hari Raya Idul Fitri (Pesta Lebaran Nusantara)**: Pawai tabuh bedug ritmik, tradisi silaturahmi halal bi halal mencicipi opor/ketupat/rendang ber-buff khusus, tradisi bagi-bagi THR berkah meningkatkan persahabatan desa, dan lomba anyam ketupat janur cepat.
    - **Hari Natal (Winter Star Festival)**: Pohon cemara raksasa bercahaya, tradisi tukar kado rahasia (*Secret Santa*), dan minigame memburu kado salju.
    - **Malam Tahun Baru (New Year's Eve)**: Pesta hitung mundur di puncak bukit/dermaga, minigame kembang api spektakuler (*Fireworks Rhythm Show*), dan montase kilas balik pencapaian tahunan tim.
- **2026-10-12 (Versi 1.5)**:
  - Penambahan **Bagian 14: Sistem Festival & Minigame Interaktif Semi-Chaos**:
    - Perumusan filosofi party game penuh aksi interaktif (input tombol aktif, bukan sekadar cutscene pasif) terinspirasi HM: Back to Nature, Coral Island, Mario Party Jamboree, Party Animals, dan LEGO Party.
    - Desain 9 minigame festival musiman: Balap Lari (dengan rintangan lumpur/pisang & saling menyenggol), Balap Karung (ritme lompat & tersandung ragdoll), Renang Bahari (ritme napas & ombak), Perang Tomat Splatfest (lempar tomat & knockback), Derby Balap Kuda (stamina & lompat pagar), Adu Ayam Sumo (sorak berkokok & dorong angin jerami), Pet Agility Race (rintangan anjing/kucing/kapibara), Perang Benteng Salju, dan Lomba Mancing Es Cepat.
    - Integrasi multiplayer split-screen 2–4 pemain (PvP party & kompetisi melawan NPC), piala pajangan rumah, dan hadiah EXP/uang tunai.
- **2026-10-12 (Versi 1.4)**:
  - Penambahan **Bagian 13: Sistem Lapak Dagang & Pekan Bazaar Interaktif (Inspirasi Grand Bazaar)**:
    - Desain mini-game berdagang real-time (bukan cutscene pasif) di Pekan Grand Bazaar mingguan dan stan ladang harian.
    - Mekanisme penataan meja etalase produk, pengaturan margin harga dan kualitas barang.
    - Fitur interaktif **Lonceng Lapak (*Bazaar Bell*)** dan teriakan panggil pembeli untuk memikat arus NPC yang melintas.
    - Sistem kasir interaktif: transaksi cepat, tawar-menawar (*haggling minigame*), rekomendasi produk silang, dan kepuasan pembeli.
    - Sinergi gotong royong co-op di stan (pembagian peran: Pemanggil Lonceng, Kasir Cepat, dan Penyuplai Stok).
    - Progresi level stan dagang (Meja Kayu $\rightarrow$ Kios Tenda $\rightarrow$ Paviliun Grand Bazaar Megah) dan papan target omzet mingguan.
- **2026-10-12 (Versi 1.3)**:
  - Penambahan **Bagian 12: Sistem Role, EXP, dan Skill Tree**:
    - Perumusan filosofi *classless progression* (tidak terkunci satu kelas, pemain bisa menguasai semua peran).
    - Desain sinergi gotong royong co-op keluarga: pembagian peran harian meningkatkan efisiensi tim secara signifikan.
    - Elaborasi 7 role utama: *Farmer, Forager, Fisher, Combat, Miner, The Merchant, The Economist* dengan formula perolehan EXP, pohon talenta Level 1–10, dan percabangan spesialisasi di Level 5 dan Level 10.
- **2026-10-12 (Versi 1.2)**:
  - Pemisahan jelas cakupan sistem tempur: **8.1 Combat MVP** (dasar & stabil) dan **8.2 Visi Lanjutan 2D Top-Down Soulslike**:
    - Mekanika Stamina-driven combat, Dodge roll dengan invulnerability frames (i-frames), Timed parry & riposte, Poise/Stagger meter, dan attack frame commitment.
    - Arsitektur kecerdasan musuh berbasis **Behavior Tree AI** dengan sensorik dinamis (Vision Cone, Hearing radius, alert states, flanking & spacing coordination).
    - Desain pertarungan Boss multi-fase di lantai kunci dungeon dengan serangan telegraphed AoE, anti-kiting response, dan arena fog gate.
- **2026-10-12 (Versi 1.1)**:
  - Mengadopsi seluruh 18 keputusan pemilik proyek dari Bagian 13 ke dalam isi dokumen:
    - Penetapan `UnlockManager` sebagai *single source of truth*.
    - Perubahan mekanisme Shipping Bin (dibayar saat tidur / kurir logistik).
    - Mekanisme upgrade alat ditinggal 1–2 hari di Blacksmith.
    - Pohon buah diubah menjadi pohon permanen lintas musim.
    - Penambahan tanaman khusus musim dingin dan aturan air beku mancing.
    - Penerapan denda pingsan (potongan uang dan kehilangan item).
    - Penetapan harga batangan logam progresif per tier (40 G s/d 1.500 G).
    - Penempatan permanen Balai Nadi di Kota dan Toko Combat di Gua.
    - Perumusan storytelling lengkap dan visi ekspansi *Endless Game* menuju Kota Modern (*Modern City*).
    - Status Cooking, Gathering Expansion, Combat, Cave/Dungeon, dan Kendaraan dinaikkan menjadi `[keputusan]`.
- **2026-10-11 (Versi 1.0)**:
  - GDD 1.0 disusun ulang dari isi proyek (crafting, bangunan, 80 equipment, tier alat, Balai Nadi save 8, Greenhouse save 9, fishing minigame, split-screen co-op).


### Konten gua 41+ — Gold, Frost–Ember, Shadow [terpasang 18 Oktober 2026]

Lantai aktif tetap 1–100. Setiap rentang sekarang berada di `resources/cave/bands/*.tres`; `cave_data.tres` menjadi katalog referensinya. Tabel bijih/permata/geoda sebelumnya dipertahankan.

| Lantai | Tier | Musuh baru (HP / ATK / DEF) | Template layout |
|---|---|---|---|
| 41–60 | Gold / Gua Emas | Slime Emas Tambang 95/40/6; Pemanah Emas 110/44/7; Myconid Sitrin 145/48/8 | `gold_a.tscn`, `gold_b.tscn` |
| 61–80 | Frost–Ember / Gua Bara Beku | Slime Beku 165/68/11; Penyihir Bara 145/78/9; Penjaga Bara 200/74/12 | `frost_ember_a.tscn`, `frost_ember_b.tscn` |
| 81–100 | Shadow / Gua Bayangan | Slime Bayangan 240/110/16; Pemanah Bayangan 210/116/14; Penyihir Bayangan 230/122/15 | `shadow_a.tscn`, `shadow_b.tscn` |

Angka dan komposisi adalah **balancing awal yang dapat diubah melalui Inspector**. Bobot musuh default 4:2:3; jumlah musuh Gold dan Frost–Ember 4–6, Shadow 5–7. Musuh memakai AI melee/ranged yang sudah ada, bukan jurus status baru. Setiap musuh memiliki prefab berisi SpriteFrames yang dapat diedit sebelum Play. Flash damage mempertahankan palette prefab.

Enam scene layout di `scenes/world/cave/tiers/` berisi dekorasi solid yang dapat digeser/edit melalui node Sprite2D dan CollisionShape2D. Collider template otomatis menutup area spawn batu, musuh dan pilar. Pemilihan template, isi dan posisi mengikuti seed harian. Lantai boss tetap arena lapang; tidak ada perubahan format save. Detail editor: [CAVE_EDITOR_GUIDE.md](CAVE_EDITOR_GUIDE.md).


### Layout dungeon utuh dan zona isi [terpasang 19 Oktober 2026]

Lantai tambang kini memilih satu dari tiga bentuk scene di `scenes/world/cave/layouts/`: cabang tambang, lingkar batu, dan rangkaian ruang. Scene berisi `GroundTiles`/`WallTiles`, marker kedatangan/tangga/lift, kandidat tangga turun, serta zona Rock/Ore/Gem/Enemy/Safe yang bisa diedit melalui Inspector. Pool layout disimpan pada `CaveBand.dungeon_scenes` untuk semua tier. Lantai danau yang dikonfigurasi dan arena boss memakai tata letak khusus.

Budget batu/mineral dan musuh tetap berasal dari tier. Zona mengatur distribusi, minimum/maksimum, whitelist mineral, kelompok endapan, serta kumpulan musuh khusus. Kategori mineral tersimpan pada `CaveOre.spawn_kind`; `is_gem` tetap kompatibel. Tidak ada koordinat layout atau komposisi tier dalam cabang generator. Semua bentuk awal tersimpan sebagai TileMap native di `.tscn`.

Validasi memastikan ground, lift/tangga dan kandidat tangga dapat dicapai dari Arrival. Rute utama dan area aman dijaga bebas spawn; template invalid dilewati. Tembok fisik mengikuti sel non-ground dan props solid yang didukung. Enemy memakai navigasi grid melalui koridor dan menghindari batu; penambangan memperbarui grid. Kandidat tangga dipilih saat tangga ditemukan, bukan muncul terbuka sejak awal. Semua isi memakai seed hari+lantai; tidak ada perubahan format save. Peti harta, puzzle, dan pintu berkunci belum ditambahkan. Panduan: [CAVE_EDITOR_GUIDE.md](CAVE_EDITOR_GUIDE.md).
