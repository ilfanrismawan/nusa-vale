# Ringkasan penjualan

- `scenes/ui/shipping_report_ui.tscn`: panel daftar penjualan, tanggal, statistik, total, saldo dan tombol lanjut.
- `scenes/ui/shipping_report_row.tscn`: template ikon, nama barang, harga satuan, jumlah dan subtotal.
- Root scene mengekspos ukuran desain serta template baris. Gaya memakai cooking_theme.tres dan backdrop blur bersama.

Ringkasan menggantikan AcceptDialog lama. Data tetap berasal dari ShippingManager.last_report yang disimpan melalui SaveManager. Harga berasal dari snapshot saat barang dititipkan, bukan harga katalog terkini. Membuka atau menutup ringkasan tidak memberikan uang lagi.

Penutupan memakai Enter/Esc atau tombol Lanjutkan. Pause dikelola dengan reason terpisah sehingga penghapusan scene tidak meninggalkan permainan terkunci dan tidak membatalkan pause lain. Hari tanpa pengiriman memiliki pesan kosong.

Tes: `tests/shipping_report_ui_regression.tscn` dan `tests/shipping_regression.tscn`, dengan APPDATA terisolasi dan NUSA_SAVE_AUDIT=1. NUSA_SHIPPING_SCREENSHOT=1 pada tes UI tanpa --headless menyimpan preview di scratch.
