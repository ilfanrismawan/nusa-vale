# Kustomisasi tanpa scroll

Scene utama: `scenes/ui/character_creator_ui.tscn`. Tidak ada ScrollContainer atau dropdown dalam kustomisasi. Semua pemilihan memakai tab, kartu, atau tombol panah.

## Halaman

- **Profil**: nama, nama farm, dan tombol kalender ulang tahun tampil sekaligus.
- **Penampilan**: maksimum enam pilihan per halaman dalam dua kolom; panah bawah membuka pilihan berikutnya. Baris warna yang tidak tersedia tetap disembunyikan.
- **Teman Pet**: kartu bergambar, highlight pilihan, animasi preview, dan nama pet. Maksimum delapan kartu per halaman; gunakan panah jika katalog bertambah.
- Aksi animasi preview diganti dengan tombol panah; tidak perlu menggulir daftar animasi.
- Lemari langsung membuka Penampilan, tanpa mengubah profil atau pet.

Ukuran desain diskalakan mengikuti viewport. Semua posisi, ukuran, font, tombol dan panel tetap berupa node yang dapat diedit di Godot.

## Pet

Empat variasi anjing: putih, cokelat, karamel dan gelap. Empat variasi kucing: hitam, abu-abu, cokelat dan putih. Semua ikon berasal dari spritesheet pet project; nama variasi adalah label tampilan, bukan statistik ras.

Pilihan Tanpa pet tetap tersedia. Nama wajib diisi bila pet dipilih. ID `dog` dan `cat` lama dipertahankan agar save sebelumnya tetap cocok.

Edit/tambah resource di `resources/pets/`, lalu masukkan ke array **Pet Options** pada root CharacterCreatorUI. Resource mengekspos ID, nama, ikon dan deskripsi. Template kartu: `scenes/ui/starter_pet_card.tscn`. Ini tetap konfigurasi/profil pet, belum menambahkan AI pet di dunia.

Properti root `options_per_page` dan `pet_cards_per_page` dibatasi kapasitas layout agar tidak perlu scroll. Jika mengubah ukuran template atau jumlah kolom, sesuaikan node grid dan batas halaman bersamaan.

## Tes

`tests/character_setup_navigation_regression.tscn` memeriksa tidak adanya scroll/dropdown, akses seluruh pilihan melalui halaman, pemilihan kartu dan validasi, serta batas viewport kecil.

Jalankan dengan NUSA_SAVE_AUDIT=1 dan APPDATA terisolasi. NUSA_SETUP_SCREENSHOT=1 tanpa --headless menyimpan preview Profil, Penampilan dan Teman Pet di scratch.
