# Eep — penjual hewan ternak

Eep berjualan di sisi barat Kota, dekat jalan menuju gerbang kebun. Pilih **Beli Hewan Ternak** saat berinteraksi pada jam buka. Ia menggunakan sistem ternak proyek: ayam, bebek, sapi, kambing dan domba. Harga, kandang yang sesuai, kapasitas, nama dan variasi hewan mengikuti sistem yang sudah ada. Hewan langsung tercatat di kandang pilihan setelah pembelian berhasil.

## Profil dan jadwal

- Nama: Eep, usia 27 tahun, penjual hewan ternak.
- Ulang tahun: 14 Musim Panas.
- Persahabatan: mulai 0 poin, maksimal 10 hati; tidak romanceable.
- Rumah/ranch berada di luar gerbang barat. Tidak ada interior baru dalam perubahan ini.

| Jam | Aktivitas / lokasi | Layanan |
| --- | --- | --- |
| 06:00 | Masih di ranch di luar gerbang barat | Tutup |
| 07:00 | Berjalan ke lapak, memeriksa pakan | Tutup |
| 09:00 | Berjualan di lapak | Buka |
| 12:00 | Makan siang; saat hujan tetap di lapak | Tutup |
| 13:00 | Kembali berjualan | Buka |
| 17:00 | Istirahat sore di dekat jalan kota | Tutup |
| 19:00 | Berjalan pulang melalui gerbang barat | Tutup |

Toko libur setiap **Rabu**. Pada hari libur Eep masih dapat diajak bicara dan diberi hadiah saat berada di Kota. Jam layanan mengikuti aktivitas jadwal; memindahkan jam aktivitas `selling` pada JSON juga memindahkan jam buka.

Eep baru disembunyikan setelah mencapai titik pulang. Saat pagi, aktor yang sama kembali terlihat di gerbang dan berjalan ke lapak. Pengaturan ini memakai `offscreen_activities`, bukan teleport atau penghapusan aktor di tengah jalan. Pada pemuatan awal Kota, ia masuk melalui gateway khusus Eep di gerbang barat.

## Data yang dapat diedit

- Semua data sosial, dialog, jadwal, hadiah dan event: `data/npc/eep.json`.
- Profil resource: `resources/npc_data/characters/eep_resident.tres`.
- Pendaftaran: **Resident Profiles** pada `scenes/npc/npc_database.tscn`.
- Scene NPC untuk preview/editor: `scenes/npc/EepNPC.tscn`. Runtime peta menggunakan aktor terjadwal dari profil, sehingga tidak perlu menambahkan instance Eep kedua ke Kota.
- SpriteFrames: `resources/npc_data/npc_animation/eep_frame.tres`.
- Sprite idle/walk dan portrait menggunakan tiga PNG dari `assets/farm_rpg/Character/NPC'S/Eep/`.
- Tampilan toko: `resources/ui/eep_livestock_shop_presentation.tres`, dirujuk oleh `service.presentation` di JSON. Mengeditnya tidak mengubah tampilan toko Rian.
- Titik tujuan: `NPCPoints/eep_stall`, `eep_lunch`, `eep_rest`, `eep_home` dalam `scenes/world/town.tscn`.
- Kurva: node **Eep_*** dalam `NPCPaths`, scene rute `scenes/npc/routes/town_paths.tscn`. Semua kurva merupakan Path2D milik Eep dengan Curve2D tersendiri.
- Gateway: `NPCPaths/eep_west_gate` dengan `NPC Id = eep` dan `Destination Maps = town`.

Jangan memasang instance Eep manual sekaligus mengaktifkan profil terjadwal: keduanya akan menghasilkan dua aktor.

## Hadiah dan cerita

| Kategori | Item ID |
| --- | --- |
| Love | complete_breakfast, carrot, cow_milk, chicken_egg |
| Like | apple, hay, animal_feed, green_tea |
| Neutral | bread, wood, stone, fiber |
| Dislike | clay, coal, fish_bone_fish |
| Hate | slime_gel, old_bone, shadow_ore |

Semua item sudah tersedia di proyek dan memiliki ikon. Item lain mengikuti aturan netral. Menu **Tas → NPC** otomatis menampilkan Eep, hati, ulang tahun, hadiah dan lokasi sesuai jadwal.

Heart event **eep_ranch_trust_1** tersedia mulai 4 hati di lapak Kota pukul 15:00–17:00, pada semua cuaca. Dekati Eep dan pilih Bicara. Menyelesaikan dialog membuka flag `eep_ranch_trust`, yang dipakai dialog persahabatan berikutnya. Membatalkan dialog tidak menyelesaikan event. Ini cerita persahabatan Eep yang terpisah dari cerita keluarga Wira.

## Pemeriksaan

Validator: `python tools/validate_npc_data.py`.

Pengujian khusus: `tests/eep_regression.tscn`. Jalankan menggunakan APPDATA audit terpisah (`nusa-save-audit-*`), bukan folder save pemain. Test meliputi sprite, jalur dan jadwal, layanan, pembelian dengan kandang yang sesuai, penolakan kandang kosong/penuh, hadiah, heart event, pulang dan kembali pagi, serta jadwal hujan.
