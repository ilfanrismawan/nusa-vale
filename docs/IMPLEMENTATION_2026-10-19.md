# Implementasi lanjutan — 19 Oktober 2026

## Perubahan

- Memeriksa gambar hasil komposisi senjata pada tes combat. Katalog mage sempat dipulihkan, tetapi editor terbuka menyimpan ulang katalog tanpa `extra_layers`; fallback runtime tetap menggambar tongkat/Fx. Tes kini membandingkan gambar bersenjata dengan gambar tubuh saja, sehingga menilai hasil aktual dan tidak bergantung pada metadata yang kosong.
- Menghindari jeda tampilan 30/40/20 detik pada tes combat/rumah/gathering saat headless; mode jendela tetap mempertahankan jeda untuk inspeksi.
- Runner MVP kini mencakup rumah, gathering, fishing musiman, portrait dan sosial NPC. Ditambahkan marker selesai untuk kelompok baru agar exit tanpa menyelesaikan tes tidak dianggap lulus. Pesan error marker combat diperbaiki.
- Tes rumah/gathering memeriksa kompatibilitas versi minimum v17/v18, bukan memaksa versi aktif selalu sama dengan versi fitur pertama diperkenalkan.
- Tes menu menunggu load startup sebelum membuat fixture, memilih resep lewat metadata ID (bukan indeks katalog), dan menerima beberapa tier amunisi. UI tetap diuji lewat klik tombol sebenarnya.
- Fixture tes ayam mengikuti konstruksi Wira, memeriksa biaya uang/bahan serta footprint sebenarnya. Tas fixture diperbesar karena 100 kayu memakai dua stack (99 + 1), sehingga bahan batu tidak hilang dari fixture akibat tas starter penuh.
- Fondasi sosial: sapaan, hadiah/preferensi, batas hari/minggu, bonus ulang tahun, decay dengan grace 14 hari, hati/poin di dialog dan persistensi P1–P4. Alat/gear/bangunan tidak bisa diberikan. B gamepad tetap cancel; Y memberi hadiah secara eksplisit.
- Save v19 menambah `friendships`, memvalidasi data sebelum load dan menerima save lama tanpa field tersebut. New Game mereset hubungan.
- GDD diselaraskan untuk area, cooking/HP, versi save dan maksimum stamina 170 dari tiga Biji Daya + rumah.
- Cache area co-op menormalisasi UID scene menjadi resource path sebelum membuat kunci World2D. Pintu yang tersimpan sebagai `uid://` tidak lagi membuat farm kedua ketika P2 kembali dari town ke farm P1. Suffix `#ranch=<uid>` dipertahankan untuk membedakan kandang.

## Batas cakupan sosial

Terhubung pada dialog VillageNPC untuk ID terdaftar, termasuk Wira/Ubay. NPC yang belum terdaftar tetap memakai dialog biasa. Preferensi/ulang tahun dapat diisi lewat JSON warga atau NPCDefinition; belum ada tanggal atau selera baru yang ditetapkan sebagai desain konten. Grace decay 14 hari dan satu hadiah/hari adalah pilihan implementasi sementara. Quest, heart events, surat/resep dan romansa tetap tahap berikutnya.

## Verifikasi

Tes combat setelah perbaikan katalog mencetak `COMBAT REGRESSION COMPLETE: failures=0`. Run pertama berhenti pada tes rumah yang masih mengharuskan save v17. Pemeriksaan versi tersebut telah diperbaiki.

Tes terpilih rumah, gathering, fishing musiman dan portrait lulus pada `scratch/social-verification-final.log`; run itu kemudian berhenti pada kesalahan tipe di tes sosial baru yang sudah diperbaiki. Hasil final combat dan sosial (termasuk simpan-baca file save terisolasi) lulus pada `scratch/combat-social-final.log`: kedua marker `failures=0`, runner exit 0.

Tes night survival lama masih mencoba menutup AcceptDialog, sementara laporan shipping sudah menjadi CanvasLayer. Helper kini menekan tombol Continue sebenarnya dan memastikan pause dilepas; `scratch/night-survival-fixed.log` mencatat `NIGHT SURVIVAL REGRESSION COMPLETE: failures=0` dan runner lulus.

Run penuh `scratch/mvp-2026-10-19-final.log` terhenti karena editor timeout 180 detik saat loading plugin window layout; log tidak menunjukkan parser error. Pemeriksaan editor **lulus dalam recovery mode** (`scratch/editor-recovery-2026-10-19.log`, exit 0), yang mematikan editor plugins/tool scripts. Ini tidak membuktikan mode editor normal sudah pulih.

Pemeriksaan runtime dilanjutkan terpisah di `scratch/mvp-2026-10-19-runtime.log`: main menu dan sepuluh scene, night survival, farm rules, early progression, starter routes, resource spawner, shared Forest ore dan co-op 2–4 lulus; run berhenti pada enam asumsi fixture/menu yang kedaluwarsa. Setelah diperbaiki, menu dan crafting lulus pada `scratch/mvp-2026-10-19-remaining.log`; tes sesudahnya dilanjutkan di run yang sama. Hasil ini gabungan run, bukan satu full run tanpa interupsi.

Runner menyediakan `-RecoveryEditor` untuk pemeriksaan editor tanpa plugin dan `-SkipEditor` untuk pemeriksaan runtime saja; output menyebutkan mode tersebut secara eksplisit.

Verifikasi lanjutan: `scratch/mvp-2026-10-19-remaining.log` lulus sampai furnitur; `scratch/mvp-2026-10-19-livestock-final.log` lulus dari ayam sampai doors/livestock shop. Run kedua mengungkap farm co-op terduplikasi karena alias UID/path. Setelah normalisasi, `scratch/mvp-2026-10-19-transitions-final.log` mencatat outdoor transition, weather dan forest fishing lulus. Uji ulang co-op 2–4 dan pemisahan interior kandang juga lulus (`scratch/coop-area-alias-regression.log`, exit 0). Tes transisi menunggu fade melepas input sebelum mencoba pintu berikutnya, tetapi tetap memeriksa perpindahan dan identitas world yang sebenarnya.

Workspace juga berubah dari sesi lain saat verifikasi (save sekarang v20, GDD versi 3.23); perubahan tersebut dipertahankan. v19 pada laporan ini adalah versi pengenalan field sosial, bukan klaim versi aktif tetap v19. Panduan konfigurasi dan batas sosial: `docs/NPC_SOCIAL.md`.

Biji Daya dilindungi dari transaksi hadiah agar hadiah unik tidak hilang permanen. Tes sosial mencakup perlindungan ini, routing Y/B gamepad melalui input UI, kuota harian/mingguan, ulang tahun, decay, save JSON dan save slot sebenarnya. Input gamepad di tes disimulasikan; bukan gamepad fisik.

Tidak ada klaim playtest visual/gamepad fisik atau validasi build Web. Working tree sudah mengandung banyak perubahan milik sesi sebelumnya; laporan ini hanya merinci perubahan sesi ini.
