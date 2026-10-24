# Migrasi dan kelengkapan NPC — 24 Oktober 2026

**Tindak lanjut tempat tinggal Eep:** Eep kini memiliki scene ranch dan rumah/toko yang dapat dimasuki; tidak lagi tidur offscreen di Town. Jadwal hujan berteduh di rumah dan toko pakan/peralatan tersedia. Status aktif Eep menggantikan batas offscreen pada laporan migrasi awal di bawah; lihat [EEP_RANCH.md](EEP_RANCH.md).

## Hasil pengerjaan bertahap

Pengerjaan ini mengikuti audit `NPC_DATA_AUDIT_2026-10-24.md`. Angka dan kekurangan sebelum migrasi pada audit tersebut merupakan riwayat. Status playtest inti solo/co-op tetap lulus menurut pemilik; pengujian di sini khusus perubahan NPC.

### Tahap 1 — Satu sumber data resident

**Selesai:** 13 NPC aktif terdaftar melalui `scenes/npc/npc_database.tscn`, memakai `ResidentProfile` dan JSON `data/npc/`:

Wira, Ubay, Eep, Zarathia, Zarathustra, Kirana, Bahar, Joko, Ratih, Rian, Damar, Bima, dan Baskoro.

- Tujuh profil hadiah lama dipindahkan ke JSON resident masing-masing; `data/npc/social/gift_profiles.json` menjadi `{}` sebagai kompatibilitas loader, bukan sumber profil kedua.
- Baskoro ditambahkan ke sistem sosial dan resident. Scene Universitas yang dipakai pintu Town, serta path scene Universitas lama, menggunakan presenter resident yang sama.
- API kompatibilitas `NPCDatabase.get_definition()` sekarang membentuk `NPCDefinition` dari profil terpusat; tidak lagi mengambil identitas Kirana dari resource terpisah yang tidak lengkap.
- ID sosial lama yang sudah terdaftar dipertahankan. Instance generik `empu_bima` yang menduplikasi Bima di Town dihapus dari peta; Bima aktif memakai ID sosial `bima`.
- Instance Wira/Tori lama dan NPC lokal lainnya dilepas dari Town. Aktor permainan dibuat oleh `NPCMapPresenter` dan menggunakan `ScheduledNPC`, sama dengan lima resident utama.
- Scene NPC dan script lama masih disimpan sebagai kompatibilitas/fixture tes. Scene tersebut bukan sumber spawn NPC aktif di Town atau Universitas. Untuk mengedit NPC aktif, gunakan JSON dan resource resident, bukan jadwal pada scene lama.

### Tahap 2 — Data dan konten dasar setara

**Selesai sebagai baseline konten:** seluruh 13 resident mempunyai identitas, umur, gender, profesi, kepribadian, biografi, ulang tahun, batas hati, lima kategori hadiah, respons hadiah, jadwal default/hujan, dialog aktivitas, dialog 2/4/6/8/10 hati, serta surat resep dan bahan.

| Ukuran konten | Sebelum | Sesudah |
|---|---:|---:|
| Resident terpusat | 5 | 13 |
| Profil sosial tambahan di luar resident | 7 | 0 |
| Resident dengan konfigurasi ulang tahun | 5 | 13 |
| Resident dengan jadwal hujan eksplisit | 4 | 13 |
| Heart event dialog | 4 | 65 |
| Pengirim reward resep/material | 5 | 13 |

Empat event lama, rangkaian kisah keluarga Wira, flag, surat Yayas, dan konfigurasi romansa si kembar dipertahankan. Ditambahkan 61 event dialog sehingga setiap resident memiliki lima milestone. Event baru menggunakan marker/jam aktivitas yang dapat dijangkau. Kelanjutan cerita keluarga tertentu tetap mensyaratkan flag cerita sebelumnya.

**Status penulisan:** umur, tanggal ulang tahun, kepribadian, biografi dan kisah baru yang sebelumnya kosong adalah baseline editorial implementasi, bukan konfirmasi kanon dari pemilik. Profil baru menandainya melalui `content_status`; konten lama yang sudah ada tidak ditafsirkan ulang sebagai keputusan baru. Event-event tersebut adalah percakapan dua atau beberapa halaman, bukan 65 adegan sinematik.

Ulang tahun baru: Kirana Semi 17; Bahar Gugur 6; Joko Panas 21; Ratih Dingin 9; Rian Semi 24; Damar Gugur 19; Bima Dingin 15; Baskoro Gugur 25. Semua dapat diubah melalui JSON.

### Tahap 3 — Peta, profesi dan layanan

**Selesai:**

