# Nusa Vale: stabilisasi MVP

Target: satu loop yang utuh dari game baru, farming/fishing, penjualan,
upgrade, membuka forest, tidur, hingga memuat kembali save.

## Verifikasi otomatis

Prioritas progres awal 15 Oktober: sumber logam yang dapat pulih, endapan besi
kecil, margin batu awal, uji rute collision, dan keterangan manfaat/sisa uang
upgrade ditambahkan. Tes baru `early_progression_regression`,
`starter_routes_regression`, serta `forest_ore_coop_regression` terdaftar di
runner. Lihat [audit progres awal](EARLY_PROGRESSION_AUDIT_2026-10-15.md).

Pembaruan 15 Oktober: stamina penyiraman, reset tanah kosong dan gate tier
pohon/batu terpasang. Referensi dua tes Balai, guard menu kandang dan fixture
carpenter diperbaiki. Seluruh cakupan runner telah diperiksa melalui gabungan
run, dengan run terakhir feedback sampai save lulus. Lihat
[GAMEPLAY_RULES_2026-10-15.md](GAMEPLAY_RULES_2026-10-15.md) untuk log, riwayat
kegagalan, batas klaim dan kebutuhan playtest manual.

Jalankan dari PowerShell 7 di root proyek:

```powershell
./tools/verify_mvp.ps1 -GodotPath 'E:\Godot\Godot.exe'
```

Runner memakai APPDATA sementara agar save asli tidak dibaca/ditimpa.
Menguji editor/parser, main menu, sepuluh scene area, serta co-op 2–4 pemain
(spawn, tas terpisah, P2 masuk rumah dan kembali ke farm).
Tes gameplay memeriksa transaksi negatif/nol, penjualan slot tas aktif,
layer rambut/baju default, pertumbuhan pohon selama area tidak dikunjungi,
dan pemisahan pemeriksaan jarak spawn antar-world co-op.
Tes crop memeriksa 39 tanaman: sprite tiap tahap, pertumbuhan hingga matang,
serta pemulihan tile setelah save/load (lihat `CROP_VISUALS.md`).
Tes save dipertahankan di tests/save_regression.tscn. Error I/O yang sengaja
dipicu tes save hanya diterima jika audit selesai dengan failures=0.
Ini pemeriksaan runtime headless; kualitas visual dan kenyamanan kontrol
tetap membutuhkan playtest.

## Hasil pengujian runtime — 13 Oktober 2026

Pengujian dijalankan dengan Godot 4.7.2 headless, APPDATA sementara, dan
`NUSA_SAVE_AUDIT=1`. Ini playtest otomatis melalui scene runtime dan input
simulasi; bukan sesi bermain manual tujuh hari atau uji gamepad fisik.
Tanda selesai di bagian ini hanya berlaku untuk cakupan tes yang disebutkan.

- [x] Editor/parser, main menu, dan 10 scene area berhasil dimuat.
- [x] Co-op 2–4 pemain: spawn, inventory terpisah, dan perpindahan area.
- [x] Inventory/settings, crafting batch, storage, furnace, serta mesin pengolah: biaya, kapasitas, dan transaksi gagal aman.
- [x] Ayam dan ternak besar: pakan, perawatan, kesehatan, kualitas produk, merumput, upgrade, dan persistensi.
- [x] Interior Barn/Coop: masuk/keluar solo dan pemisahan world co-op berdasarkan bangunan.
- [x] Cuaca cerah/hujan: penyiraman ladang luar dan persistensi status.
- [x] Placement: preview mengikuti pointer, klik kiri konfirmasi, kanan/Esc cancel, biaya tepat, save/load, dan batas kamera. Run ini tidak mengeluarkan error resource tersisa saat tes placement ditutup.
- [x] Tukang bangunan: perpindahan town/farm, cancel, interior Coop, dan placement pada viewport pembeli co-op. Tes diperbarui mengikuti alur masuk interior sebelum membuka ringkasan kandang.
- [x] NPC: interaksi, dialog, batas panel, jadwal, waypoint, dan animasi.
- [x] UI layanan: pemilihan tanpa belanja otomatis, kuantitas/total, dana tidak cukup, dan upgrade/pengambilan alat milik pemain yang benar.
- [x] Gameplay/economy dan shipping: harga tepat, slot terkunci aman, pembayaran esok hari, save/load, dan tidak ada pembayaran ganda.
- [x] Tool progression: area, stamina, kapasitas air, refill, dan pengerjaan upgrade.
- [x] Focus/pause, posisi tidur, water HUD, serta pemeriksaan konfigurasi audio tier/footstep.
- [x] Crop: seluruh 39 tanaman tumbuh multi-hari dan pulih dengan visual yang benar setelah save/load.
- [x] Character animations: 188 animasi diperiksa, termasuk 36 aksi tambahan.
- [x] Pembersihan lahan awal dan pemeriksaan cache/UI yang ditunda.
- [x] Kontribusi Balai Nadi: transaksi, pemilik inventory, transisi, persistensi, dan rollback saat save gagal.
- [x] Audit save: `SAVE AUDIT COMPLETE: failures=0`; error I/O yang sengaja dipicu merupakan bagian tes.
- [x] Baseline balancing demo terpasang: harga/jumlah panen 39 crop, stamina alat, hari 12 menit, margin pakan/ternak, olahan, dan biaya upgrade. Audit ekonomi serta regresi terkait lulus; angka dan batas perhitungan ada di `ECONOMY_BALANCE.md`. Kenyamanan dan balancing co-op masih perlu playtest manual.
- [x] Feedback kontrol tambahan: keluar interior otomatis (solo/co-op), pickup mempertahankan alat, refill tanpa frame menyiram, pengiriman satu item per klik, serta akses Balai Nadi dari town. Tes fokus dan integrasi lulus; lihat `PLAYER_FEEDBACK_2026-10-13.md`.
- [x] Greenhouse: jalur town → Balai Nadi → restorasi → greenhouse sudah diselaraskan dan lulus pada full suite 14 Oktober 2026.
- [x] Balai wings: akses Balai Nadi di town, kontribusi/funds dan reward greenhouse lulus pada full suite 14 Oktober 2026.
- [x] Full suite sekali jalan lulus pada 14 Oktober 2026: `scratch/audit-verified-suite.log`, termasuk seluruh scene, regresi, dan save dengan error I/O yang sengaja dipicu.

