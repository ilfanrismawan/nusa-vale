# Laporan Tinjauan GDD Nusa Vale

> Pembaruan status 22 Oktober 2026: pemilik mengonfirmasi playtest loop inti solo/co-op **sudah dilakukan dan lulus**. Rekomendasi playtest umum di dokumen historis ini tidak lagi menjadi prioritas aktif. Gunakan [PLAYTEST_STATUS.md](PLAYTEST_STATUS.md) dan GDD terkini; pengujian perubahan baru tetap berlaku.


Tanggal laporan: 20 Oktober 2026. Acuan: GDD v3.26 (19 Oktober 2026), kode/resource workspace, dan log regresi 19 Oktober. Laporan ini merupakan snapshot; perubahan setelah pemeriksaan perlu diverifikasi kembali.

## Kesimpulan

GDD sudah kaya dan cukup kuat sebagai visi Farming/Life-Sim RPG, tetapi belum konsisten sebagai acuan status implementasi. Proyek memiliki banyak sistem inti pada tahap alpha. Hambatan terdekat adalah stabilitas integrasi, keselarasan dokumentasi, dan kriteria penerimaan MVP yang belum tegas. Jumlah fitur atau resource tidak membuktikan kesiapan rilis.

Prioritas yang disarankan: bereskan pintu dan regresi yang gagal, satukan status GDD, lalu buktikan satu alur permainan lengkap solo/co-op sebelum menambah sistem besar berikutnya.

## 1. Hal yang sudah kuat

- Loop farming, gathering, inventory, shop, shipping, crafting, peternakan, fishing, cooking, dan upgrade saling mendukung.
- Combat, Gunung, dan Gua 1–100 sudah memiliki implementasi; rekomendasi lama untuk mulai membangun HP/combat dasar sudah tertinggal.
- Pemisahan data Resource, pengaturan Inspector NPC, jadwal/rute, serta panduan editor memudahkan pengembangan konten.
- Persahabatan dan progres pemain co-op memiliki fondasi persistensi. Save manager saat diperiksa memakai versi 22.
- Bagian 13.4 sudah menjelaskan implementasi Role/EXP, cabang perk, buku riset, dan Token Talenta, termasuk perk yang masih “Segera hadir”.

## 2. Ketidaksesuaian di dalam GDD

| Prioritas | Temuan | Dampak dan koreksi yang diperlukan |
|---|---|---|
| Tinggi | Ringkasan awal menyebut Role EXP belum terpasang, sedangkan 13.4 menyatakan sudah terpasang sebagian dan kode/data tersedia | Pindahkan ke kolom terpasang sebagian; pertahankan daftar perk yang belum tersedia. Keberadaan kode belum sama dengan hasil tes lulus. |
| Tinggi | Tabel area menyebut Gunung/Gua sebagai “scene baru” berstatus keputusan, sementara bagian 9 menjelaskan scene dan implementasinya | Gunakan path scene aktual, pisahkan area tersedia dari fitur lanjutan seperti jalur Modern City. Selaraskan juga status Balai, Hill, dan Deep Forest. |
| Sedang | Ringkasan Cooking dan bagian 6 masih memakai acuan lima resep | Saat diperiksa ada 137 resource resep dan 22 equipment memasak. Bedakan jumlah data, resep yang terhubung ke katalog, akses unlock, dan hasil playtest. |
| Sedang | Ringkasan pengolahan belum mencantumkan Beehive, Sawmill, Alchemy Table, dan Anvil | Perbarui daftar, tetapi beri catatan regresi crafting expansion masih gagal. Fermentation barrel sebagai alat cooking bukan bukti loop artisan Keg selesai. |
| Sedang | Bagian equipment menyebut 80 varian | Hitungan audit resource sebelumnya menemukan 96 resource dengan slot eksplisit: 30 senjata dan 66 wearable. Tujuh slot wearable tidak termasuk senjata hotbar. Tetapkan definisi hitungan agar tidak rancu dengan ammo/alat. |
| Sedang | Aturan umum semua mesin memakai detik aktif terlalu luas | Beehive memakai siklus hari permainan dan penundaan musim dingin; dokumentasikan pengecualian terhadap mesin berbasis detik. |
| Sedang | Tanggal/status audit awal masih 15 Oktober, tetapi changelog dan fitur sudah sampai 19 Oktober | Buat satu ringkasan status terkini; simpan hasil lama sebagai riwayat, bukan bukti verifikasi versi sekarang. |
| Sedang | Label “terpasang” didefinisikan sebagai sudah berfungsi, tanpa membedakan bukti runtime dan verifikasi | Tambahkan status verifikasi: tersedia di kode/data, lulus tes tertentu, atau sudah playtest. Hindari menjadikan keberadaan file sebagai klaim fitur selesai. |

