# Perbaikan gameplay dan feedback — 13 Oktober 2026

- Pose tidur mengikuti pusat bantal yang ditentukan pada Bed; posisi, rotasi,
  dan urutan gambar sprite dipulihkan ketika bangun, termasuk pembatalan
  tidur co-op. Posisi tubuh fisik pemain tidak dipindahkan ke collision kasur.
- Penyiram mengonsumsi stamina sekali untuk aksi siram yang berhasil. Pengisian
  air kini melewati animasi aksi dan mengonsumsi stamina sekali saat hit frame;
  tangki penuh, kosong saat menyiram, atau tanah sudah basah tidak dikenai biaya.
- Meter air bergambar muncul saat penyiram dipilih: bar, sisa/maksimum,
  warna air rendah, dan petunjuk isi ulang saat kosong, per pemain.
- PauseManager memisahkan pause kehilangan fokus dari pause menu/transisi.
  Alt-tab atau kehilangan fokus menjeda gameplay dan jam, termasuk co-op;
  kembali ke jendela mempertahankan pause menu yang masih terbuka.
- Upgrade membutuhkan dua pergantian hari, mengeluarkan alat dari tas,
  dan memerlukan pengambilan dari Empu Bima. Pesanan solo/co-op tersimpan
  pada save versi 10; tas penuh tidak menghilangkan alat dan klaim ganda ditolak.
- Sepuluh tier memiliki sampel aksen material berbeda. Alat baru memiliki
  bunyi hadiah saat diambil. Langkah jalan/lari mengikuti perpindahan nyata
  dengan enam profil: rumput, tanah, kayu, batu, karpet, dan salju.

Audio baru: Kenney Impact Sounds 1.0, CC0. Lisensi asli dan sumber tersimpan
di `assets/audio/sfx/kenney_impact/`. Permukaan dapat ditentukan dengan custom
data TileSet `footstep_surface`; fallback membaca overlay lantai dan warna tile.

Pengujian khusus: `tests/tool_progression_regression.tscn` dan
`tests/feedback_focus_regression.tscn`, dengan APPDATA uji terisolasi.
Runner MVP memasukkan keduanya. `-TimeoutSeconds` mengatur batas per proses
pada komputer yang sedang menjalankan editor atau impor aset.

## Hasil verifikasi

`tools/verify_mvp.ps1 -TimeoutSeconds 300` selesai dengan exit 0 dan
`MVP verification passed.`. Tes tool progression, feedback/focus, UI/cache,
co-op 2–4 pemain, greenhouse dan save selesai tanpa kegagalan assertion.
Data pengujian menggunakan APPDATA sementara, terpisah dari save pengguna.
Error I/O yang sengaja dipicu tes save diterima hanya setelah failures=0.

Render Compatibility/ANGLE diperiksa untuk posisi kepala di bantal, meter air
di dalam viewport dan status pesanan bengkel. Tes meter juga memeriksa batas
viewport agar panel tidak kembali berada di luar layar. Log verifikasi lokal:
`scratch/gameplay-fixes-verification.log`.
