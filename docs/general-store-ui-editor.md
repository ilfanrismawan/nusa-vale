# UI General Store

Buka `scenes/ui/shop_book.tscn` untuk mengubah tampilan toko di editor Godot. Scene ini dipakai oleh ShopUI, termasuk toko lain yang memakai controller yang sama.

- Ukuran desain 1280 × 720, otomatis menyesuaikan viewport, termasuk split-screen. Root ShopUI mengekspos `design_size` dan template scene.
- Kiri: Portrait, Keeper, Greeting dan DialoguePanel; potret dan salam mengikuti ShopData.
- Tengah: Filters enam kategori musim, Stock grid tiga kolom × dua baris, tombol halaman katalog, Inventory dan navigasi halaman tas.
- Kanan: DetailPanel krem, SelectedIcon, SelectedName, Description, Summary, Quantity dan Buy. Saldo bersama ada di bagian atas.
- Kartu katalog: `scenes/ui/shop_catalog_row.tscn` (6 barang per halaman), dengan ikon besar, nama dan harga/status.
- Slot jual: `scenes/ui/shop_inventory_slot.tscn` (12 slot per halaman, 6 kolom).
- Warna dan border kartu normal/hover/terpilih: `resources/ui/shop_card_normal.tres` dan `resources/ui/shop_card_selected.tres`. Keduanya juga bisa diganti lewat export `card_normal`/`card_selected` pada ShopUI.
- Tema utama mengikuti `cooking_theme.tres`; input jumlah mengikuti `startup_form_theme.tres`; backdrop memakai shader UI bersama.
- Description memakai BookText dengan navigasi teks panjang, tanpa scroll.

Daftar barang, nama penjaga, potret, dan salam berasal dari resource ShopData (`resources/shop/general_store.tres`). Script `scripts/ui/shop_ui.gd` mengikat data dan menangani transaksi serta navigasi, sedangkan komposisi visual ada di scene.

Klik barang untuk memilih, atur jumlah, lalu Beli. Shift+klik memilih jumlah 5. Klik slot tas menjual satu; Shift+klik menjual setumpuk. Navigasi atas/bawah gamepad otomatis membuka halaman barang yang dipilih.

Hover hanya menampilkan preview di panel kanan, tidak membeli dan tidak membuat tooltip panjang yang menutupi katalog. Keluar hover mengembalikan detail barang terpilih. Kategori tanpa stok menampilkan pesan kosong, dan pergantian kategori menghapus pilihan lama. Aturan harga/diskon, kapasitas tas, upgrade, tukar tambah dan unlock kendaraan tetap memakai backend yang sama.

Regresi khusus: `tests/shop_book_regression.tscn`, jalankan dengan direktori save audit terpisah.
