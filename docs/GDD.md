# Nusa Vale — Game Design Document (GDD)

Versi dokumen: 2.7 (15 Oktober 2026).
Dokumen ini adalah **sumber kebenaran desain** proyek `E:\nusa-vale` (Game Design Document resmi).
Pada versi 1.9, ditambahkan 4 pilar fundamental Life-Sim / Farming RPG: **Sistem Peternakan & Satwa** (kandang Barn/Coop, sapi, kambing, domba, ayam, bebek, kuda, pakan & affection), **Mesin Pengolah Pasca-Panen (Artisan Goods)** (mayones, keju, selai, fermentasi keg, tenun, pengasap ikan), **Sistem Cuaca Harian Dinamis** (cerah, hujan penyiram otomatis, badai petir penangkal baterai, salju), serta **Sistem Sosial, Persahabatan, & Jadwal Harian NPC** (hati 0-10, sistem hadiah loved/hated, rutinitas harian, heart events, dan romansa/teman sekamar).

## Cara membaca dokumen ini

Setiap angka atau aturan desain diberi label:

- **[terpasang]**: sudah ada di kode/Resource dan berfungsi di proyek saat ini.
- **[keputusan]**: sudah diputuskan oleh pemilik proyek (menjadi spesifikasi wajib yang harus diimplementasikan).
- **[usulan]**: ide lanjutan yang masih terbuka untuk penyempurnaan detail teknis lebih lanjut.

---

## Status implementasi hasil audit — 15 Oktober 2026

Proyek berada pada **alpha dengan banyak sistem inti terpasang**, berdasarkan inspeksi kode dan cakupan tes, belum berarti siap rilis. Lihat [audit](AUDIT_2026-10-15.md) dan [laporan progres](PROJECT_PROGRESS_2026-10-15.md). Catatan ini mengoreksi status historis di bawah tanpa membatalkan keputusan desain.

Verifikasi 15 Oktober: full suite berhenti gagal pada tes transisi Balai (referensi `ReturnFarm` di tes, `ReturnWorld` di scene). Sebelas kelompok regresi sebelumnya lulus; tes berikutnya belum dijalankan. Status ini tidak membatalkan bukti historis, tetapi proyek belum dapat dinyatakan lulus full suite terkini.

Kelanjutan sesi 15 Oktober: referensi lama pada dua tes Balai telah diperbaiki, menu kandang diberi guard ID invalid dan fixture carpenter diperkuat. Aturan penyiraman, tanah kosong dan syarat tier objek di bawah sudah diimplementasikan serta lulus tes. Seluruh cakupan runner selesai melalui gabungan run, dengan run terakhir feedback hingga save lulus. Ini bukan klaim satu full run baru tanpa interupsi. Bukti ada pada [laporan perubahan gameplay](GAMEPLAY_RULES_2026-10-15.md).

**Aturan gameplay terbaru [terpasang]:**

- Penyiraman pada tanah cangkul memakai stamina sekali per aksi sesuai tier (minimum 1) dan satu air per petak yang dituangi, termasuk petak yang sudah basah karena hujan/penyiraman sebelumnya. Tangki kosong, tanah tidak valid, atau stamina tidak cukup tidak menghabiskan air/stamina. Refill memakai biaya tersendiri sekali pada impact animasi.
- Tanah cangkul tanpa crop kembali menjadi ground pada pergantian hari berikutnya, baik basah maupun kering. Tanah dengan crop tetap ada meskipun belum disiram. Data di area yang tidak sedang dikunjungi juga dibersihkan; hasil tersimpan setelah save. Tanah bekas tanaman yang baru layu saat pergantian musim mengikuti pembersihan pada pergantian hari berikutnya.
- Kapak/Beliung Kayu hanya untuk kategori objek kecil; Tembaga membuka normal; Besi membuka besar. `Resource Size` dan `Minimum Tool Tier` dapat diatur di Inspector root objek. Syarat tier langka dapat lebih tinggi: batu emas minimal Emas. Menolak alat lemah tidak merusak objek atau memakai stamina.
- Pine/Birch/Maple dewasa memakai kategori normal; Mahogany/Deep Forest dewasa besar. Pohon muda dan serpihan kayu tetap dapat dipanen alat Kayu. Batu kecil/normal/besar tersedia dalam scene tersendiri; layout cleanup memakai ketiganya dengan ID save yang sama. Batu tembaga tetap dapat ditambang dengan Kayu, batu besi memerlukan Besi.

