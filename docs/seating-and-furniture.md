# Kursi dan furnitur

## Menambah kursi melalui editor

1. Instance `res://scenes/world/exterior/object/seat.tscn` di parent yang mengaktifkan Y Sort.
2. Pada **Seat Setup → Definition**, pilih `resources/furniture/wooden_chair.tres` atau `wooden_bench.tres`.
3. Pilih **Facing → Atas / Bawah / Kiri / Kanan**. Gambar, titik duduk, collision, dan sandaran mengikuti preset.
4. Samakan **Z Index efektif** kursi dengan Player. Parent `ysort` Hill sudah menyumbang Z=1; kursi di bawahnya tetap Z=0.

Kursi kayu memiliki empat arah. Bangku hanya mempunyai gambar atas/bawah; rotasi melewati arah yang tidak tersedia.

## Membuat desain baru

Duplicate definition `.tres`, lalu pilih **Make Unique** pada pose yang akan diedit. Setiap `SeatPose` menyimpan Facing, Region, Sprite Offset, Seat Position, Visual Offset, Collision Size/Position, dan Backrest Height. Backrest Height adalah jumlah baris piksel dari atas Region yang digambar di depan tubuh saat duduk. Jangan mengubah resource bersama jika hanya satu desain yang harus berubah.

Untuk sprite dengan tata letak khusus, Definition boleh dikosongkan dan penempatan marker/collider diatur manual. Facing tetap menentukan arah karakter.

Untuk menambah jenis kursi inventory tanpa mengubah script: buat `resources/item_data/<item_id>.tres` bertipe ItemData, isi Item ID, Icon, **Placeable = On**, **Seat Definition**, dan Placement Size. Tambahkan resep atau stok toko melalui katalog yang sesuai. Sistem placement dan save mengenali Seat Definition secara otomatis; tidak perlu menambahkan ID ke daftar script.

## Pemain memasang kursi

- Craft **Kursi Kayu** (8 kayu) atau **Bangku Kayu** (20 kayu), kelompok **Furnitur**.
- Pilih item di hotbar. Preview hijau berarti bisa dipasang; merah berarti terhalang, terlalu jauh, atau tanah tidak sesuai.
- **R** memutar preview, **klik kiri** memasang pada grid 16 px, **E / klik kanan** duduk atau berdiri.
- Setelah berhasil dipasang, preview ditutup meskipun stack masih tersisa. Pilih kembali slot hotbar untuk memasang kursi berikutnya. Arah kursi terpasang tetap sampai diambil dan dipasang ulang; WASD/mouse tidak mengubah pose saat duduk.
- **Shift + klik kanan** pada furnitur kosong mengambilnya kembali ke tas. Pasang lagi untuk memindah atau mengganti arahnya.
- Penempatan saat ini mengikuti aturan StructureManager: farm, tanah farmable kosong, maksimal jarak 36 px. Kursi memakai 1×1 petak; bangku 2×1.
- Posisi dan Facing masuk ke save `structures`. Kursi dekorasi bawaan Hill tetap menjadi bagian scene dan tidak bisa diambil pemain.

Regresi: jalankan `tests/furniture_regression.tscn` dengan APPDATA terisolasi bernama `nusa-save-audit-*` dan `NUSA_SAVE_AUDIT=1`, mengikuti `tools/verify_mvp.ps1`.
