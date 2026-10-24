# Rumah dan toko Ranch Eep

Implementasi: 24 Oktober 2026. Area dibuat sebagai scene Godot yang dapat diedit, memakai aset proyek. Komposisi mengikuti referensi pemilik: kolam di barat daya, pepohonan di pinggir area, jalan tanah bercabang, rumah ranch di timur laut, padang berpagar dan kandang kecil di timur, serta air di tenggara.

## Scene dan koneksi

- Area luar: `scenes/world/eep_ranch.tscn`, ukuran 1.152 × 768.
- Rumah/toko: `scenes/world/interior/eep_home.tscn`, ukuran 640 × 448. Area depan untuk pelayanan; kamar dan meja makan di sisi timur.
- Ranch **utara → Farm**; Farm mempunyai `EnterEepRanch` pada jalur selatan. Posisi kembali ke Farm `(992, 928)`, sebelum collider tebing; trigger menuju ranch `(992, 976)`.
- Ranch **barat → Town**; Town mempunyai `RanchEntrance` di timur. Posisi kembali ke Town `(1184, 640)`.
- Pintu rumah ranch menuju interior, dan pintu interior kembali ke depan rumah. Akses bangunan memakai interaksi; batas luar berpindah otomatis.
- Jalur Farm–Town lama tetap tersedia. Koneksi ranch adalah tambahan.

Pohon cleanup Farm `MahoganyTree18` digeser dari `(990, 967)` ke `(944, 967)` agar tidak menutup koridor pintu ranch. ID persistensinya tetap sama, sehingga pohon yang sudah ditebang tidak muncul kembali.

Layer tanah, jalan dan air; collider kolam; pagar; bangunan; dekorasi; marker; Path2D; dan pintu tersimpan dalam scene. `scripts/world/eep_ranch.gd` hanya menangani batas kamera dan pengikatan state area, bukan menggambar peta saat runtime. `tools/build_eep_ranch.gd` adalah alat authoring awal; menjalankannya ulang menimpa dua scene ranch tersebut.

## Jadwal dan perdagangan Eep

Profil terpusat tetap `data/npc/eep.json`, dengan ID `eep` yang sama. Persahabatan, surat, hadiah dan event yang sudah selesai tetap memakai identitas lama. Lokasi lima event dipindahkan ke marker toko dalam rumah; flag/event ID tidak diganti.

| Waktu | Cerah | Hujan |
|---|---|---|
| 06.00 | Istirahat di rumah | Istirahat di rumah |
| 07.00 | Memeriksa pakan di padang ranch | Memeriksa pakan di dalam rumah |
| 09.00 | Melayani di toko | Melayani di toko |
| 12.00 | Makan siang di rumah | Makan siang di rumah |
| 13.00 | Melayani di toko | Melayani di toko |
| 17.00 | Memeriksa halaman/padang | Istirahat di rumah |
| 19.00 | Kembali ke rumah | Tetap di rumah |
| 22.00 | Tidur di kamar | Tidur di kamar |

Jam transaksi **09.00–12.00 dan 13.00–17.00; Rabu libur**. Penutupan toko tidak menghilangkan percakapan/hadiah. Jadwal household lama tetap mempunyai prioritas apabila Eep sudah diundang menjadi roommate pemain.

- **Beli Hewan Ternak:** tetap memakai layanan pembelian/penamaan/pengantaran ayam, bebek, sapi, kambing dan domba ke kandang pemain yang sesuai.
- **Beli Pakan / Peralatan:** memakai `resources/shop/eep_supplies.tres`, berisi pakan hewan, jerami, sikat, ember susu dan gunting wol. Harga berasal dari ItemData yang sudah tersedia; toko tidak menerima jual ulang barang.
- Menu persediaan hanya ditawarkan ketika layanan Eep buka, termasuk aturan libur Rabu.
- Eep tidak lagi muncul sebagai resident terjadwal Town. Marker dan kurva rute Eep lama di Town dibersihkan.

## Verifikasi

- `python tools/validate_npc_data.py`: **13 resident, 0 error, 0 warning**.
- `tests/eep_ranch_regression.tscn`: **0 kegagalan**. Memeriksa rute Eep di luar/dalam rumah, spawn dan koridor Farm/Town, perjalanan solo Farm → ranch → rumah → ranch → Town → ranch → Farm, serta perpindahan hanya pemain yang melintas pada co-op.
- `tests/eep_regression.tscn`: **0 kegagalan**. Memeriksa jadwal, jam buka/libur Rabu, layanan sosial, pembelian ternak sesuai kandang, pembayaran tunggal, penolakan transaksi tidak valid, lima stok persediaan, pembelian pakan dan event kepercayaan Eep.
- `git diff --check` untuk berkas perubahan ini lulus. Preview area luar dan interior telah diperiksa.

Log akhir: `scratch/eep-resumed-final-tests.log`. Runner memakai save terisolasi `nusa-save-audit-*`. Run sebelumnya menemukan `MahoganyTree18` menghalangi koridor Farm; pohon telah digeser dan pemeriksaan koridor ulang lulus. Upaya verifikasi terdahulu yang terhenti/timeout tidak dihitung sebagai kelulusan.

Peringatan root certificate store Windows ditoleransi secara eksplisit melalui `-AllowCertificateStoreWarning`; error script/assertion lain tetap menggagalkan runner. Warning fallback `CharacterSheet mage` berasal dari tampilan pemain yang sudah ada. Tidak menjalankan full suite, editor/parser terpisah atau playtest manual baru.

## Batas konten

Hewan di padang luar adalah sprite pajangan ranch, bukan ternak milik pemain dan bukan sumber produk gratis. Pembelian hewan tetap masuk ke kandang pemain melalui sistem yang sudah ada. Pohon dekoratif di area ini belum menjadi sumber tebang baru. Kolam mempunyai collider air dan efek permukaan; belum didaftarkan sebagai lokasi memancing baru.

Rumah Eep kini benar-benar tersedia; rumah pribadi NPC lain pada laporan migrasi sebelumnya tetap mengikuti status masing-masing. Ini pengujian terarah pada area dan perdagangan Eep, tidak membuka kembali milestone playtest umum yang sudah lulus menurut pemilik.

## Preview tata ruang

[Area luar](previews/eep_ranch.png) dan [interior rumah/toko](previews/eep_home.png) dirender dari salinan tata ruang scene tanpa autoload gameplay. Preview ini memeriksa komposisi visual; bukti transaksi dan perpindahan memakai tes runtime terpisah.