- Kirana, Bahar, Joko, Ratih, Rian, dan Damar memakai kurva rute milik masing-masing di Town. Kurva tidak berbagi resource dengan Wira. Cabang tempat kerja Bahar/Joko/Ratih/Rian menghubungkan lokasi aktivitas lama ke jaringan jalan resident.
- Bima memakai penempatan tetap di bengkel; Baskoro tetap di area mengajar Universitas. Keduanya tetap memakai data jadwal dan menu resident yang sama; `anchored: true` menjelaskan bahwa mereka tidak berkeliling.
- Tidur resident baru menggunakan aktivitas offscreen di Town/Universitas, bukan interior rumah yang belum tersedia. Mereka kembali terlihat mengikuti jadwal pagi.
- Damar tetap membuka layanan konstruksi. Wira tetap membuka layanan kayu/renovasi yang sudah tersedia. Penamaan peran dan dialog menjelaskan pembagian kerja; backend menu konstruksi tetap sistem bersama.
- Rian menjadi perawat ternak pada data/dialog; pembelian hewan tetap melalui Eep.
- Bima membuka layanan upgrade alat dan geoda dari menu resident, memakai UI/transaksi lama.
- Zarathia kini membuka kedai teh/kue saat `tea_stall`; Joko membuka penjualan makanan saat `working`/`lunch`. Keduanya memakai `ShopUI` yang sudah tersedia.
- Stok/harga toko berada di `service.stock` pada JSON. Harga per toko memakai salinan ItemData, sehingga tidak mengubah harga item global. Toko ini tidak menjadi tempat jual ulang barang pemain.

Stok awal Zarathia: Green Tea 40 G, Chamomile Tea 100 G, Cake 350 G, Banana Bread 1.000 G. Joko menjual Vegetable Soup, Boiled Egg dan Rice Ball dengan baseline sekitar dua kali harga jual item, dibulatkan ke puluhan G. Ini harga awal, belum balancing ekonomi jangka panjang final.

### Tahap 4 — Aset dan konsistensi

**Selesai:** portrait khusus Zarathia, Zarathustra dan Ubay yang sudah tersedia sekarang direferensikan JSON aktif. Sprite geraknya belum seluruhnya khusus karakter.

- Portrait Bahar/Joko memakai lembar 4 kolom × 2 baris, bukan konfigurasi 5 × 3 milik resident lain. Pemetaan ekspresi diperbaiki.
- Animasi resident baru dipisahkan ke resource `*_resident_frame.tres`. Alias arah disediakan agar kontraknya sama dengan lima resident awal.
- Resource Kirana memakai atlas Manu yang sesuai layout sumbernya. Layout atlas Adrian/Baskoro diperbaiki menjadi satu baris horizontal sesuai gambar yang tersedia.
- Validator memeriksa kelengkapan metadata, milestone/dialog hati, jadwal default/hujan, batas region portrait, registrasi JSON/resource, penerima reward, ID resep aktual, layanan dan harga stok. Pemeriksaan resep memakai ID di dalam Resource, bukan menganggap nama file sama dengan ID (contoh `vegetablle_soup.tres` ber-ID `vegetable_soup`).

Saat tes integrasi ditemukan referensi UI lama ke Banner yang sudah dipindah, `%BtnSettings`/`%TipLabel` yang sudah tidak ada, serta CanvasModulate yang dapat dilepas pada area co-op. Referensi Banner diarahkan ke lokasi aset yang tersedia; node opsional dibaca dengan `get_node_or_null()`, sesuai guard yang sudah ada. Ini perbaikan terarah agar pengujian layanan NPC dapat berjalan pada workspace aktif.

## Verifikasi

- `python tools/validate_npc_data.py`: **13 residents, 0 social profiles, 1 story file, 0 error, 0 warning**.
- Delapan suite dalam run akhir `tools/verify_mvp.ps1` selesai dengan `failures=0` dan `Selected MVP verification passed`: `npc_story_regression`, `npc_centralization_regression`, `residents_regression`, `npc_paths_regression`, `npc_inspector_regression`, `npc_gifts_regression`, `household_regression`, dan `npc_relationship_ui_regression`.
- `carpenter_regression` juga selesai dengan `failures=0` setelah penyesuaian referensi node opsional; mencakup pembukaan konstruksi dan pembatalan transisi solo/co-op melalui Damar yang terpusat. Run gabungan pada saat itu kemudian berhenti pada region atlas Baskoro; atlas tersebut diperbaiki dan seluruh delapan suite di atas kemudian lulus.
- Run terarah terakhir `npc_centralization_regression` kembali lulus setelah menambahkan pemeriksaan Bima membawa geoda → UI geoda → UI upgrade → tutup tanpa tertinggal pause. Membuka layanan tidak memotong uang.
- Tes baru memeriksa 65 syarat event, pembatalan/penyelesaian dialog, region sprite/portrait, spawn tanpa duplikat, pergerakan fisik enam NPC baru pada jadwal normal/hujan, transaksi toko tanpa mengubah ItemData global, interaksi sosial Baskoro, klaim surat 13 warga tanpa duplikasi, independensi karakter dan save roundtrip.
- `git diff --check` lulus. Save pengujian diisolasi oleh runner ke direktori `nusa-save-audit-*`; tidak menggunakan save pemain.

