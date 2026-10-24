# Papan nama bangunan yang dapat diedit

Buka `scenes/objects/building_sign.tscn`. Seluruh tampilan papan kini berupa node scene; script tidak memakai `_draw()`, `draw_rect()`, atau `draw_string()`.

## Node untuk diedit di Inspector

- `Board/Content/Row/Caption` (Label): Text, Theme Overrides → Fonts/Font, Font Sizes, Colors, outline, dan alignment. Untuk bold, gunakan FontVariation lokal pada Font.
- `Board/Content/Row/Icon` (TextureRect): Texture, Visible, Custom Minimum Size, dan Stretch Mode. Icon bersifat opsional.
- `Board/Frame` (Panel): Theme Overrides → Styles → Panel mengatur warna kayu, border, dan ketebalan tepi. Gunakan Make Unique untuk variasi instance tertentu.
- `Board/TopGrain` dan `Board/BottomGrain`: warna dan posisi garis serat/highlight.
- Empat node `*Rivet`: warna, posisi, dan ukuran baut.
- `Board/Posts`: dua tiang beserta highlight; `Board/Hanging`: dua rantai dan kait. Semua bagian menggunakan ColorRect, sehingga dapat dipilih dan diubah melalui editor.

## Ukuran dan posisi

Dengan **Auto Layout** aktif, ukuran minimum diatur lewat `Board → Layout → Custom Minimum Size`. Papan melebar mengikuti Caption, Icon, dan margin node Content. Padding berada pada `Content → Theme Overrides → Constants`; jarak ikon-teks pada `Row → Theme Overrides → Constants → Separation`.

Posisi pusat papan mengikuti Marker2D `WallMount` untuk WALL/HANGING, dan `PostMount` untuk POSTS. Ujung tiang mengikuti Marker2D `Ground`. Marker dapat dipindahkan langsung di editor.

Untuk mengatur Position/Size semua bagian secara manual, matikan **Auto Layout** pada root. Script kemudian tidak mengubah ukuran, posisi papan, atau panjang tiang. Mount masih menentukan apakah tiang/gantungan ditampilkan.

## Preset dan instance lama

Enam preset di `scenes/objects/signs/` dan papan yang sudah dipasang tetap mendukung properti root `caption`, `mount`, `minimum_width`, `minimum_height`, `font_size`, `icon`, `wood_color`, dan `text_color`.

Jika ingin mengedit node pada instance/preset tersebut, klik kanan instance → **Editable Children**, lalu matikan **Use Preset Overrides** pada root. Setelah itu Caption, font, warna, dan ikon dibaca dari node, sehingga properti preset lama tidak menimpanya saat dijalankan. Pilihan Mount tetap tersedia.

Untuk papan baru yang langsung memakai scene dasar tanpa override preset, perubahan pada node tetap dipertahankan saat masuk game. Tiap papan memiliki resource frame lokal sehingga perubahan warna melalui properti root tidak mengubah instance lain.

Papan tidak memiliki collision. Semua node Control memakai Mouse Filter Ignore agar pintu tetap dapat dipakai. Z Index root tetap 2 dan Texture Filter Nearest. Gunakan koordinat serta skala bulat untuk pixel art.

`scenes/objects/signs/sign_gallery.tscn` menampilkan enam preset. Pengujian `tests/building_sign_regression.tscn` mencakup preview node, ukuran otomatis/manual, tiga tipe mount, preset lama, ikon, dan pemisahan warna antar-instance. Jalankan dengan APPDATA terpisah bernama `nusa-save-audit-*`.
