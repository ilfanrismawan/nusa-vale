# Farm terbengkalai: objek sekali bersihkan

586 objek choppable/mineable awal farm dipindahkan dari instance di `farm.tscn`
ke katalog `resources/world/farm_cleanup_layout.tres`. Nama, jenis scene, posisi,
dan urutan objek dipertahankan. Sprite dekorasi dan instance dengan `script = null`
tetap berada di scene karena bukan objek yang dapat dibersihkan pemain.

`farm.gd` memanggil `farm_cleanup_spawner.gd` saat enter tree, sebelum physics dan
spawner area membaca isi farm. Spawner membuat hanya objek yang belum dibersihkan.
Node menjadi anak langsung YSort seperti sebelumnya; tidak ada wrapper tambahan.
Spawner tidak memproses frame/hari dan tidak menumbuhkan kembali objek cerita.

ID permanen berbentuk `farm:cleanup:<nama awal>`. Choppable menyimpan ID itu ke
`GameState.chopped_trees` atau `mined_rocks`; schema/version save tidak diubah.
Path save lama yang berakhir `/Farm/YSort/<nama>` dikenali untuk solo dan co-op,
sehingga farm lama tidak kembali penuh. Objek di forest dan spawner pohon harian
tetap memakai aturan sebelumnya. New Game menghapus progres cleanup.

Idle satu frame ditampilkan dengan sprite berhenti; animasi multi-frame,
chopping, timer damage, collision, dan drop item tetap memakai Choppable.

## Mengubah tata letak

Edit posisi/scene di katalog. Jangan mengganti ID objek yang sudah dirilis,
meskipun label nama atau scene-nya diganti, karena ID menghubungkan progres save.
Objek cleanup dibuat saat game berjalan; editor scene farm tidak menginstansiasinya.
Farm awal masih memiliki semua objek karena itu bagian dari cerita. Sistem ini
mengurangi node sesuai progres pemain, bukan melakukan chunk streaming.

## Verifikasi

`tests/farm_cleanup_regression.tscn`: 13 pemeriksaan lulus tanpa error, termasuk
ID unik, posisi/interaksi, partial damage, penghancuran, save/load, save lama solo
dan co-op, nol node untuk farm bersih, tidak respawn harian, dan reset New Game.

Probe lokal untuk populasi katalog di luar scene tree: farm awal 194,33 ms
(586 objek), farm bersih 22,88 ms (0 objek). Ini waktu populasi katalog, bukan
waktu load farm total atau FPS. Farm bersih menghindari 586 body beserta child
sprite/collision, setup musiman, dan pendaftaran physics mereka.

Tes baru dimasukkan ke runner `tools/verify_mvp.ps1`.
Fixture tes placement juga dibersihkan dan antrean operasi deferred diflush
sebelum shutdown, agar runner tidak gagal karena resource fixture masih tertahan.
Tes NPC diperbaiki untuk memakai fungsi global `is_instance_valid()`; pemanggilan
sebagai method NPC sebelumnya menghentikan tes dengan runtime error.

Pemeriksaan integrasi lulus: parser, main menu, delapan scene area, co-op 2–4
pemain, menu, crafting, bangunan, ayam, cuaca, placement, carpenter, gameplay,
cleanup, cache UI, tool, focus/sleep, tanaman, dan animasi karakter. Setelah
pembetulan tes NPC, bagian akhir dijalankan terpisah: NPC, Balai Nadi,
greenhouse, Balai wings, dan regresi save semuanya lulus. Error I/O pada tes
save/community adalah skenario kegagalan yang sengaja diuji. Diff perubahan
cleanup dan runner lolos `git diff --check`.
