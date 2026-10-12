# Audit dan debugging — 11 Oktober 2026

Lingkup: pemeriksaan kode, parser/editor, startup scene, regresi save,
co-op 2–4 pemain, dan tes gameplay headless. Save pemain diisolasi melalui
APPDATA sementara oleh `tools/verify_mvp.ps1`.

## Perbaikan

- **Layer karakter hilang:** katalog menyembunyikan daftar warna, tetapi asset
  masih memakai `{color}`. Sanitizer sebelumnya menghasilkan path `.png` tanpa
  nama warna sehingga rambut dan pakaian dilewati. Pertahankan warna appearance
  dan pulihkan warna kosong/invalid dari nama asset yang tersedia; pengaturan
  pilihan warna di katalog tetap sama.
- **Duplikasi uang saat shipping:** shipping menghitung seluruh 36 slot, sedangkan
  penghapusan hanya menjangkau ukuran tas aktif. Barang tersimpan di slot terkunci
  bisa menghasilkan uang berulang. Hitung slot aktif dan bayar hanya jika
  penghapusan berhasil.
- **Transaksi negatif:** pembelian, penghapusan item, dan pengeluaran uang menerima
  angka negatif yang dapat menambah uang/barang. Tolak jumlah pembelian/penghapusan
  <= 0 dan pengeluaran uang < 0.
- **Pohon tidak tumbuh selama pemain pergi:** umur hanya diproses oleh sinyal hari
  pada scene yang sedang dimuat. Proses umur juga sebelum sinkronisasi saat area
  dimuat kembali.
- **Spawn pohon terhalang area lain di co-op:** pencarian group mencakup seluruh
  scene tree. Batasi pemeriksaan jarak ke World2D milik spawner.
- **Runner audit:** error script/assertion selalu menggagalkan pemeriksaan, termasuk
  tes save yang sengaja memicu error I/O. Tes co-op/gameplay wajib mencetak penanda
  selesai dengan failures=0.

## Verifikasi

`tests/gameplay_regression.tscn` ditambahkan ke runner MVP. Menguji pembelian
normal setelah penolakan transaksi invalid, penjualan ulang dan pembukaan slot
tas, resolusi layer karakter, pohon matang ketika kembali, serta spacing pohon
di world lokal dan world co-op lain.

Hasil: suite MVP lulus (`MVP verification passed.`), co-op dan save selesai
dengan `failures=0`. Tes gameplay terakhir lulus 16 pemeriksaan dengan
`failures=0`, tanpa error/warning. Pemeriksaan scene pada suite terakhir tidak
memunculkan warning layer karakter. Error I/O pada tes save merupakan skenario
kegagalan yang sengaja diuji, dan pemulihan backup lulus. `git diff --check`
juga lulus.

Tes headless tidak membuktikan kualitas visual, kenyamanan kontrol, atau perilaku
gamepad fisik. Checklist playtest di `MVP_CHECKLIST.md` masih perlu dijalankan.
