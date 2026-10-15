# Papan nama bangunan

Instance `scenes/objects/building_sign.tscn` sebagai anak bangunan/rumah,
lalu pindahkan ke fasad atau sisi pintu. Preview langsung terlihat di editor.
Papan tidak mempunyai collision dan tidak menyerap input, sehingga pintu
tetap dapat dipakai. `z_index` bawaan 2, relatif terhadap parent bangunan.

Pilihan Inspector:

- `caption`: nama fasilitas, misalnya Sekolah, Universitas, Pandai Besi,
  Perpustakaan, Warung Makan, Toko atau nama pemilik rumah.
- `mount`: WALL (plakat dinding), HANGING (papan gantung), POSTS (palang berkaki).
- `minimum_width`: lebar minimum; nama panjang otomatis memperlebar papan.
- `font_size`, `wood_color`, `text_color`: ukuran dan warna.
- `icon`: icon opsional. Gunakan texture/AtlasTexture satu icon agar tidak
  menampilkan seluruh spritesheet.

Untuk WALL/HANGING, origin node berada di pusat papan. Untuk POSTS, origin
berada di kaki palang; papan berada 20 px di atas origin.
Gunakan posisi dalam bilangan bulat dan skala 1/2/3 untuk pixel art tajam.
Font menggunakan `assets/fonts/m5x7.ttf` yang sudah dimiliki proyek.

Folder `scenes/objects/signs/` menyediakan enam preset siap dipasang.
`scenes/objects/signs/sign_gallery.tscn` menampilkan semua preset bersama.