Panduan editor resep, karakter, animasi dan syarat objek: [EDITOR_GUIDE.md](EDITOR_GUIDE.md).

**Progres awal (2.7) [terpasang]:** Forest memiliki sumber bijih yang pulih 2 node/hari, kapasitas 10, enam node pada kunjungan pertama. Tembaga dapat ditambang dengan Kayu; endapan besi kecil memerlukan Tembaga dan membuka jalan menuju alat Besi. Spawn bijih dibatasi ke patch yang terhubung dari pintu masuk dengan alat awal. Tiga batu dekat rumah menjadi kecil untuk mencukupi akses bahan jembatan + Furnace; ID save dipertahankan. UI upgrade menampilkan kekuatan, kategori objek, dan sisa saldo. Harga serta biaya proyek tidak berubah. Audit cashflow, metode rute dan batas verifikasi ada di [EARLY_PROGRESSION_AUDIT_2026-10-15.md](EARLY_PROGRESSION_AUDIT_2026-10-15.md).

| Sistem | Terpasang | Batas implementasi |
|---|---|---|
| Loop inti | Farming, inventory, toko, shipping esok hari, crafting, alat, save | Playtest alur panjang dan balancing tetap diperlukan |
| Peternakan | Ayam, bebek, sapi, kambing, domba; perawatan, kualitas, merumput, interior, upgrade | Kuda, pembiakan, satwa tambahan belum selesai |
| Pengolahan | Furnace, Mayonnaise Maker, Cheese Press, Loom, Preserves Jar, Dehydrator | Keg, Oil Maker, Fish Smoker masih target |
| Dunia | Farm, rumah, Forest, Deep Forest, Town, Balai Nadi, Greenhouse | Gunung, dungeon, pantai, Modern City masih target |
| Town/NPC | 14 bangunan child scene, interior, dialog, jadwal, layanan | Klinik/rumah dasar; hati, hadiah, romansa belum selesai |
| Cuaca | Cerah/hujan; hujan menyiram outdoor | Badai, salju, petir/baterai, prakiraan masih target |
| Cooking | Lima resep, buku per pemain, stamina, buff laju | Dapur rumah, HP/combat, resep TV/sosial masih target |
| Biji Daya | Tiga sumber unik, kapasitas stamina 100–130 | Target 200 membutuhkan tujuh sumber tambahan |
| Fishing | Minigame, lokasi dan jam | `FishData` belum memiliki field musim; pembekuan air masih target |
| Co-op | Lokal split-screen 2–4 pemain | Gamepad fisik dan kenyamanan perlu playtest |
| Konten lanjutan | Data equipment dan spesifikasi desain | HP/combat/enemy/dungeon, role EXP, bazaar, festival, ekonomi dinamis belum dinyatakan terpasang |

Koreksi acuan implementasi:

- Viewport aktif `project.godot`: **1280 × 720**, window awal 1280 × 720; angka 960 × 540 di tabel lama sudah kedaluwarsa.
- `SAVE_VERSION = 13`; angka versi save pada bagian keputusan lanjutan bukan versi aktif.
- Stamina awal 100, maksimum pemain dapat naik melalui Biji Daya. Detail transaksi dan persistensi: [BIJI_DAYA.md](BIJI_DAYA.md).
- Pingsan batas waktu pada 05:10 memulangkan pemain, bangun 08:00 dengan 50% kapasitas stamina; pemain co-op yang sudah tidur pulih penuh. **Tidak memotong uang atau item**. Denda medis/combat pada bagian 4.2 dan rekap keputusan tetap target terpisah, belum terpasang.
- Shipping dibayar saat pergantian hari melalui `ShippingManager.settle`, ke saldo bersama dan ringkasan pendapatan. Kurir sore masih rancangan.
- Restorasi Balai Nadi membutuhkan **100 kayu + 50 batu + 500 G**; Greenhouse 150 kayu + 75 batu + 5 copper_bar. Akses Balai dari town sudah terpasang.
- `DailyWeather`: hari pertama cerah; berikutnya peluang hujan 30% berdasarkan seed tersimpan. Desain lima cuaca di bagian 4.1 belum seluruhnya tersedia.
- Deep Forest sudah terpasang di `scenes/world/DeepForest.tscn`: akses Forest + 3.000 G + 150 kayu + 75 batu untuk unlock permanen. Area gathering ini bukan dungeon combat. Lihat [DEEP_FOREST.md](DEEP_FOREST.md).
- Durasi mesin menggunakan detik aktif, pause menghentikan proses, tidur/offline tidak memberikan catch-up. Lihat [PROCESSING_AUDIT.md](PROCESSING_AUDIT.md).
- Usulan peternakan pada bagian 4.10 yang telah diwujudkan mengacu pada aturan aktual [LIVESTOCK_CORE_LOOP.md](LIVESTOCK_CORE_LOOP.md); angka historis bukan spesifikasi kedua.

