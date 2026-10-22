# Implementasi HerbalHouse, sosial dan Role

> Pembaruan status 22 Oktober 2026: pemilik mengonfirmasi playtest loop inti solo/co-op **sudah dilakukan dan lulus**. Rekomendasi playtest umum di dokumen historis ini tidak lagi menjadi prioritas aktif. Gunakan [PLAYTEST_STATUS.md](PLAYTEST_STATUS.md) dan GDD terkini; pengujian perubahan baru tetap berlaku.


Tanggal: 22 Oktober 2026. Acuan: GDD v3.28, save v25. Perubahan dikerjakan pada workspace aktif dengan perubahan lokal pengguna tetap dipertahankan.

## Hasil

| Bagian | Implementasi |
|---|---|
| HerbalHouse | Pintu menuju `scenes/world/interior/town/herbal_house.tscn`. Regresi memeriksa interior tersedia, masuk lewat interaksi, keluar otomatis dan kembali ke marker bangunan; solo dan dua pemain co-op memakai HerbalHouse sebagai jalur nyata. |
| Kunci hati | `friendships.<npc>.locked` menyimpan bahwa maksimum pernah tercapai. Setelah terkunci, poin tetap maksimum meski hadiah dibenci atau hari berlalu; konsumsi hadiah, kuota dan reaksi tetap berlaku. Default maksimum 10 hati; konfigurasi batas NPC tetap dihormati. |
| Rumah tangga | Lamaran butuh rumah tingkat 2; upacara tersedia esok hari. Selesaikan dialog upacara di rumah untuk meresmikan household; pembatalan tidak mengesahkan. NPC pulang pagi sebelum 09.00 dan sore mulai 18.00, tetap menjalankan jadwal siang. |
| Teman sekamar | Ubay/Eep pada 10 hati dan rumah tingkat 2 dapat diundang secara platonis. Esok hari ada dialog penyambutan. Satu household per karakter; satu NPC tidak menempati dua household. |
| Bantuan | Sekali per hari: sarapan Omelet di kotak surat, penyiraman crop Farm pada hari genap, pemberian pakan pada hari ganjil. Pakan/jerami diambil dari tas pemilik; tidak menciptakan pakan gratis. Greenhouse tidak disiram. Maksimal satu sarapan belum diambil agar surat tidak bertambah tanpa batas. |
| Hadiah persahabatan | Ambang hati mengantrekan resep dan bahan sekali per reward. Surat tiba esok hari, diklaim setelah semua halaman dibaca. Tas penuh atau batal tidak menghilangkan hadiah, tidak menandai surat selesai dan tidak membuka resep. Resep gratis dan milik karakter penerima. |
| Kurir Logistik | Economist Lv6 membayar Shipping Bin pada 12.00 dan 17.00. Slot harian dan kiriman yang telah dibayar tersimpan. Settlement pagi hanya membayar sisa, sementara laporan tetap mencakup seluruh pendapatan hari itu. |
| Forest Whisperer | Selain growth 2×, pohon yang ditebang diganti data bibit berjenis sama. Bibit muncul saat sinkronisasi spawner berikutnya (hari baru/kunjungan ulang), lalu tumbuh dengan aturan pohon yang ada. |
| Keamanan progres Role | Role tak dikenal tidak menerima EXP; EXP sangat besar dibatasi sebelum konversi integer. Cabang yang masih ditunda tetap tidak dapat diaktifkan. |

## Cara mencoba

1. Masuk ke HerbalHouse di Town lalu berjalan keluar: kembali ke depan HerbalHouse yang sama. Jalur ini juga diuji dengan dua pemain menuju dua interior berbeda.
2. Capai maksimum persahabatan. Hadiah negatif tetap memberi respons tidak suka tetapi tidak menurunkan hubungan. Simpan/muat: kunci tetap berlaku.
3. Tingkatkan rumah ke level 2, penuhi hati kandidat dan selesaikan dialog lamaran. Esok hari temui pasangan di rumah dan pilih **Mulai Upacara Pernikahan**. Selesaikan seluruh halaman. Untuk Ubay/Eep, gunakan **Undang sebagai Teman Sekamar**, lalu **Rayakan Tinggal Bersama** esok hari.
4. Kotak Surat aktif ada di Farm di kiri pintu rumah, posisi `(1088, 288)`. Interaksi membuka satu surat yang sudah tiba; selesaikan halaman terakhir untuk menerima isinya. Dekorasi `mailbox_decor` tetap dekorasi biasa. Surat cerita Wira juga tetap dapat dibaca melalui menu Wira.
5. Buka Economist Lv6 untuk kurir; titipkan barang sebelum 12.00/17.00. Forest Whisperer berada pada Forager Lv10 cabang A; tebang pohon dari spawner, kemudian kembali ke area atau tunggu hari berikutnya.

## Konfigurasi dan sumber

- Aturan household dan hadiah: `data/npc/social/household_rules.json`. Ambang/bingkisan awal merupakan balancing awal yang dapat diedit.
- Wira 4 hati: Omelet + 5 kayu. Ubay 4 hati: Pancakes + 2 gandum. Eep 4 hati: Salad + 2 wortel. Zarathia 6 hati: Sun Tea + 1 madu. Zarathustra 6 hati: Vegetable Mix + 2 kentang.
- Transaksi, jadwal rumah dan bantuan: `scripts/npc/npc_household.gd`; integrasi `npc_database.gd`, `npc_map_presenter.gd`, `scheduled_npc.gd`, `npc_home.gd` dan `resident_service_menu.gd`.
- Kotak surat: `scripts/world/social_mailbox.gd`, dipasang oleh `farm.gd`; penghuni dipasang oleh `interior_house.gd`.
- Kunci hati: `scripts/npc/npc_social_service.gd`. Data household ada dalam `PlayerData.npc_progress.household`; resep tetap di `learned_recipes`.
- Role: `scripts/system/player_skills.gd`, `skill_system.gd`, `shipping_manager.gd`, `tree_spawner.gd`, serta Resource role Economist/Forager.

