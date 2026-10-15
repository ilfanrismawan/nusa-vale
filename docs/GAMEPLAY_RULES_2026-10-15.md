# Perubahan gameplay dan prioritas — 15 Oktober 2026

## Implementasi

- **Watering can:** sebelumnya biaya hanya diterapkan jika `FarmManager.water` mengubah status kering menjadi basah. Karena hujan otomatis membasahi tanah, menuang pada petak tersebut tampak gratis. Sekarang menuang pada petak cangkul yang valid memakai satu biaya stamina per aksi dan satu air per petak, meskipun sudah basah. Harga stamina tetap mengikuti ToolData, minimum satu. Tank kosong, stamina kurang, tanah invalid, dan completion event animasi berulang tidak menggandakan biaya.
- **Tanah kosong:** data petak tanpa crop dihapus pada pergantian hari. Soil/water/crop overlay untuk area termuat dibersihkan tanpa mengganti ground dasar. Area yang tidak termuat ikut dibersihkan datanya; tanaman hidup tetap dipertahankan meskipun tidak disiram. Pergantian musim terjadi sesudah evaluasi harian sehingga tanah tanaman yang baru layu dibersihkan hari berikutnya.
- **Upgrade alat:** objek memiliki `Resource Size` dan `Minimum Tool Tier` di Inspector. Kayu → kecil, Tembaga → normal, Besi → besar; batu emas minimal Emas. Pohon muda dan kayu lepas tetap menyediakan sumber kayu awal; batu kecil menyediakan batu awal, batu tembaga tetap dapat ditambang alat Kayu. Gating memeriksa jenis dan tier alat, bukan damage semata. Penolakan menampilkan kebutuhan tanpa biaya stamina.
- **Batu:** `small_rock.tscn` dan `large_rock.tscn` adalah turunan `rock.tscn` dengan ukuran visual/collider, health, loot dan syarat berbeda. Sebagian batu cleanup farm memakai varian tersebut. ID/posisi objek tidak diubah; objek yang sudah dibersihkan tetap tidak muncul pada save lama.
- **Konteks pemain:** damage alat membaca/mengurangi stamina pemain pelaku secara langsung, selaras dengan penyiraman.

## Prioritas urgent dari audit

Referensi `ReturnFarm` pada tes outdoor telah disesuaikan ke node aktual `ReturnWorld`. Regresi transisi Balai lulus kembali. Kode pintu gameplay tidak perlu diubah untuk masalah referensi tes ini.

Referensi lama kedua pada `request_feedback_regression.gd` juga sudah diperbaiki. Regresi tukang bangunan sempat gagal pada run luas lalu lulus saat diulang; tes kini memakai seed tetap, tas fixture berkapasitas cukup, pencarian seluruh ground farm, dan berhenti dengan pesan jelas jika konstruksi gagal. Penyebab run awal tidak dibuktikan secara tunggal; perbaikan mengurangi ketergantungan pada spawn/resource acak dan mencegah error berantai. `open_ranch_menu` kini menolak pemain/ID kandang yang tidak valid sebelum membentuk UI; jalur penolakan diuji.

Tidak menambahkan combat/dungeon dalam perubahan ini: prioritas konkret audit adalah memulihkan verifikasi dan menstabilkan aturan yang baru diubah. Combat adalah milestone besar berikutnya setelah validasi loop, bukan perbaikan bug mendesak yang bisa dinyatakan selesai dari data equipment saja.

## Bukti uji

- `scratch/gameplay-changes-focus-2026-10-15.log`: outdoor transitions, farm cleanup, tool progression, crop dan greenhouse semuanya lulus; runner berakhir `Selected MVP verification passed.`
- `scratch/farm-rules-2026-10-15.log`: tes baru stamina/air melalui event aksi, no double-charge, petak basah, stamina kurang, target invalid, delapan tipe objek/gate tier, reset tanah lintas area, tanaman tetap ada dan save/load. Hasil `FARM RULES REGRESSION COMPLETE: failures=0`.
- Tes baru terdaftar dalam `tools/verify_mvp.ps1`. Run luas `scratch/gameplay-changes-full-2026-10-15.log` lulus editor/parser, main menu, sepuluh area dan seluruh kelompok sampai placement, kemudian berhenti pada carpenter. Hasil gagal ini dipertahankan sebagai riwayat.
- `scratch/gameplay-changes-remaining-2026-10-15.log`: carpenter yang diperkuat, interaksi NPC dan service UI lulus; berhenti pada referensi lama Balai di tes feedback, yang kemudian diperbaiki.
- **Hasil akhir:** `scratch/gameplay-changes-final-2026-10-15.log` selesai `Selected MVP verification passed.` (exit 0). Seluruh 16 kelompok yang dipilih dari request feedback sampai save lulus, termasuk gameplay, economy, cooking, cleanup, performance UI, tool progression, focus, crop, character animations, NPC, Balai, Greenhouse, wings, Biji Daya dan save. Error I/O pada tes Balai/Biji Daya/save merupakan injeksi kegagalan yang diharapkan; audit selesai dengan `failures=0`.

Seluruh cakupan runner telah diperiksa melalui **gabungan run**, bukan satu full run baru tanpa interupsi setelah perubahan terakhir. Perubahan terakhir pada kode runtime adalah guard menu kandang, yang telah diperiksa pada regresi carpenter setelah perubahan. Tidak ada kode gameplay baru sesudah verifikasi tersebut.

Log merupakan artefak lokal di scratch. Tes headless tidak menggantikan playtest visual, keseimbangan upgrade dan gamepad fisik. Pembatas tier memperlambat pembersihan awal; kenyamanannya perlu dimainkan langsung.

Panduan editor: [EDITOR_GUIDE.md](EDITOR_GUIDE.md).

Kelanjutan prioritas progres awal setelah laporan ini: suplai logam Forest, akses
batu awal, manfaat/sisa saldo upgrade dan callback pickup lintas HUD diperbaiki.
Endapan besi kecil kini memerlukan Tembaga; batu besi besar tetap Besi. Hasil
verifikasi terbaru dan batas analisis ada di [EARLY_PROGRESSION_AUDIT_2026-10-15.md](EARLY_PROGRESSION_AUDIT_2026-10-15.md).
