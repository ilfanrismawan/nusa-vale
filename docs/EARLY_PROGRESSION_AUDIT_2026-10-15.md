# Audit progres awal — 15 Oktober 2026

## Hasil utama

Audit menemukan kekurangan pasokan tembaga dan dependensi melingkar menuju alat Besi setelah pembatas tier objek diberlakukan. Keduanya telah ditangani dengan bijih Forest yang dapat pulih dan endapan besi kecil yang membutuhkan Tembaga. Tiga batu dekat area rumah diubah menjadi kecil untuk memberi margin bahan awal. Harga, biaya restorasi dan durasi upgrade tidak diubah.

Ini inspeksi data, analisis rute collision, serta pengujian runtime headless. Ini **bukan** sesi bermain manual beberapa hari, pengukuran waktu tempuh manusia, atau bukti balancing akhir. Tahap smelting/upgrade memakai fixture uang dan material yang dinyatakan dalam tes; hasil tersebut tidak berarti seluruh dana diperoleh dalam playthrough utuh.

## Temuan dan perbaikan

| Temuan | Bukti | Perbaikan |
|---|---|---|
| Sumber tembaga tetap tidak cukup | Dua RockCopper di Forest masing-masing 4 bijih; Furnace meminta 10, lima batangan tambahan meminta 10 lagi | OreSpawner Forest: 2 node baru per hari, kapasitas 10, enam node pada kunjungan pertama; tembaga tetap dapat ditambang dengan Kayu |
| Upgrade Besi memerlukan hasil tambang yang mensyaratkan Besi | RockIron besar membutuhkan tier Besi; upgrade membutuhkan 5 iron_bar | `small_iron_rock.tscn`: minimal Tembaga, 2 bijih per node; RockIron besar tetap mensyaratkan Besi |
| Total bahan ada, tetapi tidak semuanya terjangkau dari spawn | Model rute Farm sebelum penyesuaian memberi 74 batu terjangkau; jembatan + Furnace meminta 75 | Rock25, Rock44, Rock46 menjadi small_rock; posisi dan persistence ID dipertahankan |
| Bijih acak dapat terletak di balik objek tier terkunci | Probe rute Forest menunjukkan hanya sebagian hasil spawn awal terhubung ke pintu masuk | Kandidat spawn dibatasi ke patch terbuka yang terhubung dari entrance, menghormati collision, ground dan jembatan; pemilihan kandidat langsung dari patch tersebut |
| Manfaat upgrade kurang jelas | Kapak/beliung Tembaga masih menampilkan stamina/area yang sama dengan Kayu | UI menambahkan kekuatan pukulan, kategori objek dan sisa saldo setelah biaya |
| Feedback pickup dapat memanggil HUD yang sudah dibebaskan | Tes memicu error CallbackTweener `_fly_done` ketika area/HUD ditutup | Callback menyimpan WeakRef ke hotbar; feedback tetap selesai jika target sudah tidak ada |

## Sumber daya dan kebutuhan

| Tahap | Kebutuhan |
|---|---|
| Jembatan Forest | 100 kayu + 50 batu |
| Furnace | 10 copper_ore + 25 batu |
| Beliung Tembaga | 500 G + 5 copper_bar (= 10 copper_ore) + 10 kayu; dua pergantian hari |
| Beliung Besi | 1.200 G + 5 iron_bar (= 10 iron_ore) + 15 kayu; dua pergantian hari |
| Balai Nadi | 100 kayu + 50 batu + 500 G |
| Greenhouse | 150 kayu + 75 batu + 5 copper_bar |

Layout Farm setelah perubahan memiliki 489 kayu dan 92 batu yang secara kategori dapat dipanen dengan alat Kayu. Model rute pada seed uji dapat menjangkau 433 kayu dan 80 batu dengan membuka objek tier Kayu, sambil mempertahankan collision objek tier terkunci. Ini cukup untuk jembatan + Furnace (75 batu) serta kayu jembatan dan upgrade pertama (110).

Model memakai bentuk collision pemain, offset kaki, grid ortogonal dan jangkauan bidik termasuk diagonal. Objek yang bisa dibersihkan dengan tier yang sedang dianalisis dianggap dapat disingkirkan sepanjang rute. Model tidak mensimulasikan setiap langkah/input maupun seluruh stamina perjalanan. Angka terjangkau bukan persediaan gratis atau hasil satu hari.

Seluruh stok awal tier Kayu memerlukan 2.388 stamina untuk kayu dan 368 untuk batu, berdasarkan health/damage/cost aktual. Tidak perlu menghabiskan semuanya untuk milestone pertama; angka ini menunjukkan bahwa memperbaiki jembatan, menabung material, dan upgrade tetap membutuhkan beberapa hari kerja. Stamina awal 100 dapat bertambah melalui Biji Daya.

## Cashflow panen pertama

Asumsi: semua bibit starter dipanen dan dijual, tanpa belanja lain; uang awal bersama 100 G. Lima stroberi menghasilkan 10 buah × 33 G; tiga wortel menghasilkan 3 × 60 G. Total penjualan 510 G per pemain. Pembayaran shipping tetap menunggu pergantian hari. Membeli ulang paket 5 bibit stroberi + 3 wortel memerlukan 225 G per pemain.