Prioritas rekomendasi audit: stabilisasi dan playtest loop lengkap → selaraskan kriteria MVP terhadap target combat → HP/combat dasar dan satu area dungeon → perluasan sosial/konten. Urutan ini rekomendasi, bukan perubahan keputusan fitur pemilik proyek.

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
| Pemain | 1 pemain, atau co-op lokal split screen 2-4 pemain | [terpasang] |
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
6. Eksplorasi malam diperbolehkan sampai 05:00 dengan kabut, ambience horror, dan siluet setelah tengah malam di luar ruangan. Tidur di kasur paling lambat 05:00 (hari baru + simpan otomatis). Pada tick 05:10 pemain terjaga **pingsan**, dipulangkan, dan bangun 08:00 dengan stamina 50%; pemain co-op yang sudah berbaring pulih penuh. Tidak ada kehilangan item akibat batas waktu.

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
| Balai Nadi | `scenes/world/balai_nadi/exterior.tscn`, `interior.tscn` | Gedung permanen di Kota dengan pintu masuk permanen; meja kontribusi proyek restorasi desa | [keputusan] |
| Hutan (Forest) | `scenes/world/Forest.tscn` | Pohon spawn, batu tembaga, batu besi, forage musiman, rumput liar, titik gali, sungai hutan | [terpasang] |
| Kota (Town) | `scenes/world/town.tscn` | Toko General Store, Sekolah, Universitas, Blacksmith (Pandai Besi), Warung Makan, Klinik, Balai Nadi permanen, rumah warga | [terpasang + keputusan] |
| Gunung (Mountain) | scene baru | Area berbatu menuju pintu masuk Gua, spot forage pegunungan, stasiun/jalur ke Modern City (harus di-unlock) | [keputusan] |
| Gua / Dungeon | scene baru | Lantai tambang bertingkat, batu bijih langka (Gold ke atas), monster musuh, tangga turun, Toko Combat | [keputusan] |
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

**Sistem Cuaca Harian Dinamis (Weather System) [keputusan]**:
- Prakiraan cuaca diprediksi setiap hari melalui siaran Televisi di rumah atau papan cuaca desa.
- Variasi Cuaca:
  1. **Cerah (Sunny / Clear)**: Cuaca standar; sinar matahari cerah, tanaman membutuhkan siraman air manual.
  2. **Hujan (Rainy)**: Langit mendung dan rintik hujan; **secara otomatis menyiram seluruh petak ladang luar ruangan** sepanjang hari (pemain menghemat stamina dan air untuk fokus menjelajah gua/memancing). Beberapa spesies ikan langka hanya aktif saat hujan.
  3. **Badai Petir (Thunderstorm / Heavy Storm)**: Hujan lebat disertai kilat dan guruh. Berisiko menyambar tanaman/pohon liar kecuali dilindungi oleh **Penangkal Petir (*Lightning Rod*)**. Penangkal petir yang tersambar menghasilkan item berharga *Battery Pack* untuk perakitan teknologi otomatis.
  4. **Berkabut (Foggy / Overcast)**: Hutan diselimuti kabut tebal; jamur dan forage langka bermunculan lebih banyak di hutan.
  5. **Salju & Badai Salju (Snow & Blizzard)**: Terjadi di musim dingin; permukaan tanah membeku, suhu dingin menuntut pemain mengenakan pakaian hangat atau masakan berbuff penghangat tubuh.

### 4.2 Stamina, Tidur, dan Denda Pingsan [terpasang + keputusan]