Log lokal: `scratch/npc-migration-suite-final.log` (delapan suite akhir), `scratch/npc-centralization-final.log` (tambahan geoda), dan `scratch/npc-migration-suite.log` (run terdahulu yang memuat hasil konstruksi solo/co-op serta kegagalan atlas yang sudah diperbaiki).

Peringatan sertifikat Windows ditoleransi secara eksplisit melalui `-AllowCertificateStoreWarning`; error script/assertion/Godot lainnya tetap ditolak. Ada warning fallback `CharacterSheet mage` pada pengujian yang membuat pemain penuh; itu tidak diklaim sebagai aset karakter final. Tidak menjalankan full suite atau editor/parser terpisah, serta tidak mengklaim playtest visual/gamepad baru.

## Yang belum lengkap / belum dikerjakan

| Bagian | Status tersisa |
|---|---|
| Kanon konten baru | Peninjauan editorial atas umur, ulang tahun, biografi, kepribadian dan dialog baseline. Data sudah terisi; belum dikonfirmasi pemilik sebagai kanon final. |
| Artwork unik | Kirana/Damar/Bima/Baskoro masih memiliki portrait atau sprite pengganti. Si kembar masih memakai sprite gerak Tori/Manu, Ubay masih Josh. Portrait khusus ketiganya sudah terhubung. |
| Rumah pribadi | Resident baru masih memakai rumah offscreen. Interior rumah, kamar pribadi, dekorasi dan akses kamar berdasarkan hati belum dilengkapi untuk semua warga. Eep sudah mempunyai rumah/toko fisik dan jadwal tidur interior; lihat `docs/EEP_RANCH.md`. |
| Variasi jadwal | Profil baru dan Ubay sudah punya blok hujan eksplisit, tetapi baseline barunya masih mengikuti jadwal normal. Belum rutinitas berteduh khusus bagi semua warga, jadwal musim, baju musim dingin, hari libur dan festival. Bima/Baskoro belum jadwal berkeliling. |
| Kedalaman kisah | Lima milestone dialog per NPC sudah tersedia. Pilihan jawaban bercabang, staging kamera/gerakan, sinematik otomatis ketika masuk lokasi, ilustrasi khusus dan episode lanjutan belum dibuat. |
| Quest warga | Help Wanted Board, data permintaan, hadiah quest dan bonus hubungan dari penyelesaian permintaan belum tersedia. |
| Festival sosial | Jadwal festival, kegiatan bersama, bonus hubungan massal dan tradisi THR belum tersedia. |
| Romansa lanjutan | Bouquet, pendant, pembukaan hati 9–10 melalui bouquet, undangan tamu, sinematik pernikahan dan aktivitas keluarga lanjutan belum tersedia. Dating/lamaran/upacara dialog/household yang lama tetap ada. Kandidat romansa tetap dua NPC; penambahan kandidat tidak diasumsikan. |
| Rumah tangga | Bantuan harian/sarapan masih perilaku dasar sistem lama. Belum variasi karakter, AI pekerjaan bebas, anak atau perluasan keluarga. `spouse_home_map` belum memilih interior alternatif. |
| Layanan profesi lain | Ratih tetap memiliki dialog sosial; layanan medis yang ada tetap melalui sistem Klinik. Belum menu perawatan personal baru dari Ratih, toko pancing Bahar, atau layanan bunga Kirana. Layanan seperti ini memerlukan desain/implementasi tersendiri. |
| Balancing | Harga kedai, reward dan pacing 65 event merupakan baseline. Belum validasi ekonomi jangka panjang atau kualitas naratif lewat permainan nyata. |
| Verifikasi visual/manual | Tes headless tidak membuktikan kecocokan artwork, pengalaman percakapan, gamepad fisik atau kenyamanan seluruh rute secara visual. Milestone playtest umum pemilik tidak dibuka kembali. |

Prioritas berikutnya: tinjau harga/reward dan manfaat akses konten ini, lalu artwork/tempat tinggal dan variasi rutinitas. Sistem sosial lanjutan dikerjakan setelah baseline ini ditinjau. Semua pengaturan aktif dapat ditelusuri dari resource `*_resident.tres` ke `source_json` masing-masing.