| Pemain | Penjualan starter tim | Saldo setelah satu upgrade Tembaga | Saldo setelah setiap pemain upgrade | Modal ulang bibit tim |
|---|---:|---:|---:|---:|
| 1 | 510 G | 110 G | 110 G | 225 G |
| 2 | 1.020 G | 620 G | 120 G | 450 G |
| 4 | 2.040 G | 1.640 G | 140 G | 900 G |

Panen pertama dapat membayar satu upgrade, tetapi belum sekaligus membiayai seluruh penanaman ulang untuk solo. Co-op juga kekurangan modal bila semua pemain langsung upgrade. Ini tekanan modal, bukan softlock: pemain dapat menunda order, menanam ulang sebagian, atau memperoleh pendapatan dari sumber lain. Untuk co-op, memprioritaskan satu penambang beralat Tembaga mempertahankan modal bibit tim lebih baik daripada semua orang upgrade bersamaan.

Belum ada dasar playtest manual untuk mengubah harga. UI kini memperlihatkan sisa saldo sebelum order; langkah berikutnya adalah mengukur apakah keputusan modal tersebut terasa wajar saat dimainkan. Model belum memasukkan hasil forage/fishing, kebutuhan tas, waktu tempuh dan penghasilan dari mesin.

## Aturan bijih Forest

- Node `Forest/OreSpawner` dapat diedit melalui Inspector: `Daily Spawn`, `Max Active`, serta `Entrance Position` yang harus tetap sesuai pintu masuk Forest.
- Tembaga menjatuhkan 4 bijih; endapan besi kecil 2. Pilihan jenis menyeimbangkan jumlah node yang masih tersimpan, sehingga menghabiskan tembaga tidak membuat suplai hanya berisi besi.
- Persistensi memakai `ForageManager` pada `forest#ore`: sel, jenis dan hari spawn tersimpan. Memanen menghapus record; keluar-masuk atau mengganti pemain co-op pada hari yang sama tidak menambah hasil.
- Penambahan antarahari, catch-up, batas kapasitas, dan pergantian musim memakai fondasi spawner yang sama. Tidak membersihkan bijih hanya karena musim berubah.
- Batu tetap dan batu besar tidak dihapus atau diturunkan tiernya. Save versi 13 tetap digunakan; tidak ada perubahan skema.

## Verifikasi dan batasnya

Tes baru `early_progression_regression.tscn` menguji stok aktual, cashflow, sumber yang muncul pada Forest sungguhan, jangkauan resource menurut tier, penghapusan drop, kunjungan ulang, save/load, konteks inventori co-op, crafting Furnace, peleburan dan order Kayu → Tembaga → Besi. Pop/chop serta waktu kerja dipercepat oleh tes; fixture downstream menggunakan 1.700 G untuk memeriksa biaya tepat dua order.

`starter_routes_regression.tscn` memeriksa akses bahan Farm di sekitar objek tier terkunci. Kedua tes terdaftar di `tools/verify_mvp.ps1` dan wajib mengeluarkan marker selesai dengan `failures=0`.

Hasil akhir (seluruh run berikut selesai exit 0):

- `scratch/progression-parser-2026-10-15.log`: editor/parser bersih.
- `scratch/progression-route-final-2026-10-15.log`: early progression, starter routes, co-op 2–4 pemain, Forest fishing dan Deep Forest lulus setelah perubahan terakhir pada pemilihan kandidat spawn.
- `scratch/forest-ore-coop-verified-2026-10-15.log`: tes khusus dua pemain di Forest lulus. P2 dapat menambang tanpa mengurangi stamina P1; empat unit hasil masuk hanya ke tas P2; node bersama dihapus satu kali; unload/reentry pada hari yang sama tidak memulihkan hasil.
- `scratch/progression-audit-verified-2026-10-15.log`: UI layanan/upgrade dan save/rollback lulus, bersama pemeriksaan progres/rute serta integrasi area. Error I/O yang disengaja pada tes save diterima runner karena audit berakhir `failures=0`.
- `scratch/early-progression-final-verified-2026-10-15.log`: economy balance, durasi/persistensi mesin dan farm cleanup juga lulus pada batch pendukung.

Pada run rute terakhir, Forest menyediakan 12 copper_ore yang terjangkau pada kunjungan awal. Setelah panen dan pemulihan antarahari, tes mengukur 12 bijih yang sudah dipegang serta 20 yang dapat dijangkau berikutnya; endapan kecil menyediakan jalur ke 10 iron_ore menggunakan tier Tembaga. Jumlah/posisi acak dan waktu tempuh pada seed lain tidak dinyatakan identik.

Seluruh cakupan yang relevan diperiksa melalui beberapa run, bukan satu full suite baru tanpa interupsi. Tes feedback HUD sengaja memulai ikon pickup lalu membebaskan area/hotbar; callback selesai tanpa error. Semua tes memakai APPDATA sementara, tidak membaca/menimpa save pemain. Kegagalan pengembangan dan probe lama tetap berada di scratch sebagai riwayat, bukan hasil run akhir.

## Prioritas berikutnya

Mainkan jalur awal dengan UI sebenarnya pada solo dan co-op: catat hari pertama jembatan, Furnace, alat Tembaga/Besi, Balai dan Greenhouse; frekuensi tas penuh; sisa modal bibit; serta kebutuhan pulang/isi air. Setelah pacing dan kontrol tersebut diterima, milestone implementasi besar berikutnya tetap satu loop HP/combat/dungeon dasar. Audit ini belum menambahkan combat atau menyatakan MVP selesai.
