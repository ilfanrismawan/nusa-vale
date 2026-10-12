# Animasi karakter

Karakter sekarang memiliki 35 aksi animasi tambahan dari paket Farm RPG.
Semua dapat diperiksa melalui pilihan **Animasi** di layar Penampilan Karakter
(New Game atau lemari). Tombol Putar mengganti arah. Pratinjau mengulang aksi,
sedangkan aksi sekali putar tetap tidak berulang ketika dipakai dalam game.

Panen tangan memakai `pick_up`; kasur menampilkan `sleep` selama istirahat,
termasuk saat menunggu pemain lain dalam co-op.

Animasi tambahan: sword, archer, catch_insect, damage, death, carry_idle,
carry_walk, carry_run, pick_up, horse_idle/walk/run/lower/eat,
bicycle_idle/run, bear_idle/walk/run/attack/hit/death,
umbrella_idle/walk/run, sit, petting, climb, flute, mage,
swim_idle/out/submerged, swim, broomstick.

Animasi kendaraan, berenang, dan pertarungan tersedia pada SpriteFrames pemain;
kontrol dan mekanik gameplay terkait belum ditambahkan. Pemanggilan dari state
atau mekanik baru menggunakan `player.animation_controller.play(&"nama_aksi")`.

Resep ada di `resources/character/character_catalog.tres`. Builder membuat frame
dari layer dengan arah asli; animasi lama tetap mengikuti timing dan hit frame
Player.tscn. Layer tunggangan 32x48 memakai frame 64px agar tidak terpotong.

Pose tambahan dalam paket umumnya hanya menyediakan pakaian Farm. Jika varian
baju yang dipilih tidak tersedia, builder memakai mask Farm pada pose tersebut;
desain baju custom dan baggy jeans tetap diterapkan. Efek tenggelam memakai
satu layer air yang sama untuk semua warna kulit.

Verifikasi: `tools/verify_mvp.ps1`, termasuk
`tests/character_animation_regression.tscn` untuk frame, arah kiri, pose tidur,
kostum custom, filter pratinjau, dan pilihan animasi di layar kustomisasi.
