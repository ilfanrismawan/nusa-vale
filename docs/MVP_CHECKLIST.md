# Nusa Vale: stabilisasi MVP

Target: satu loop yang utuh dari game baru, farming/fishing, penjualan,
upgrade, membuka forest, tidur, hingga memuat kembali save.

## Verifikasi otomatis

Jalankan dari PowerShell 7 di root proyek:

```powershell
./tools/verify_mvp.ps1 -GodotPath 'E:\Godot\Godot.exe'
```

Runner memakai APPDATA sementara agar save asli tidak dibaca/ditimpa.
Menguji editor/parser, main menu, enam scene area, serta co-op 2–4 pemain
(spawn, tas terpisah, P2 masuk rumah dan kembali ke farm).
Tes save dipertahankan di tests/save_regression.tscn. Error I/O yang sengaja
dipicu tes save hanya diterima jika audit selesai dengan failures=0.
Ini pemeriksaan runtime headless; kualitas visual dan kenyamanan kontrol
tetap membutuhkan playtest.

## Checklist playtest menuju MVP

- [ ] New Game: konfirmasi overwrite, character creator, spawn di farm.
- [ ] Semua arah/animasi rambut, baju, mata, dan tools terlihat benar.
- [ ] Cangkul, tanam, siram, tidur, panen; verifikasi pertumbuhan multi-hari.
- [ ] Pergantian musim memengaruhi bibit dan crop dengan konsisten.
- [ ] Fishing: cast, bite, mini-game, catch/miss, inventory penuh.
- [ ] Chop/mine/forage: stamina dan item drop benar, termasuk tas penuh.
- [ ] Shop/shipping: jumlah, harga, uang dan barang tidak terduplikasi.
- [ ] Furnace dan upgrade tool/tas: biaya terpakai sesuai hasil.
- [ ] Bridge: 100 wood + 50 stone, forest terbuka dan bertahan setelah load.
- [ ] Save, keluar, Continue: uang, crop, resources, penampilan, unlock pulih.
- [ ] Co-op dengan gamepad nyata: input/UI setiap pemain, tidur, pause,
      disconnect/reconnect, fishing, shop, dan save P2–P4.
- [ ] Export release: F1–F11 dan cheat fishing tidak mengubah state.

## Catatan implementasi

FishingEffect.apply adalah marker yang sengaja kosong: ToolController
mengarahkan FishingEffect ke FishingState. Method kosong State adalah
hook untuk subclass; keberadaan pass saja bukan fitur yang belum selesai.
Scene school/school_v2 dan asset lama dipertahankan sampai penggunaan
dan hasil visualnya dikonfirmasi. Jangan menghapus asset berdasarkan
jumlah file saja.

Urutan berikutnya: playtest loop solo, perbaiki kegagalan yang ditemukan,
playtest gamepad/co-op, balancing ekonomi dan stamina, lalu export release.