## Audit dan kelanjutan GDD — 14 Oktober 2026

- [x] Perbaikan interaksi kasur, metadata/angkat hewan, resolusi tersimpan,
      mode fullscreen, dan timeout runner; lihat `AUDIT_2026-10-14.md`.
- [x] Animasi: semua atlas frame berasal dari komposisi karakter kustom;
      188 animasi diperiksa, termasuk pickup/drop/carry.
- [x] Angkat hewan: tidak mengubah tas/perawatan, refresh tetap mengikuti
      player, drop memulihkan collision, dan travel tidak menduplikasi hewan.
- [x] Placement: klik singkat konfirmasi, tahan kiri/middle drag untuk kamera,
      edge scrolling, batas map dan pembatalan aman. Tes ulang terakhir
      memastikan tombol UI tetap bisa diklik: `scratch/audit-placement-buttons.log`.
- [x] Cooking dasar sesuai GDD bagian 6: lima resep, buku resep per pemain,
      transaksi tas penuh aman, stamina/buff, HUD durasi dan save/load.
- [x] Town: 14 bangunan menjadi child scene instance, dengan collider, sign,
      pintu masuk, interior dan marker keluar. Balai memakai scene akses
      tersendiri; prefab library siap dipasang. Masuk/keluar solo dan dua
      pemain keluar bersamaan dari rumah berbeda lulus regresi, bersama
      tes co-op, pintu, batas outdoor, toko, UI layanan dan cooking.
      Lihat `TOWN_BUILDINGS.md` dan `scratch/town-buildings-final.log`.
- [x] Paket export resource berhasil dibuat (24.821.860 byte); inspeksi dari
      direktori terisolasi memastikan script cheat/tes/tools tidak masuk,
      serta lima data/icon masakan terbaca. Log: `scratch/audit-export-content-final.log`.
- [ ] Cooking lanjutan: dapur rumah melalui upgrade, HP/buff combat,
      buku resep melalui TV/hadiah sosial.
- [ ] Validasi baru secara manual: tampilan split daun/batang, animasi kustom,
      angkat hewan dan UI cooking; gamepad fisik dan build Web di browser.

Checkbox manual lama di bawah dipertahankan sebagai status yang sudah
ditandai pemilik proyek. Audit ini tidak mengulang atau membuktikan sesi
bermain manual maupun gamepad fisik tersebut.

Log bukti berada di `scratch/` (artefak lokal, tidak dijamin masuk Git):
`mvp-playtest-2026-10-13.log`, `mvp-playtest-remaining-2026-10-13.log`,
`mvp-playtest-carpenter-2026-10-13.log`, `mvp-playtest-save-2026-10-13.log`,
`mvp-playtest-save-only-2026-10-13.log`, dan `fixes-shipping_regression.log`.

## Checklist playtest manual menuju MVP

Bagian ini tetap terbuka sampai dimainkan langsung. Lulus tes otomatis
di atas tidak membuktikan kenyamanan, kualitas suara, atau keseluruhan alur UI.

- [x] New Game: konfirmasi overwrite, character creator, spawn di farm.
- [x] Semua arah/animasi rambut, baju, mata, dan tools terlihat benar.
- [x] Cangkul, tanam, siram, tidur, panen; verifikasi pertumbuhan multi-hari.
- [x] Pergantian musim memengaruhi bibit dan crop dengan konsisten.
- [x] Fishing: cast, bite, mini-game, catch/miss, inventory penuh.
- [x] Chop/mine/forage: stamina dan item drop benar, termasuk tas penuh.
- [x] Shop/shipping: jumlah, harga, uang dan barang tidak terduplikasi.
- [x] Furnace dan upgrade tool/tas: biaya terpakai sesuai hasil.
- [x] Ternak: pakan, elus/sikat, kebersihan, kesehatan, panen, dan merumput; uji rutinitas 4 hewan dalam 45–90 detik nyata.
- [x] Silo/auto-feeder dan mayones/keju/kain: cadangan berkurang tepat, kualitas bertahan, tas penuh aman.
- [x] Bridge: 100 wood + 50 stone, forest terbuka dan bertahan setelah load.
- [x] Save, keluar, Continue: uang, crop, resources, penampilan, unlock pulih.
- [x] Co-op dengan gamepad nyata: input/UI setiap pemain, tidur, pause,
      disconnect/reconnect, fishing, shop, dan save P2–P4.
- [x] Export release: F1–F11 dan cheat fishing tidak mengubah state.

## Catatan implementasi

FishingEffect.apply adalah marker yang sengaja kosong: ToolController
mengarahkan FishingEffect ke FishingState. Method kosong State adalah
hook untuk subclass; keberadaan pass saja bukan fitur yang belum selesai.
Scene school/school_v2 dan asset lama dipertahankan sampai penggunaan
dan hasil visualnya dikonfirmasi. Jangan menghapus asset berdasarkan
jumlah file saja.

Urutan berikutnya: playtest cooking dan kontrol terbaru; lanjutkan fondasi
HP/combat MVP serta fasilitas upgrade rumah untuk melengkapi cooking,
kemudian integrasi sosial/resep dan area lanjutan sesuai GDD.
