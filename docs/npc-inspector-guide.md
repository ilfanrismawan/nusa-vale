# Mengatur Wira dan Ubay lewat Godot Inspector

## Jadwal, kecepatan, dan tampilan

Buka resource melalui FileSystem:

- `resources/npc_data/characters/wira_resident.tres`
- `resources/npc_data/characters/ubay_resident.tres`

Inspector menyediakan Display Name, Role Title, Move Speed, Waypoint Radius,
Sprite Frames, Portrait, Default Schedule, dan Rainy Schedule.
Klik elemen jadwal untuk mengubah Hour, Minute, Map Id, Point Id, dan Activity.
Point Id harus cocok dengan nama Marker2D dalam `NPCPoints` map tujuan.
Urutan jadwal diurutkan otomatis berdasarkan jam. Rainy Schedule kosong
berarti memakai Default Schedule. Untuk mengganti jadwal, edit resource ini;
jadwal JSON tidak lagi menjadi sumber runtime.

Source Json tetap menyimpan dialog, ekspresi potret, kepribadian, dan data
sosial. Sprite Frames dan Portrait kosong berarti memakai gambar dari JSON.
Waypoint Radius sebaiknya tetap kecil (default 2 pixel), terutama di jalur sempit.

## Mengedit jalur Path2D pada map

Buka scene map (`hill.tscn`, `town.tscn`, `farm.tscn`, atau interior rumah),
lalu buka anak node `NPCPaths`. Editable Children sudah diaktifkan agar jalur
bisa diedit langsung dengan map sebagai backdrop. Tidak perlu menambahkan
scene map lain ke scene rute. Scene `scenes/npc/routes/*_paths.tscn` sendiri
hanya berisi jalur dan marker pintu, tanpa map/preview lain.

1. Pilih Path2D bernama `Wira_...` atau `Ubay_...` di bawah NPCPaths.
2. Gunakan toolbar Path2D bawaan Godot untuk memindahkan, menambah, atau
   menghapus titik Curve. Handle kurva bisa digunakan untuk membuat belokan.
3. Inspector `Npc Id` menentukan pemilik jalur. Jalur Wira dan Ubay memiliki
   Curve2D terpisah; mengubah kurva Ubay tidak mengubah kurva Wira.
4. Ruas Path2D milik NPC yang sama disambungkan otomatis jika ujungnya bertemu
   (toleransi root NPCPaths → Join Distance). Saat membuat cabang baru,
   duplikasi Path2D dan pilih **Make Unique** pada Curve sebelum mengeditnya.
5. Marker2D hanya dipakai untuk pintu/batas map. Isi Destination Maps dengan ID map yang dihubungkan,
   misalnya `town` atau `wira_home`.
6. Aktifkan Default Gateway pada satu marker sebagai pintu cadangan. Posisikan
   marker pintu di ujung Path2D yang sesuai.

Tidak ada gambar bantu dari script tool; garis yang diedit adalah gizmo Path2D
bawaan Godot. Tutup lalu buka ulang tab scene rute lama setelah script diperbarui.
Usahakan titik kurva melewati tanah yang dapat dipijak dan menghindari collision.
Marker aktivitas dalam NPCPoints boleh berada sedikit di sisi jalan agar NPC
yang sedang berhenti tidak menutup rute NPC lain.

## Hubungan jalur dengan jadwal setiap NPC

Presenter membaca jadwal aktif dari profil NPC (jam, map, Point Id, aktivitas).
Rute menuju marker aktivitas dihitung **hanya pada Path2D dengan Npc Id yang
cocok**. Town mempunyai ruas kurva Wira dan Ubay secara terpisah. Hill dan
rumah Wira berisi jalur Wira; Farm dan rumah Ubay berisi jalur Ubay.
Marker pintu antar-map boleh dipakai bersama karena menunjuk lokasi fisik
yang sama, tetapi kurva perjalanan masing-masing NPC tetap independen.

## Presenter dan daftar NPC

Pada setiap map, pilih NPCMapPresenter untuk mengatur Map Id, Actors Root,
Points Root, Paths Root, serta Actor Scene melalui Inspector.

Daftar NPC berada pada scene `scenes/npc/npc_database.tscn`, node NPCDatabase,
field Resident Profiles. Tambahkan resource profil ke array ini untuk
mendaftarkan NPC tanpa mengubah daftar ID dalam kode. Scene ini dipakai
sebagai autoload NPCDatabase pada Project Settings.

Simpan resource/scene lalu jalankan ulang game. Editor dapat mengubah data
dan jalur; perubahan tersebut tidak memerlukan pengeditan GDScript.
