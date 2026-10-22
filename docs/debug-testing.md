# Debug pengujian

Jalankan game melalui editor Godot, tekan **F1**. Kategori Pengujian Tambahan menyediakan pemulihan HP/stamina/air/efek makanan, jam berhenti/berjalan, set jam 06/12/18/00/04, serta pemberian item berdasarkan ID dan jumlah (1–999). Item yang tidak muat dilaporkan; target adalah `GameState.current` (pemain aktif).

Aksi baru berada di `development/testing_actions.gd`, UI di `autoload/debug_manager.gd`. Tidak ada perubahan fungsi gameplay untuk menerapkan cheat ini. Perubahan uang, inventory, tanaman, dan waktu dari cheat dapat tersimpan oleh save normal; gunakan slot pengujian.

`DebugBootstrap` hanya memuat manager saat `editor` dan debug build. Export debug maupun release tidak memuatnya. Semua preset export mengecualikan folder development, manager cheat, panel/action/config debug memasak, dan data konfigurasinya. Cooking UI memuat panel debug secara dinamis hanya dalam editor sehingga export tidak memiliki dependency statis pada file yang dikecualikan.

Jika menambahkan preset baru, salin exclude_filter dari preset yang ada. Verifikasi: Godot --headless --path . tests/debug_tools_regression.tscn. Untuk audit distribusi, export memakai preset dan periksa isi PCK agar file dalam exclude_filter tidak ada.


## EXP, skill, role dan perk

F1 → SKILL / ROLE / EXP / PERKS. Pilih pemain P1/P2/dst dan role. Jumlah EXP dapat diatur, level 0–10 bisa dipasang sebagai EXP menunggu tidur atau langsung aktif. Set level mengubah total EXP ke ambang level tersebut (dapat menurunkan progres). Reset role hanya menghapus progres role pilihan; role lain tetap ada.

Tombol perk Lv5/Lv10 dapat mengganti A/B berulang kali atau menghapus pilihan untuk menguji pemilihan ulang. Level harus sudah aktif; perk Segera Hadir tetap mengikuti pembatasan game. Daftar status menampilkan EXP, level aktif/level EXP, token, nama cabang, dan perk aktif. Tambah 10 token dan tukar satu token menggunakan mekanisme game biasa.

Implementasi terpisah: `development/skill_debug_actions.gd` dan `development/skill_debug_panel.gd`. Keduanya tercakup pengecualian export `development/*`. Progres hasil cheat ikut save normal; gunakan slot pengujian.
