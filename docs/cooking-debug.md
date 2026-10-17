# Cheat playtest cooking

Jalankan game melalui Godot Editor/debug build. Interaksi dengan Dapur Warung atau peralatan memasak, lalu klik **Debug Cooking** pada menu dapur. Tombol ini tidak tampil dalam release build, dan helper mutasi juga menolak berjalan pada release build.

## Loop cepat

1. Pilih resep dari dropdown.
2. Bila perlu klik **Tas maksimal** untuk memberi ruang tanpa menghapus barang.
3. Klik **Buka resep ini**, atur jumlah kali memasak, lalu **Siapkan bahan**.
4. Klik **Alat wajib resep ini** atau **Semua alat**.
5. Klik **Masak uji**; ini memakai CookingManager normal dan tetap memeriksa bahan, alat, resep, dan kapasitas tas.
6. Atur target stamina (misalnya 50%), klik **Atur stamina**, lalu **Makan hasil**.
7. Tutup dapur dan bergerak/gunakan alat untuk mengamati timer, kecepatan, regenerasi, dan biaya stamina. Timer mengikuti pause gameplay, sehingga tidak berjalan saat menu dapur solo terbuka.

Gunakan **Hapus buff/debuff** sebelum membandingkan makanan. **Tambah hasil langsung** sengaja melewati memasak dan hanya untuk tes konsumsi; hasilnya mengikuti output_item dan output_count resep. Bahan olahan kategori MATERIAL tetap tidak bisa dimakan.

## Kasus gagal

- **Tanpa alat**: masak harus ditolak dan bahan tetap utuh.
- **Alat wajib resep ini**: mengaktifkan seluruh requirements resep terpilih untuk sesi menu.
- **Pulihkan alat awal**: mengembalikan daftar alat saat menu dibuka.
- Persiapan bahan mengisi kekurangan hingga jumlah batch yang dipilih, bukan terus menambah sebanyak itu setiap diklik.
- Jika tas tidak muat, persiapan bahan dan penambahan hasil dibatalkan seluruhnya; barang lama tidak dihapus.
- Pembatasan kategori stasiun tetap berlaku. Gunakan Dapur Warung untuk mencoba seluruh resep; panci/oven mandiri tetap mengikuti filter stasiunnya.

## Pengaturan Inspector

Edit `resources/cooking/debug/cooking_debug_config.tres` untuk enabled, katalog, jumlah batch awal, persentase stamina awal, dan jumlah uang cheat. Resep/peralatan diambil dari katalog resource; tidak ada daftar ID masakan dalam kode cheat.

Layout, nama tombol, dan batas SpinBox dapat diedit pada `scenes/ui/cooking_debug_panel.tscn`. Instance DebugPanel pada scene cooking_ui memiliki config_path yang bisa diarahkan ke preset .tres lain. Konfigurasi dimuat ketika panel siap agar tidak membentuk siklus referensi menu → katalog → scene peralatan → menu.

Alat cheat hanya mengubah available_equipment milik menu saat itu. Menutup dan membuka dapur lagi memakai fasilitas asli scene; resource installed_equipment tidak diubah. Item, resep yang dipelajari, level tas, stamina, dan uang adalah state game nyata dan dapat tersimpan bila game disimpan setelah menggunakan cheat. Cheat tidak memanggil save otomatis.

Dalam co-op, tas/resep/stamina/efek memakai pemain pemilik menu. Uang tetap bersama. Tidak perlu memasang autoload baru atau mengaktifkan DebugManager lama.