Acuan: [GDD](GDD.md), terutama ringkasan status, bagian 3, 4.13, 6, 12, dan 13.4.

## 3. Temuan implementasi yang memengaruhi desain

### P1 — Pintu HerbalHouse menunjuk scene yang tidak ada

`scenes/world/exterior/town/herbal_house.tscn` masih menargetkan `res://scenes/world/interior/town/house_teal.tscn`. File tersebut tidak ada; `scenes/world/interior/town/herbal_house.tscn` tersedia. Klaim semua interior Town dapat diakses perlu dibatasi sampai referensi ini diperbaiki dan transisinya diuji.

Tes Town juga mengasumsikan node `CollisionShape2D`, sedangkan bangunan ini memakai `CollisionPolygon2D`. Assertion tersebut perlu menerima bentuk collider valid. Tes harus menghentikan pemeriksaan dengan pesan jelas ketika load scene gagal agar tidak berlanjut ke instantiate null dan timeout.

### P2 — Hubungan 10 hati belum mengikuti janji permanen

Bagian 12 menyatakan setelah mencapai 10 hati hubungan terkunci permanen. `scripts/npc/npc_social_service.gd` hanya menonaktifkan decay ketika poin saat ini mencapai 2500. Hadiah negatif bisa menurunkan poin, lalu decay dapat berlaku lagi. Belum ada penanda historis “pernah mencapai 10 hati”. Implementasi perlu mengikuti keputusan tersebut, atau perubahan desain harus ditetapkan secara eksplisit.

### P2 — Fondasi sosial lebih maju daripada isi kontennya

Percakapan, kuota hadiah, poin, dan persistensi sudah tersedia. Preferensi hadiah/ulang tahun NPC, heart event, hadiah resep/surat, dan romansa perlu dinilai terpisah. Mekanisme birthday multiplier tidak membuktikan setiap NPC telah mempunyai tanggal dan konten ulang tahun.

### P2 — Kapasitas stamina belum mencapai target

Tiga Biji Daya memberi +30 dan bonus rumah total +40 di atas stamina awal 100: kapasitas yang didokumentasikan saat ini 170. Target 200 memerlukan sumber tambahan atau penyesuaian desain yang jelas; jangan menandainya selesai.

## 4. Bukti verifikasi dan batasnya

Enam kelompok tes terpilih pada log review 19 Oktober menghasilkan empat kelompok lulus dan dua kelompok gagal, dengan tiga assertion gagal:

| Kelompok | Hasil | Catatan |
|---|---|---|
| NPC Inspector | Lulus | failures=0 |
| NPC Paths | Gagal | “farm arrival follows clear route without teleport” |
| NPC Social | Lulus | failures=0 |
| Input Context | Lulus | failures=0 |
| Crafting Expansion | Gagal | Craft potion_health di alchemy table; record beehive/sawmill setelah load_save |
| HUD Feedback Visual | Lulus | failures=0 |

Bukti: [log NPC Inspector/Paths](../scratch/review-gdd-2026-10-19-tests.log) dan [log Social/Input/Crafting/HUD](../scratch/review-gdd-2026-10-19-more-tests.log). Akar masalah tiga assertion tersebut belum dipastikan; hasil ini tidak cukup untuk menyimpulkan seluruh pathfinding atau seluruh save rusak. Log ini juga mendahului sebagian penambahan Role/EXP dan bukan tes terhadap semua perubahan terbaru.