## Persistensi dan migrasi

Save saat ini versi 25. `household` menyimpan NPC, mode spouse/roommate, hari upacara, status selesai dan hari bantuan terakhir. Surat menambahkan payload `recipes` dan `items`; klaim dilakukan secara atomik melalui tas sementara. Progres per karakter disimpan juga untuk anggota roster co-op yang tidak sedang dimainkan.

Save lama tanpa household tetap valid. Status married lama dapat mengantrekan upacara saat sistem sosial berjalan dan rumah memenuhi syarat. Hubungan lama yang masih maksimum memperoleh kunci saat pertama dibaca. Hubungan yang pernah maksimum tetapi sudah turun pada versi lama tidak dapat dipulihkan otomatis karena riwayatnya tidak tersimpan. Tidak ada perubahan paksa pada poin hubungan lama yang belum maksimum.

Shipping menyimpan `pickup_day`, `pickup_mask`, dan `collected_rows`; save lama memakai default kosong. Semua format tambahan divalidasi sebelum save dimuat, termasuk boolean kunci/household dan isi hadiah.

## Verifikasi

`python tools/validate_npc_data.py` lulus: 5 resident, 7 profil sosial, 1 cerita, 0 error dan 0 warning. Validator juga memeriksa syarat household, kandidat roommate, referensi resep dan bahan bingkisan.

Run gabungan 11 kelompok selesai dengan `Selected MVP verification passed` dan seluruh marker `failures=0`:

- Town Buildings: collider valid tanpa bergantung nama node, transisi HerbalHouse solo/co-op dan return spawn.
- Role EXP: EXP aktivitas, aktif setelah tidur, cabang permanen, token/buku, harga dan persistensi.
- Role Coverage: 7 role × ambang level 1–10, kedua cabang, perk ditunda, efek/stat, serialisasi, co-op aktif/offline, rod pribadi, tool damage/growth/replant, serta kurir tanpa pembayaran ganda.
- NPC Story: event, surat cerita, pembatalan dialog, romance dan persistensi.
- Household: upacara lewat UI rumah, lokasi penghuni dalam lantai rumah, pembatalan, roommate, sarapan, penyiraman/pakan, surat resep, full-bag rollback, isolasi karakter dan save disk.
- Skill Tree UI, House, Gathering, Fishing Season, NPC Social dan Save Audit.

Bukti: [run gabungan](../scratch/social-role-verification-2026-10-22.log), [run cakupan yang diperluas](../scratch/expanded-coverage-tests.log), serta [konfirmasi akhir sosial/UI](../scratch/social-final-confirmation.log). Konfirmasi terakhir mencakup undangan/pembatalan dan penyambutan roommate melalui UI, klaim/pembatalan kotak surat, serta migrasi kunci hati dari save lama. Klaim surat mengumumkan perubahan inventory hanya setelah seluruh status reward dikomit. Sebagian tes dijalankan ulang setelah perubahan, sehingga bukti mencakup ketiga log. Save pengujian diisolasi oleh runner. Save Audit memang memicu error I/O yang diharapkan untuk menguji rollback/backup.

Perintah utama:

```powershell
./tools/verify_mvp.ps1 -SkipEditor -AllowCertificateStoreWarning -Scenes tests/town_buildings_regression.tscn,tests/npc_story_regression.tscn,tests/npc_social_regression.tscn,tests/household_regression.tscn,tests/role_exp_regression.tscn,tests/role_coverage_regression.tscn,tests/skill_tree_ui_regression.tscn,tests/save_regression.tscn,tests/gathering_regression.tscn,tests/fishing_season_regression.tscn,tests/house_regression.tscn
```

Runner tetap ketat secara default. Opsi eksplisit `AllowCertificateStoreWarning` hanya menoleransi baris persis `ERROR: Failed to read the root certificate store.` dari lingkungan Windows; log asli tetap dicetak. Error lain, assertion, exit nonzero, marker tidak selesai dan scene pilihan yang tidak terdaftar tetap gagal. Editor headless berhasil keluar saat pengecekan awal, tetapi run gabungan memakai SkipEditor; tidak ada klaim full suite atau playtest visual/gamepad fisik.

## Batas implementasi

Upacara saat ini berupa dialog berhalaman di rumah, belum sinematik/artwork atau undangan tamu. Buket/pendant, gate hati 9–10 melalui buket, pemilihan rumah lewat `romance.spouse_home_map`, dan kehidupan keluarga lanjutan masih target. Jadwal perpindahan household bekerja lewat pergantian representasi antar-map, belum rute jalan fisik rumah pemain ke semua map.

Cakupan Role mengikuti keputusan GDD 13.4: aktifkan perk yang sistem pendukungnya tersedia. Sepuluh perk Resource tetap **Segera hadir**: Bintang Perak, Bintang Emas, Perpetual Orchard, Botanist, Kompas Alam, Demolition Expert, Stok Langka, Guild Magnate, Capitalist Investor, Commodity Tycoon. Kualitas crop/forage, orchard, peta penanda, bom, katalog eksklusif dan kontrak komoditas memerlukan pekerjaan sistem tersendiri. Overdrive/lift otomatis juga masih rancangan. Tes tidak membuktikan semua kombinasi efek probabilistik atau keseimbangan ekonomi jangka panjang.
