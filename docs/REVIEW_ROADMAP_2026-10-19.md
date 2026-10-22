# Review GDD dan kode — 19 Oktober 2026

> Pembaruan status 22 Oktober 2026: pemilik mengonfirmasi playtest loop inti solo/co-op **sudah dilakukan dan lulus**. Rekomendasi playtest umum di dokumen historis ini tidak lagi menjadi prioritas aktif. Gunakan [PLAYTEST_STATUS.md](PLAYTEST_STATUS.md) dan GDD terkini; pengujian perubahan baru tetap berlaku.


Catatan lanjutan: dokumen ini adalah snapshot review awal. Fondasi sosial dan perbaikan verifikasi kemudian dikerjakan; status serta bukti terbaru sesi ini ada di [IMPLEMENTATION_2026-10-19.md](IMPLEMENTATION_2026-10-19.md).

## Cakupan

Inspeksi working tree, GDD versi 3.16, dokumen progres lama, manager gameplay, data dan runner tes. Banyak perubahan lokal dan file baru sudah ada sebelum review. Tidak ada kode gameplay yang diubah. Inspeksi ini bukan playtest visual, gamepad, export, atau pembuktian seluruh fitur berfungsi.

## Temuan utama

1. **Dokumen progres 15 Oktober sudah tertinggal.** Combat, AI, boss, Gunung, gua 1–100, lift, upgrade rumah, fishing musiman, kolam musim dingin dan gathering sudah memiliki implementasi. Jangan memulai ulang fondasi combat berdasarkan roadmap lama.
2. **GDD sendiri belum konsisten.** Matriks awal masih menyebut Gunung/dungeon sebagai target, sementara bagian 8–9 mencatat implementasinya. Koreksi versi save di awal masih v15; `autoload/save_manager.gd:16` sudah v18. Bagian cooking masih menargetkan HP, padahal `FoodEffectData.hp_per_tick` sudah diproses `PlayerData.advance_food_effects`. Buff serang/bertahan dan keberuntungan fishing belum terlihat dalam skema efek makanan ini.
3. **Sosial masih berupa fondasi data.** `scripts/npc/npc_social_service.gd` hanya `extends Node`. `NPCDefinition` memiliki preferensi hadiah dan `romanceable`, tetapi ini belum membuktikan poin hati, transaksi hadiah, event atau pernikahan. Jadwal/dialog NPC sudah terpisah dan tersedia.
4. **Cakupan runner belum mengikuti fitur baru.** `tools/verify_mvp.ps1` belum memanggil `house_regression`, `gathering_regression`, `fishing_season_regression`, dan `portrait_expression_regression`, meskipun scene tes tersedia. Filter `-Scenes` hanya menyaring panggilan yang sudah terdaftar; tidak otomatis menjalankan scene tambahan.
5. **Batas stamina perlu diselaraskan.** Tiga Biji Daya memberi +30, rumah tingkat 2–3 memberi total +40; getter saat ini adalah 100 + jumlah Biji Daya dikonsumsi ×10 + bonus rumah. Jadi maksimum dari sumber sekarang dapat 170, bukan hanya 130. Target 200 perlu menetapkan apakah bonus rumah dihitung dalam batas tersebut.

## Backlog yang belum selesai

