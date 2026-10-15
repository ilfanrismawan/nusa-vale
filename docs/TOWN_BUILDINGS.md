# Bangunan town sebagai child scene

Semua 14 bangunan lama sekarang memakai instance dari
`scenes/world/exterior/town/` di `Town/YSortEntities/Buildings`.
Posisi instance dan gambar dari town sebelumnya dipertahankan. Akses Balai
Nadi juga memakai scene `balai_access.tscn` sebagai anak langsung Town.

Komponen exterior tiap bangunan:

- `Sprite2D`: gambar dan atlas bangunan yang sudah dimiliki proyek.
- `CollisionShape2D`: footprint fisik, ikut pindah bersama instance.
- `Door/CollisionShape2D`: area masuk melalui klik kanan/Enter/A.
- `Door.target_scene`, `Door.spawn_position`: tujuan dan posisi interior.
- `Sign`: instance papan reusable, teks/warna/model dapat diubah.
- `ReturnSpawn`: marker posisi player ketika keluar kembali ke town.

Untuk memindahkan bangunan, geser root instance di town. Collider, pintu,
sign, dan marker ikut bergerak. Ubah `ReturnSpawn` agar tetap berada di
depan pintu dan di tanah yang dapat dilalui. Collider toko lama yang berdiri
terpisah di Boundaries dihapus; collision toko kini milik child scene.

Sekolah dan Universitas memakai interior yang sebelumnya sudah tersedia.
Warung, bengkel, toko, klinik dan delapan rumah memakai scene interior
masing-masing di `scenes/world/interior/town/`, yang mewarisi
`town_room.tscn`. Template menyediakan lantai, dinding, player, spawn,
batas kamera, dan keluar otomatis. Warung menyediakan panci cooking,
bengkel menyediakan Empu Bima, dan toko menyediakan counter belanja.
Layanan klinik/isi rumah masih dasar; tidak menambahkan sistem HP/quest baru.
Layanan outdoor yang sudah ada tetap tersedia.

Prefab `library.tscn` tersedia dengan papan Perpustakaan dan interior
bacaan dasar. Town sebelumnya tidak memiliki bangunan library, sehingga
prefab ini siap di-instance di lokasi yang dipilih pemilik proyek.

`town_building_door.gd` menyimpan posisi return berdasarkan index pemain,
sehingga pemain co-op yang masuk bangunan berbeda tidak saling menimpa
titik keluar. Interior masing-masing rumah mempunyai path berbeda untuk
memisahkan world co-op. Catatan return berlaku selama sesi; pemuatan save
tetap mengikuti aturan spawn save yang sudah ada.

Verifikasi: `tests/town_buildings_regression.tscn`, pemeriksaan pintu dan
toko, batas outdoor, service UI, serta cooking. Run final lulus, termasuk
dua pemain masuk rumah berbeda dan keluar bersamaan ke marker masing-masing.
Perbaikan `RoomDoor.travel` mengirim spawn langsung bersama permintaan co-op,
agar koordinat tidak tertimpa melalui variabel global yang ditunda.
Log di `scratch/town-buildings-verification.log` dan
`scratch/town-buildings-final.log`.
