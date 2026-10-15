# Eksplorasi malam

- Hari tetap dimulai 06.00. Tengah malam tidak menumbuhkan tanaman atau mengubah tanggal.
- 19.00–05.00: pemain boleh menjelajah. Kabut, vignette, ambience angin rendah dan siluet singkat setelah tengah malam membangun suasana horror. Efek per viewport, hanya di luar bangunan; HUD tetap terbaca.
- Peringatan muncul 19.00, 00.00, 04.00 dan 05.00. Jam HUD menjadi merah setelah tengah malam.
- 05.00 masih aman; tick 05.10 memicu pingsan. Waktu berhenti selama transisi tidur/pingsan, input dikunci saat pingsan.
- Pemain dipulangkan ke rumah, hari bertambah satu, bangun 08.00 dengan stamina 50%. Tidak ada penghapusan item. Co-op: pemain yang sudah berbaring pulih penuh; semua dipulangkan bersama.
- Tidur sebelum batas memulihkan stamina penuh dan memulai pagi 06.00.

Atmosfer ini belum menambahkan monster atau combat baru. Uji mekanik: tests/night_survival_regression.tscn, melalui tools/verify_mvp.ps1 dengan data save terisolasi.