| Bidang | Kondisi kode/desain | Pekerjaan tersisa |
|---|---|---|
| Sosial NPC | Jadwal/dialog dan data preferensi tersedia; social service kosong | Poin per pemain, hati, bicara harian, hadiah, batas harian, decay, save; lalu event/resep/surat dan romansa |
| Cuaca | `DailyWeather.STATES` hanya sunny/rain | Prakiraan melalui UI/TV, fog, badai/petir, lightning rod/battery, snow/blizzard beserta dampaknya |
| Artisan | Mesin dasar tersedia | Keg, Oil Maker, Fish Smoker dan rantai bahan/resep/produknya; putuskan waktu fermentasi karena mesin lama memakai detik aktif |
| Rumah | Level/pesanan/bonus stamina/dapur tersedia | Visual luar per tingkat; cellar masih flag, perlu interior dan fungsi |
| Cooking | Resep, alat, efek stamina/gerak dan HP bertahap tersedia | Resep TV/sosial, buff combat/fishing dan konten resep lanjutan |
| Pantai | Data ikan/forage tersedia | Scene, akses/unlock, FishingSpot laut, ForageSpawner dan transisi/save/co-op |
| Pohon buah | Pohon kayu dari biji dan tapper tersedia | Loop pohon buah permanen lintas musim; menanam pohon kayu tidak sama dengan kebun buah |
| Ternak lanjutan | Lima spesies inti tersedia | Kuda, pembiakan dan satwa tambahan sesuai GDD |
| Combat/dungeon | Implementasi sudah luas | Verifikasi integrasi, balancing lantai/boss, keterbacaan telegraph, kontrol co-op; musik boss dan visual roll khusus masih perlu aset |
| Role/EXP | Belum ditemukan loop implementasi pada inspeksi | EXP per aktivitas/pemain, level, pilihan skill, UI dan persistensi |
| Bazaar/festival | Masih desain GDD | Jadwal, transaksi/minigame, hadiah, NPC dan co-op |
| Ekonomi dinamis | Ekonomi dasar sudah ada | Supply-demand, pajak/tagihan dan money sink; perlu data balancing sebelum diterapkan |
| Kendaraan/Modern City | Masih desain GDD | Mobilitas, syarat kemakmuran desa, rute transportasi dan konten kota |

Ketidakadaan implementasi di atas adalah hasil inspeksi, bukan hanya pencarian kata TODO. Hook `pass` pada kelas dasar atau callback tidak otomatis menandakan fitur rusak.

## Urutan pengerjaan yang disarankan

1. **Stabilisasi dan sinkronisasi status.** Tambahkan tes fitur baru ke runner; jalankan parser, suite lengkap dengan save terisolasi, lalu playtest New Game → upgrade → restorasi → dungeon → save/reload, solo dan co-op. Sinkronkan GDD/checklist/progres setelah hasilnya diketahui. Selesai bila cakupan tes jelas dan alur lintas sistem terbukti.
2. **Sosial tahap pertama.** Implementasikan hubungan per pemain, bicara sekali sehari, hadiah atomik, hati/UI dan save/load. Mulai dengan satu NPC untuk membuktikan alur; perluas setelah transaksi dan batas harian aman. Selesai bila hadiah tidak terduplikasi dan hubungan P1/P2 tetap terpisah setelah reload.
3. **Hubungkan sosial dengan tujuan bermain.** Hadiah resep, surat dan satu heart event; sambungkan ke cooking/restorasi. Romansa/pernikahan menjadi tahap setelah fondasinya stabil.
4. **Tutup produksi dan musim.** Keg/Oil Maker/Fish Smoker, cellar, prakiraan dan cuaca lanjutan. Tentukan aturan waktu mesin dan batas stamina sebelum menambah angka baru.
5. **Pantai dan konten farm.** Bangun scene pantai memakai data yang sudah tersedia; lanjut kebun buah dan ternak lanjutan.
6. **Progres jangka panjang.** Role/EXP lebih dahulu, lalu bazaar/festival dan ekonomi dinamis; kendaraan/Modern City setelah loop desa memiliki kriteria kemakmuran yang terukur.

Prioritas ini rekomendasi urutan, bukan penghapusan fitur GDD. Langkah implementasi langsung yang paling berguna: tutup celah runner dan hasil verifikasi, kemudian sosial NPC tahap pertama.

## Verifikasi runtime sesi ini

Temuan konkret dalam log combat: `COMBAT REGRESSION COMPLETE: failures=1`, assertion **`attack animations draw the weapon`** gagal pada `tests/combat_regression.gd:128`. Prioritas pertama adalah memeriksa komposisi layer senjata dan ekspektasi tes; penyebab belum dipastikan. Ada pula warning CharacterSheet mage tanpa extra_layers dan penggunaan cadangan. Jadi timeout bukan satu-satunya masalah: assertion sudah gagal sebelum proses dihentikan.

Percobaan tes terpilih: combat, deep cave, weather dan cooking melalui runner dengan save terisolasi. **Run berhenti pada combat karena timeout 120 detik (exit 1).** Deep cave, weather dan cooking tidak dijalankan pada percobaan ini. Ini blocker verifikasi yang perlu ditelusuri, belum membuktikan akar masalah gameplay. Tidak ada klaim full suite lulus. Log: `scratch/review-2026-10-19.log` dan `scratch/verify-timeout-Combat_HP__weapons__enemies_and_defeat.log`.
