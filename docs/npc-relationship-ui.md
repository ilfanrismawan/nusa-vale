# Menu warga dan hubungan

## Membuka menu

1. Buka tas dengan tombol **I** atau tombol tas yang sudah Anda atur.
2. Pilih tab **NPC** dengan ikon hati. Tab ini juga masuk urutan navigasi LB/RB pada gamepad.
3. Klik kartu warga pada dua kolom di masing-masing sisi buku untuk membuka detail NPC. Tombol **‹ Semua warga** atau Esc dari detail mengembalikan daftar. Gunakan pencarian nama/profesi atau filter hubungan.
4. Pilih tab Tas atau tab lain untuk mengganti isi buku. Esc atau tombol batal pemain menutup inventory langsung. Halaman NPC tetap menjadi node di dalam inventory.

Menu berisi seluruh profil NPC terjadwal dan profil sosial yang terdaftar. Penambahan profil baru otomatis masuk daftar; tidak perlu mengubah daftar nama dalam script UI.

## Informasi yang ditampilkan

- Portrait atau inisial jika portrait belum tersedia, nama dan profesi.
- Hati, poin persahabatan dan progres menuju batas hati NPC tersebut.
- Status kenalan/teman/sahabat, berpacaran, atau menikah; penanda apakah NPC bisa romance.
- Ulang tahun jika datanya tersedia. Tanggal NPC lama yang belum diisi ditampilkan sebagai belum tercatat.
- Status bicara dan hadiah hari ini, serta jumlah hadiah yang dihitung dalam batas mingguan.
- Lokasi sesuai jadwal sekarang, progres heart event, dan pemberitahuan surat yang sudah tiba.
- Lima kategori hadiah: Love, Like, Netral, Dislike, Hate. Setiap kartu menampilkan ikon dan nama item; pilih kartu untuk membaca deskripsinya.

Menu ini menampilkan informasi. Memberi hadiah dan menyatakan perasaan tetap dilakukan saat bertemu NPC. Item yang tidak masuk daftar selera dianggap netral. Informasi mengikuti karakter pemain pemilik tas, termasuk co-op.

## Mengedit di Godot

- Scene utama: `scenes/ui/npc_relationship_ui.tscn`.
- Script: `scripts/ui/npc_relationship_ui.gd`.
- Theme: `resources/ui/inventory_book_theme.tres`, sama dengan seluruh halaman buku.
- Root scene mengekspor **Design Size**, **Heart Icon**, dan **Map Names**. Ukuran desain default 420×224 dan diskalakan di tengah viewport pemain.
- Daftar warga memakai empat kolom total, dua pada tiap sisi buku, dengan delapan kartu per tampilan. Potret berada di kiri, status hubungan di kanan atas, nama dan sepuluh hati dalam dua baris di kanan, serta indikator hadiah mingguan dan percakapan di bawah. Penanda cerita baru mengikuti surat NPC yang tersedia. Daftar warga dan hadiah memakai pagination. Profil & Hubungan tampil di kiri dan Catatan Hadiah di kanan secara bersamaan. Tombol Catatan membuka jurnal di kiri; klik hadiah membuka detail item di kanan, dengan tombol kembali ke daftar; seluruh konten dapat diakses tanpa scroll.
- Instance halaman dan tab NPC berada di `scenes/ui/ui_inventory.tscn`, di bawah `Dimmer/BookRoot`.
- Template node daftar: `scenes/ui/relationship_resident.tscn`, `relationship_gift.tscn`, dan `relationship_heart.tscn`. Ubah ukuran, font, ikon, dan tampilan template melalui Inspector.
- Mode `embedded` menyesuaikan desain ke ruang halaman buku; tidak membuat CanvasLayer atau mengganti scene dunia.
- Profil lima NPC terjadwal berada di JSON masing-masing di `data/npc/`. Profil sosial NPC lain berada di `data/npc/social/gift_profiles.json`. Field `name`, `role`, `visual.portrait`, `romanceable`, `birthday` dan `gift_tastes` digunakan untuk tampilan; portrait bersifat opsional.

Tidak ada format save baru untuk menu ini. Data dibaca dari sistem relationship yang sudah tersimpan. Membuka jurnal tidak memberi bonus percakapan atau mengonsumsi item.

Pengujian: `tests/npc_relationship_ui_regression.tscn`, memakai folder APPDATA terpisah `nusa-save-audit-*`. Test memeriksa pemilihan warga, pencarian/filter, kartu hadiah, pemisahan data pemain, ukuran viewport dan pengelolaan pause saat kembali ke tas.

## Lembar vintage dan teks

Dua belas NPC dibagi menjadi dua tampilan buku; kapasitas delapan kartu per tampilan dalam dua baris, empat kartu pada setiap sisi. Berikutnya membalik lembar kanan melewati jilid dan menutupi kiri; Sebelumnya membalik arah. Tombol dinonaktifkan selama animasi dan pada batas lembar. Filter menyesuaikan jumlah lembar; refresh data mempertahankan lembar aktif. Klik kartu tetap membuka detail NPC.

