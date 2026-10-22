# Menu warga dan hubungan

## Membuka menu

1. Buka tas dengan tombol **I** atau tombol tas yang sudah Anda atur.
2. Pilih tab **NPC** dengan ikon hati. Tab ini juga masuk urutan navigasi LB/RB pada gamepad.
3. Pilih warga di sebelah kiri. Gunakan pencarian nama/profesi atau filter hubungan.
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
- Daftar warga dan hadiah memakai pagination. Profil, Aktivitas, Hadiah, dan Detail hadiah dipilih melalui menu bagian di halaman kanan; seluruh konten dapat diakses tanpa scroll.
- Instance halaman dan tab NPC berada di `scenes/ui/ui_inventory.tscn`, di bawah `Dimmer/BookRoot`.
- Template node daftar: `scenes/ui/relationship_resident.tscn`, `relationship_gift.tscn`, dan `relationship_heart.tscn`. Ubah ukuran, font, ikon, dan tampilan template melalui Inspector.
- Mode `embedded` menyesuaikan desain ke ruang halaman buku; tidak membuat CanvasLayer atau mengganti scene dunia.
- Profil lima NPC terjadwal berada di JSON masing-masing di `data/npc/`. Profil sosial NPC lain berada di `data/npc/social/gift_profiles.json`. Field `name`, `role`, `visual.portrait`, `romanceable`, `birthday` dan `gift_tastes` digunakan untuk tampilan; portrait bersifat opsional.

Tidak ada format save baru untuk menu ini. Data dibaca dari sistem relationship yang sudah tersimpan. Membuka jurnal tidak memberi bonus percakapan atau mengonsumsi item.

Pengujian: `tests/npc_relationship_ui_regression.tscn`, memakai folder APPDATA terpisah `nusa-save-audit-*`. Test memeriksa pemilihan warga, pencarian/filter, kartu hadiah, pemisahan data pemain, ukuran viewport dan pengelolaan pause saat kembali ke tas.