- Stamina awal 100 per pemain; kapasitas aktual dapat naik sampai 130 melalui tiga Biji Daya yang sudah tersedia.
- Biaya stamina alat sekali per ayunan (berkurang drastis pada tier tinggi, lihat tabel 4.5).
- Memungut forage dan menebas rumput liar tidak menggunakan stamina (stamina cost = 0) [keputusan].
- Tidur di kasur rumah memulihkan stamina 100%, memicu pergantian hari, dan menyimpan game otomatis.
- **Pingsan batas waktu [terpasang]**: 05:10, bangun 08:00 di rumah dengan 50% kapasitas stamina; tanpa kehilangan uang/item. Pemain co-op yang sudah tidur pulih penuh.
- **Denda medis/dungeon [keputusan, belum terpasang]**:
  - Jika kehabisan HP di dungeon: target pemain bangun jam 08:00 di klinik/rumah dengan stamina 50%.
  - Dikenakan sanksi **potongan uang** (biaya perawatan medis) dan/atau **kehilangan sebagian item secara acak** di inventory tas.

### 4.3 Inventory, Equipment, dan Lokalisasi Bahasa [terpasang + keputusan]

- Ransel 36 slot (aktif 12 / 24 / 36 sesuai `bag_level`). Upgrade ransel dibeli di toko (2.000 G dan 10.000 G).
- Hotbar 8 slot dengan tombol geser halaman (Tab / Gamepad Back).
- Sortir tas (R) otomatis menggabungkan stack dan merapikan alat di depan.
- Equipment: 5 slot (`weapon`, `helmet`, `armor`, `leggings`, `boots`). 80 varian equipment tersedia dalam database.
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
  - Copper: 500 G + 5 copper_bar + 10 wood
  - Iron: 1.200 G + 5 iron_bar + 15 wood
  - Gold: 2.500 G + 5 gold_bar
  - Platinum: 4.500 G + 5 platinum_bar
  - Crimson: 7.000 G + 5 crimson_bar
  - Frost: 10.000 G + 5 frost_bar
  - Shadow: 14.000 G + 5 shadow_bar
  - Fairy: 20.000 G + 5 fairy_bar
  - Obsidian: 28.000 G + 5 obsidian_bar

Balancing demo saat ini tercatat pada `ECONOMY_BALANCE.md`: margin 39 tanaman,
jumlah panen, stamina, pakan, produk ternak, olahan, serta target progres awal.

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

### 4.10 Sistem Peternakan & Satwa (Animal Husbandry & Ranching) [terpasang + keputusan + usulan]

**Implementasi core loop (13 Oktober 2026) [terpasang]**: ayam, bebek, sapi, kambing, domba; pakan dan jerami; elusan +3 dan sikat +1 sehari; kebersihan, kesehatan/pemulihan; telur, susu, wol dengan ukuran/kualitas; petak rumput pakan dan hewan berjalan di ladang; silo 240 jatah; upgrade kandang 4/8/12 dan auto-feeder; Mesin Mayones, Mesin Keju, Alat Tenun; save/load dan perawatan bersama co-op. Panduan aturan aktual dan harga ada di **[LIVESTOCK_CORE_LOOP.md](LIVESTOCK_CORE_LOOP.md)**. Angka usulan di bawah yang sesuai panduan tersebut kini sudah terpasang. Kuda, kerbau, kapibara, inkubasi/pembiakan, bulu bebek, serta festival masih rancangan lanjutan.

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
| Kuda, ayam jago, kapibara | Mobilitas/festival/kedekatan | Tidak memproduksi komoditas harian | Perawatan mengikuti kebutuhan spesies |

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

### 4.11 Mesin Pengolah Pasca-Panen (Artisan Goods & Processing) [keputusan]

Mesin pengolah yang dapat dirakit melalui Crafting dan ditempatkan di ladang atau gudang untuk mengubah komoditas mentah menjadi produk bernilai tinggi:
- **Mayonnaise Maker**: Telur biasa $\rightarrow$ Mayones (nilai jual +50%); Telur Emas/Besar $\rightarrow$ Mayones Kualitas Emas.
- **Cheese Press**: Susu Sapi $\rightarrow$ Keju Batangan; Susu Kambing $\rightarrow$ Keju Kambing (*Goat Cheese* bernilai jual tinggi).
- **Preserves Jar (Toples Pengawet)**: Buah segar $\rightarrow$ Selai Manis (*Jam*); Sayuran $\rightarrow$ Acar Segar (*Pickles*).
- **Keg (Tong Fermentasi)**: Gandum $\rightarrow$ Bir Olahan; Buah $\rightarrow$ Anggur/Jus Buah Fermentasi (membutuhkan waktu fermentasi 2–4 hari).
- **Loom (Alat Tenun)**: Wol domba $\rightarrow$ Kain Halus (*Cloth*) untuk bahan pakaian dan dekorasi.
- **Oil Maker**: Jagung / Biji Bunga Matahari / Truffle $\rightarrow$ Minyak Masak & Minyak Truffle bernilai mewah.
- **Fish Smoker (Pengasap Ikan)**: Ikan mentah + kayu $\rightarrow$ Ikan Asap bernilai jual 2x lipat dan memulihkan stamina tinggi.