Runner `tools/verify_mvp.ps1` belum mencantumkan beberapa scene tes baru yang diperiksa: NPC Inspector, NPC Paths, Input Context, Crafting Expansion, HUD Feedback Visual, dan Role EXP. Keberadaan file tes tidak berarti tes itu dijalankan oleh runner utama.

Run luas sebelumnya berhenti pada Town Buildings. Belum ada bukti satu full suite terkini selesai tanpa kegagalan. Editor recovery yang berhasil tidak membuktikan startup editor normal sudah pulih. Laporan ini tidak mengklaim playtest manual lengkap, gamepad fisik, export, atau semua konten telah seimbang.

## 5. Cakupan yang masih perlu dikerjakan

| Kelompok | Batas saat ini / pekerjaan berikutnya |
|---|---|
| Sosial | Isi preferensi dan ulang tahun, heart event, surat/resep sosial, romansa/teman sekamar |
| Cuaca | Cerah/hujan tersedia; badai, salju, petir/baterai, prakiraan masih target. Kabut visual malam bukan implementasi cuaca harian kabut. |
| Farming/peternakan | Pohon buah permanen, kuda, pembiakan; crop bernama buah bukan bukti sistem orchard permanen |
| Produksi | Artisan Keg, Oil Maker, Fish Smoker; stabilisasi mesin tambahan dan persistensinya |
| Dunia | Pantai, Modern City, transportasi lanjutan; state input SWIM belum membuktikan loop berenang di peta |
| Role/EXP | Verifikasi integrasi baru, pacing dan ekonomi perk; sejumlah perk, festival token dan makan bersama masih belum tersedia |
| Ekonomi/kegiatan | Bazaar interaktif, festival, harga dinamis/pajak dan money sinks sesuai keputusan desain |

Inventaris data saat diperiksa: 39 crop, 65 fish, 137 resep cooking, 22 equipment cooking, dan 7 RoleData. Angka ini menunjukkan luas data, bukan persentase penyelesaian game.

## 6. Urutan kerja yang direkomendasikan

1. **Stabilitas akses dan persistensi.** Perbaiki target pintu HerbalHouse, fixture collider/load Town, lalu reproduksi dan selesaikan kegagalan rute Farm serta crafting/save mesin. Selesai bila tes terkait lulus dan transisi bisa dimainkan.
2. **Satu jalur verifikasi utama.** Daftarkan tes fitur baru termasuk Role/EXP; jalankan suite pada save terisolasi. Pisahkan hasil normal/recovery dan catat kegagalan tanpa menutupi tes yang belum berjalan.
3. **Sinkronisasi GDD.** Satukan matriks status, hitungan katalog, area, timing mesin, dan backlog. Pertahankan keputusan pemilik; tandai usulan perubahan balancing secara eksplisit.
4. **Tetapkan gerbang MVP.** Definisikan alur minimum: mulai game → farming/gathering → transaksi/produksi → tidur/settlement → upgrade → akses area → combat → save/reload. Uji solo dan co-op, termasuk progres tiap pemain dan transisi hari. Ini rekomendasi kriteria penerimaan, bukan perubahan scope otomatis.
5. **Isi konten yang menghubungkan sistem.** Lengkapi satu NPC end-to-end: jadwal, dialog, selera, ulang tahun, hadiah, satu event/reward. Validasi pacing Role/EXP bersama ekonomi dan progres alat sebelum ekspansi besar.
6. **Lanjutkan perluasan bertahap.** Pilih milestone produksi/cuaca/pantai, kemudian bazaar/festival/Modern City berdasarkan dependensi dan keputusan pemilik.

Tidak diberikan persentase selesai atau estimasi waktu karena batas MVP dan cakupan playtest belum ditetapkan secara terukur. Laporan ini tidak mengubah kode gameplay.
