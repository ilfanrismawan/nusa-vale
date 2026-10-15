# Bangunan ladang, ayam, dan cuaca

**Pembaruan 13 Oktober 2026:** core loop diperluas menjadi ayam/bebek dan sapi/kambing/domba, termasuk merumput, jerami/silo, kebersihan, kesehatan, kualitas, upgrade kandang, dan mesin olahan. Panduan aktual lengkap: [LIVESTOCK_CORE_LOOP.md](LIVESTOCK_CORE_LOOP.md). Catatan fase ayam awal di bawah perlu dibaca bersama panduan tersebut.

## Placement melalui tukang bangunan

Temui **Pak Damar, Tukang Bangunan**, di kota dekat area pandai besi. Pilih Kandang Ayam atau Kandang Ternak untuk membuka peta ladang sebenarnya. Kamera bebas bergerak: WASD/stick, drag tombol tengah mouse, dan wheel untuk zoom. Preview mengikuti pointer, dengan pusat gambar bangunan sebagai patokan dan snap ke petak. Klik kiri langsung memasang di posisi pointer; Enter/A juga mengonfirmasi. Klik kanan/Esc/B membatalkan. Klik pada panel informasi tidak memasang bangunan. Semua pemain dan jam dijeda selama pemilihan lokasi.

Preview hijau berarti seluruh footprint serta akses pintu tersedia; merah menunjukkan alasan penolakan. Air, jalan, tebing, tanaman/lahan yang digarap, pohon, batu, objek, dan bangunan lain menghalangi konstruksi. Bangunan tidak dibatasi jarak dari karakter. Biaya dibayar hanya setelah konfirmasi yang valid, dari uang bersama dan bahan di tas pembeli. Pembatalan kembali ke posisi awal di kota tanpa biaya.

Kamera placement memakai batas kamera ladang yang dipotong ke area TileMap tergambar. Geser/drag kamera dikunci ke batas tersebut, dan zoom minimum disesuaikan dengan ukuran viewport agar tidak menampilkan ruang hitam di luar peta. Batas berlaku pada viewport pembeli dalam co-op dan diperbarui ketika ukuran viewport berubah.

| Bangunan | Footprint | Biaya tukang | Kapasitas |
| --- | --- | --- | --- |
| Kandang Ayam | 5 × 3 petak | 2.000 G, 100 kayu, 50 batu | 4 ayam |
| Kandang Ternak | 6 × 4 petak | 3.000 G, 200 kayu, 100 batu | 4 sapi/kambing/domba; upgrade hingga 12 |
| Silo Jerami | 3 × 2 petak | 1.200 G, 50 kayu, 100 batu | 240 jerami |

Bangunan juga bisa dibuat melalui crafting dengan bahan yang sama tanpa ongkos tukang. Gunakan item bangunan dari hotbar untuk membuka planner; konfirmasi mengonsumsi item, tanpa memotong biaya lagi. Bangunan kosong dapat dikemas lalu dipasang kembali. Kandang berisi ayam atau telur tidak dapat dikemas.

Posisi bangunan tersimpan. Dalam co-op hanya satu sesi placement aktif, UI tampil pada layar pembeli, dan bangunan menjadi milik ladang bersama. Pemain lain tidak ikut berpindah kota/ladang.

## Siklus ayam

Berinteraksi di depan pintu kandang untuk membuka pengelolaan. Beli ayam dewasa putih/cokelat seharga **800 G**, dengan nama opsional. Pakan Ayam tersedia di toko seharga **10 G**. Setiap ayam membutuhkan satu pakan per hari. Tombol individual dan “Beri pakan semua” mengambil pakan dari tas pemain yang sedang berinteraksi.

Ayam yang diberi makan menghasilkan satu telur pada pergantian hari. Hari yang tidak diberi makan tidak menghasilkan telur. Mengelus sekali sehari menambah kasih sayang. Bar menunjukkan jumlah ayam yang sudah makan hari ini; daftar menampilkan nama, status, dan kasih sayang. Telur dikumpulkan ke tas pemain, dapat dijual/dikirim seharga **50 G**. Jika tas penuh, telur tetap disimpan di kandang; pengambilan parsial aman.

Ayam, nama, varian, kasih sayang, pakan harian, telur, dan hari produksi terakhir ikut save/load. Produksi serta pengambilan tidak berulang karena reload atau interaksi pemain co-op lain. Pengelolaan menggunakan menu kandang dan interaksi langsung pada hewan di luar. Hewan berkeliaran dan merumput saat pintu dibuka; interior kandang tersedia melalui klik kanan pintu; pembelian hewan melalui Toko Ternak Rian di kota.

## Cuaca harian

Game baru dimulai cerah. Hari berikutnya memiliki peluang hujan 30%; cuaca ditentukan sekali per hari dari seed tersimpan. HUD menampilkan ikon dan status Cerah/Hujan. Hujan ditampilkan pada setiap viewport pemain yang berada di luar ruangan.

Hujan otomatis menyiram semua plot ladang luar, termasuk plot baru yang dicangkul/ditanami saat hujan. Greenhouse tetap memerlukan penyiraman. Pertumbuhan memakai status air hari sebelumnya; hujan pagi baru tidak mempercepat tanaman yang kemarin kering. Status cuaca, seed, dan tanah basah tersimpan serta menjadi satu state bersama bagi semua pemain co-op lokal.

## Verifikasi

`tools/verify_mvp.ps1` menjalankan parser, scene smoke, suite co-op 2–4 pemain, regresi lama, serta tes ayam, cuaca, placement, dan transisi tukang bangunan. Semua tes menggunakan APPDATA terisolasi agar save pemain tidak disentuh. Probe render memeriksa menu ayam, menu tukang, preview placement, dan hujan pada ladang sebenarnya.
