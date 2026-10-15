# Perubahan kontrol dan suasana — 13 Oktober 2026

- Pintu keluar rumah, sekolah/universitas, greenhouse, Barn/Coop, dan Balai Nadi berjalan otomatis ketika pemain menyentuh trigger. Pintu masuk tetap memakai interaksi. Co-op hanya memindahkan pemain yang keluar.
- Batas outdoor Farm ↔ Town, Farm ↔ Forest, dan Town ↔ halaman Balai Nadi juga otomatis. Forest tetap memerlukan unlock jembatan. Hanya masuk ke interior bangunan yang memerlukan klik kanan.
- Hujan memakai lapisan biru abu-abu dengan opacity 25% di viewport pemain. Interior tetap bebas hujan; HUD dan menu berada di atas lapisan cuaca.
- Pickup ketika slot alat terpilih mempertahankan alat dan halaman hotbar. Animasi pickup tidak mengubah pemain menjadi pembawa item hasil pickup.
- Refill memakai animasi `refill_*` tersendiri dari pose persiapan kaleng: mencelup, mengangkat, lalu kembali. Frame yang menampilkan air menyiram tidak digunakan. Kapasitas dan stamina berubah sekali pada frame tengah.
- Klik kiri saat dekat dan menghadap shipping bin menitipkan satu item dari stack hotbar yang dipilih, dengan animasi lempar, ikon bergerak ke kotak, pantulan kotak, dan suara. Alat dan barang tanpa harga jual ditolak. Pembayaran tetap esok hari setelah tidur; klik kanan tetap membuka tas untuk pengiriman banyak item.
- Akses Balai Nadi berada di town pada `(800, 560)`, menuju scene halaman khusus. Jalan keluar halaman kembali ke town. Aset balai kayu/atap genteng/lentera dan tanaman halaman memberi suasana desa lama; aset rusak/pulih mengikuti restorasi yang sudah tersimpan.

Validasi: `request_feedback_regression`, `tool_progression_regression`, dan `ranch_interior_regression`. Bukti lokal ada di `scratch/fixes-request_feedback_regression.log` serta `scratch/request-feedback-tests.log`. Pengujian integrasi tambahan dicatat di `scratch/request-feedback-integration.log`.