Background: `assets/ui/vintage_crumpled_paper.png`, dibuat dengan built-in imagegen. Prompt final:

> Use case: stylized-concept. Asset type: game UI paper background texture. Create a flat front-facing rectangular full-bleed sheet of vintage cream parchment, landscape 3:2 aspect ratio. Gently crumpled paper with fine visible creases, subtle warm sepia aging and slightly darker worn edges, delicate fibers, restrained texture. Very pale ivory center to preserve excellent readability of dark UI text. No text, no symbols, no objects, no borders, no book, no perspective, no cast shadow, no holes. Fill the entire image with paper. Production game background asset.

Font menu: `readable_font.tres` memakai `menu_vector_font.tres`, SystemFont Segoe UI/Noto Sans/Arial dengan MSDF. Glyph tetap tajam saat UI diskalakan; label memakai sampling linear, dengan tampilan potret memakai aset piksel game yang ada. Tidak mengubah font dunia game.

Batas buku: konten kiri x=8–192 dan kanan x=228–412 pada desain 420×224; area jilid x=200–220 dikosongkan. Tekstur kertas dibagi menjadi dua bidang; pencarian berada di kiri, filter di kanan, navigasi di bawah kiri. Konten saat diam tetap di dalam halaman; hanya lembar yang sedang dibalik melintasi jilid.

## Grid per sisi dan ikon aktivitas

Setiap sisi buku memuat empat NPC dalam dua kolom dan dua baris. Kapasitas per tampilan adalah delapan kartu; sisa NPC dilanjutkan dengan Berikutnya. Kartu berukuran 88×72 pada desain 420×224. Container `Residents` memakai `relationship_card_grid.gd` untuk menyediakan celah jilid 36 unit: empat kolom total dengan jarak antarkartu 8 unit dan jarak baris 6 unit.

Ikon kado diikuti jumlah hadiah mingguan (`0/2`), ikon percakapan diikuti status bicara harian (`0/1` atau `1/1`). Arahkan pointer ke kartu untuk penjelasan status; klik untuk membuka detail NPC. Ikon SVG berada di `assets/ui/relationship_gift.svg` dan `assets/ui/relationship_talk.svg`.

Animasi Berikutnya memutar lembar kanan utuh melalui jilid x=210 ke kiri. Sebelumnya membalik arah. Salinan visual sementara menampilkan isi lembar dan teks sisi balik yang terbaca. Navigasi dan klik kartu dikunci selama animasi. Isi yang diam tetap berada di dalam bingkai masing-masing halaman.

## Detail NPC dan nama panjang

Dropdown pemilih bagian dihapus. `Design/DetailsLeft` berisi profil dan hubungan; `Design/Right/Details` berisi catatan hadiah. Kategori selera tetap dipilih melalui `GiftTabs`. Tombol Catatan/Profil mengganti isi kiri tanpa menutup hadiah. Tombol Daftar hadiah mengembalikan daftar dari detail item di kanan.

Nama kartu: `relationship_resident.tscn` → `ResidentRow/NameLabel` → Autowrap Mode = Word Smart. Area label menampung dua baris; script menyesuaikan ukuran font bila perlu supaya nama tidak menimpa indikator hati.

Teks tombol BackToResidents memakai koreksi lokal `resources/ui/pixel_button_font.tres`. Font dasar tetap m5x7; Extra Spacing Top = -4 dan Bottom = 4 mengimbangi metrik font sehingga bentuk huruf tampak berada di tengah tombol. Resource juga dipakai ActivityToggle dan GiftBack; tema font global tetap mengikuti pengaturan pemilik proyek.

## Font tombol independen dan hadiah piksel 16 px

BackToResidents, ActivityToggle, dan GiftBack memakai tiga subresource FontVariation terpisah dengan Local to Scene aktif. Mengubah Extra Spacing salah satunya tidak mengubah tombol lain. Untuk resource lain yang masih dibagikan di Inspector, buka menu resource → Make Unique sebelum mengedit; jangan mengubah FontFile dasar bila hanya ingin menyesuaikan satu tombol.

Tombol kartu `relationship_gift.tscn` memakai m5x7 ukuran 16 dan Nearest. GiftTabs, judul, petunjuk, tombol kembali, detail hadiah, serta pagination hadiah memakai 16 px dan Nearest. Daftar menampilkan dua hadiah per halaman agar font 16 px tetap muat. Seluruh hadiah tetap bisa dijangkau melalui pagination.

BookText dan BookPager memiliki export Text Font Size, Text Font, dan Nearest Textures untuk mengatur instance GiftInfo/GiftsPager tanpa mengubah halaman lain. BookText menghitung tinggi navigasi dan kapasitas teks sesuai ukuran font agar detail panjang tidak terpotong.
