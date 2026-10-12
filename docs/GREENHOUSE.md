# Greenhouse — proyek Balai Nadi

Greenhouse yang sudah ada di farm (576, 56) dimulai dalam keadaan rusak dan terkunci.
Proyek **Pemulihan Greenhouse** di meja Balai Nadi membutuhkan **150 kayu, 75 batu,
5 batangan tembaga**. Kontribusi bisa dicicil, hanya jumlah yang masih diperlukan
yang dipotong, dan tiap kontribusi ikut disimpan dengan transaksi Balai Nadi.

## Alur bermain

1. Dari farm, dekati papan **Balai Nadi (E)** di sebelah greenhouse dan tekan E.
2. Dekati meja kontribusi dari bawah, menghadap atas, lalu tekan E.
3. Pilih **Pemulihan Greenhouse** dari pilihan proyek, lalu kontribusikan bahan.
4. Keluar dari Balai Nadi ke halaman; jalur **Kembali ke Farm (E)** ada di selatan.
5. Setelah proyek selesai, tampilan greenhouse di farm berubah menjadi bersih dan
   pintunya dapat dibuka dengan E.
6. Di dalam tersedia 32 petak. Gunakan cangkul, bibit, penyiram dan panen seperti
   di farm. Tanaman tetap memerlukan air untuk tumbuh, tetapi bisa ditanam lintas musim
   dan tidak layu saat musim berganti. Pintu selatan kembali ke farm.

Proyek greenhouse dan restorasi bangunan Balai Nadi bersifat independen; tidak ada
syarat urutan wajib. Sprite rusak/bagus menggunakan dua bagian asset greenhouse yang
sudah tersedia, dengan papan tambahan pada kondisi rusak. Data TileMap farm tidak diubah.

## Implementasi

* `resources/restoration/greenhouse_restoration.tres`: kebutuhan dan pesan penyelesaian.
* `scripts/world/greenhouse.gd`: akses pintu dan tampilan berdasarkan proyek selesai.
* `scenes/world/exterior/building/Greenhouse.tscn`: instance farm yang sudah ada,
  ditambah pintu, collider, papan Balai Nadi dan dekorasi rusak.
* `scripts/world/greenhouse_interior.gd` dan `scenes/world/interior/greenhouse.tscn`:
  ruangan, 32 petak, layer runtime dan integrasi FarmManager.
* BalaiNadiManager mendaftarkan proyek kedua; UI menampilkan kebutuhan dan pesan
  penyelesaian sesuai proyek. Resource memiliki `completion_message` untuk tiap proyek.
* FarmManager menandai setiap plot dengan `area`, memulihkan visual hanya untuk area
  aktif, dan melindungi tanaman greenhouse dari perubahan musim. Pertumbuhan semua
  plot tetap berlangsung saat hari berganti, termasuk saat area lain sedang aktif.
* Save versi **9** menyimpan `area` per plot dalam array `farm` yang sudah ada. Save lama
  tanpa area dianggap plot farm; save tanpa proyek greenhouse diinisialisasi belum selesai.
  Flag `greenhouse_unlocked` mengikuti proyek dan tidak memberikan reward ulang saat load.

Petak greenhouse memakai koordinat logis `(10000, 10000)` dengan offset layer ke posisi
ruangan. Ini memisahkan key Dictionary dari koordinat ladang utama tanpa mengganti sistem
inventory atau farming. Jangan gunakan rentang ini untuk map farm baru.

## Pengujian

`tests/greenhouse_regression.tscn` menguji pintu terkunci, alur farm → Balai Nadi,
pemilihan proyek, cicilan, save/load, penyelesaian sekali, perubahan sprite, pintu
greenhouse, 32 petak, tanam lintas musim, siram, pertumbuhan, panen, pemisahan area,
save crop, kembali ke farm, kompatibilitas save versi 8 dan reset New Game.
Jalankan melalui `tools/verify_mvp.ps1` agar APPDATA terisolasi dari save pemain.

Dieksekusi dengan Godot 4.7.2: 28 pemeriksaan greenhouse lulus. Parser, regresi Balai
Nadi, 39 jenis crop, struktur/furnace, co-op 2–4 pemain dan save juga lulus. UI tiga
bahan, kondisi rusak/pulih, dan interior dirender pada 854×480 dan diperiksa secara visual.
Regresi menu inventory memiliki dua kegagalan klik recipe yang sudah tercatat pada
implementasi sebelumnya; tidak diubah dalam fitur greenhouse ini.

Kebutuhan bahan dapat diubah langsung di resource proyek. Interior masih sederhana;
milestone berikutnya: mengganti dekorasi ruangan dengan tileset interior greenhouse.