---

## 5. Sistem Memancing (Fishing) [terpasang + keputusan]

- Mini-game melempar kail dengan meteran tenaga, menunggu gigitan, dan menyeimbangkan barra tangkapan hijau mengikuti ikon ikan.
- 65 spesies ikan dengan 5 tingkat kelangkaan (Umum, Tidak Umum, Langka, Epik, Legendaris) dan variasi lokasi/jam tangkap.
- **Musim Ikan (`seasons` di `FishData`) [keputusan]**:
  - Ditambahkan atribut daftar musim ke dalam data ikan. Spesies ikan tertentu hanya dapat dipancing pada musim yang sesuai.
- **Air Beku Musim Dingin [keputusan]**:
  - Permukaan danau dan sungai biasa membeku di musim dingin sehingga aktivitas memancing di luar ruangan diblokir.
  - Pemain dapat memancing di musim dingin hanya jika telah membuka akses ke area pancing khusus (seperti pemandian air panas tersembunyi atau danau bawah tanah di dalam gua).

---

## 6. Sistem Memasak (Cooking) [terpasang sebagian + keputusan]

Tahap dasar (14 Oktober 2026) [terpasang]: panci Dapur Warung di town,
lima resep, pembelian buku per pemain, makanan pemulih stamina, buff laju
sementara, dan save/load resep. Lihat `COOKING.md`. Dapur rumah setelah
upgrade, HP/combat serta resep dari TV/hadiah sosial masih [keputusan].

- **Status**: Disetujui untuk diimplementasikan [keputusan].
- **Fasilitas**: Dapur di interior rumah (setelah upgrade rumah) serta kompor/panci di Warung Makan kota.
- **Kategori Item**: Kategori baru `FOOD` (= 9) pada `ItemData.Category`.
- **Manfaat**:
  - Memulihkan Stamina dan Health Point (HP).
  - Memberikan efek status/buff sementara (kecepatan jalan, keberuntungan memancing, peningkatan serangan/pertahanan di dungeon).
- **Resep Masakan**: Menggunakan bahan hasil tani, ikan, telur/ternak, dan forage (misal: Ikan Bakar Lele, Sup Sayur Bening, Salad Buah, Roti Gandum, dsb.).
- Resep dipelajari dari siaran TV, membeli buku resep di Warung, atau hadiah persahabatan warga.

---

## 7. Ekspansi Pengumpulan Alam (Gathering Expansion) [keputusan]

- **Status**: Disetujui untuk diimplementasikan [keputusan].
- Penangkapan Serangga (*Bug Catching*): Menggunakan jaring serangga untuk menangkap kupu-kupu, kumbang, kunang-kunang di ladang, hutan, dan gua.
- Ekspansi titik forage musiman ke area Kota, Pegunungan, dan Pantai.
- Pohon liar dapat disadap (*Tapper*) untuk menghasilkan getah, resin, atau sirup.

---

## 8. Sistem Pertarungan (Combat) & Musuh [keputusan]

### 8.1 Cakupan Combat untuk Fase MVP [keputusan - Target MVP]
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

#### A. Mekanika Tempur Kompleks Berbasis Stamina & Timing (Soulslike Core)
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

#### B. Kecerdasan Buatan Musuh Tingkat Lanjut (Behavior Tree AI)
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

---

## 9. Gua Tambang & Dungeon [keputusan]

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

## 10. Kendaraan & Mobilitas [keputusan]

- **Sepeda (Bicycle)**:
  - Dibeli di toko desa sebagai peningkatan kecepatan mobilitas tanpa perlu menahan tombol Shift.
  - Memberikan kecepatan gerak 2x lipat kecepatan jalan biasa di jalanan luar ruangan.
- **Sapu Terbang (Broomstick)**:
  - Item sihir / teknologi eksotis tingkat tinggi.
  - Memberikan kecepatan 3x lipat dan kemampuan melintasi rintangan air atau jurang pendek.
- Kendaraan tidak dapat digunakan di dalam ruangan sempit.

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

## 12. Hubungan Sosial, Persahabatan, & Warga Desa (NPC Schedules & Friendship) [keputusan]

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
  - *Peluruhan Hubungan (Decay)*: Jika pemain tidak berbicara dengan warga selama berpekan-pekan, poin persahabatan berkurang sangat sedikit (hanya -2 poin/hari jika belum mencapai 10 hati; setelah 10 hati, hubungan permanen terkunci dan tidak pernah luntur).

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
- Warga yang senang dengan pemain akan mengirimkan surat kejutan di kotak surat ladang:
  - Berisi resep masakan keluarga (*Family Recipes*) untuk dimasak di dapur rumah (misal: Pak Joko mengirimkan resep Rawon Rempah dan Sayur Lodeh Istimewa).
  - Bingkisan bahan material langka (misal: Empu Bima sesekali mengirim batangan besi/emas, warga tani mengirim bibit langka).

---

### 12.5 Romansa, Pernikahan, & Teman Sekamar (Romance, Marriage, & Roommates)
- **Karakter Lajang (Marriage Candidates)**: Tersedia beberapa kandidat warga desa yang dapat dijalin hubungan romantis.
- **Pemberian Buket Bunga (Bouquet pada 8 Hati)**: Membuka hati ke-9 dan ke-10 sebagai tanda resmi berpacaran (*Dating*).
- **Lamaran & Bunga Pengantin (Pendant Lamaran pada 10 Hati)**:
  - Rumah pemain minimal telah ditingkatkan ke Level 2 (memiliki ranjang ganda).
  - Pasangan akan pindah tinggal bersama di rumah pemain, membantu menyiram tanaman sesekali, memberi makan ternak, atau memasakkan sarapan pagi hangat.
- **Pilihan Teman Sekamar Platonic (Roommate Option)**:
  - Pemain yang tidak ingin menikah dapat mengundang sahabat non-romantis (atau satwa/makhluk unik) untuk tinggal bersama sebagai teman sekamar platonis.

---

## 13. Sistem Role, EXP, dan Skill Tree (Co-op Synergy) [keputusan]

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
- **Tab Keahlian (Skills Tab)**: Terintegrasi pada menu ransel (`I` / Gamepad `Y`), menampilkan 7 panel role dengan progres bar EXP, level aktif, dan bagan Skill Tree.
- **Notifikasi Level Up**: Layar rekap tidur malam menampilkan animasi "Level Up!" lengkap dengan perolehan stat baru dan pilihan pemilihan perk spesialisasi.
- **Sinergi Tim Co-op**: Di menu Co-op, buku status menampilkan ringkasan profil keahlian pemain lain sehingga anggota keluarga dapat saling berkoordinasi untuk membagi tugas secara optimal setiap pagi.

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
  - Pemain berdiri di stan dan menekan tombol interaksi panggil (Spasi / Gamepad `X`) untuk membunyikan **Lonceng Lapak (*Bazaar Bell*)** atau berseru menawarkan dagangan (*"Ayo mampir! Sayur dan ikan segar baru dipanen hari ini!"*).
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
8. **Denda Pingsan**: jalur batas waktu hanya menerapkan bangun 08:00/stamina 50%, tanpa potongan uang/item [terpasang]. Potongan uang atau kehilangan item pada jalur medis/dungeon masih target [keputusan].
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
5. **Format Penyimpanan EXP & Skill Tree di Save Game**: Menentukan struktur dictionary `skills` pada `SaveManager` (SAVE_VERSION aktif = 13).
6. **Layout Alun-Alun Pekan Bazaar**: Menentukan posisi deretan stan pemain dan rute jalan NPC pembeli di alun-alun kota pada scene `town.tscn`.
7. **Tanggal Pasti Kalender Hari Raya**: Menetapkan tanggal kalender (1–28) per musim untuk Hari Raya Idul Fitri, Natal (25 Dingin), dan Malam Tahun Baru (28 Dingin).
8. **Formula Numerik Fluktuasi Pasar**: Menentukan batas ambang kuantitas penjualan harian (misal: threshold > 50 item) sebelum harga pasar mengalami penurunan 10%.

---

## 19. Changelog

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
