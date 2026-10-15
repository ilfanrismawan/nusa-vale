# Progres Nusa Vale — 15 Oktober 2026

## Posisi proyek saat ini

Kelanjutan prioritas progres awal: pasokan bijih Forest dipulihkan, jalur bahan
Tembaga → Besi dibuka lewat endapan kecil, margin batu awal diperbaiki, serta
UI upgrade menampilkan manfaat dan sisa modal. Pacing manual dan combat tetap
belum dinyatakan selesai. Rincian: [EARLY_PROGRESSION_AUDIT_2026-10-15.md](EARLY_PROGRESSION_AUDIT_2026-10-15.md).

**Alpha dengan banyak sistem inti terpasang; sedang menuju penyelesaian dan stabilisasi MVP.** Proyek telah melampaui prototipe farming: ada sistem produksi, penjualan, pembangunan, peternakan, eksplorasi, restorasi, persistensi dan co-op yang saling terhubung. Ini penilaian teknis berdasarkan repository, bukan bukti kesiapan rilis atau hasil playtest pengguna.

Persentase total belum layak diberikan. GDD mencakup game utama sekaligus visi ekspansi besar, tanpa bobot pekerjaan atau definisi selesai per fitur. Menghitung jumlah fitur akan menyamakan pekerjaan kecil dengan combat/dungeon atau seluruh Modern City.

## Yang sudah dicapai

| Pilar | Bukti implementasi | Penilaian |
|---|---|---|
| Fondasi permainan | Godot 4.7, menu, karakter, inventory/equipment, hotbar, settings, save slots | Fondasi tersedia |
| Pertanian | 39 resource crop, siklus musim, penyiraman, panen, Greenhouse | Loop inti tersedia |
| Produksi dan ekonomi | Toko, shipping esok hari, crafting, storage, furnace, mesin artisan, upgrade alat bertempo | Rantai hasil → olah/jual → investasi tersedia |
| Peternakan | Lima spesies; pakan, kesehatan/kebersihan, kasih sayang, kualitas, merumput, silo, interior, upgrade | Sistem substansial sudah terpasang |
| Dunia dan progres | Farm, Forest, Deep Forest, Town, Balai Nadi, Greenhouse, unlock/restorasi | Beberapa area dan tujuan progres tersedia |
| Kehidupan desa | NPC bernama, dialog, jadwal, waypoint, layanan; 14 exterior town dan interior | Kehidupan desa dasar tersedia |
| Cooking dan stamina | Lima resep, buku per pemain, stamina/buff laju; tiga Biji Daya menuju kapasitas 130 | Implementasi tahap dasar |
| Co-op dan persistensi | Split-screen lokal 2–4; konteks pemain/world, save v13 dan tes transaksi | Fondasi tersedia; kenyamanan perlu validasi manual |
| Kualitas teknis | Runner parser/scene/regresi, isolasi save, pengujian rollback dan ekspor terdahulu | Ada proses verifikasi yang dapat diulang |

## Yang masih sebagian

- Cuaca baru cerah/hujan. Prakiraan, salju, badai dan penangkal petir belum merupakan loop lengkap.
- Cooking belum mencakup dapur rumah hasil upgrade, HP/combat, dan resep dari hubungan sosial/TV.
- NPC sudah dapat bergerak dan memberi layanan; sistem hubungan hati, hadiah, heart events dan romansa belum dapat disamakan dengan jadwal NPC.
- Data equipment belum berarti sistem pertarungan tersedia. HP, serangan, musuh, damage, reward, dan dungeon harus terhubung untuk membuktikan combat.
- Fishing sudah memiliki minigame; filter musim dan air beku masih target. Pohon buah permanen dan tanaman dingin khusus juga belum dinyatakan selesai.
- Mesin utama tersedia; Keg, Oil Maker dan Fish Smoker masih perlu implementasi.
- Biji Daya baru tiga sumber; target kapasitas 200 memerlukan tujuh sumber berikutnya.

## Pekerjaan besar yang masih di depan

HP/combat dasar dan dungeon; area Gunung/pantai; hubungan sosial; role/EXP/skill tree; bazaar; festival; ekonomi dinamis/pajak; kendaraan; Modern City. Semuanya tetap dalam visi GDD, tetapi bukan bukti capaian implementasi saat ini.

## Rekomendasi milestone berikutnya

**Blocker verifikasi saat audit:** full suite 15 Oktober berhenti pada tes transisi Balai: tes mencari `ReturnFarm`, scene memakai `ReturnWorld`. Sebelas kelompok regresi sebelumnya lulus, tetapi kelompok setelah titik gagal belum dijalankan. Perbaiki kesesuaian tes/pintu dan ulangi suite sebelum menyatakan stabilisasi selesai. Rincian bukti ada di laporan audit.

**Pembaruan setelah implementasi sesi yang sama:** referensi lama pada dua tes Balai telah diperbaiki, menu kandang mendapat guard ID invalid, dan fixture carpenter diperkuat. Stamina penyiraman, reset tanah kosong dan syarat tier objek sudah terpasang. Seluruh cakupan runner telah diperiksa melalui gabungan run; run terakhir dari feedback hingga save lulus. Lihat [laporan perubahan](GAMEPLAY_RULES_2026-10-15.md). Blocker tes awal sudah ditindaklanjuti; playtest manual dan combat MVP tetap pekerjaan berikutnya.

1. **Tutup stabilisasi loop yang ada.** Selesaikan suite, lalu mainkan satu putaran beberapa hari dari New Game → produksi → shipping → upgrade → restorasi → save/reload. Catat hambatan kontrol, waktu tempuh, keterbacaan dan keseimbangan uang/stamina untuk solo serta co-op.
2. **Tetapkan gerbang MVP yang konsisten.** Checklist stabilisasi berfokus pada farming; GDD juga mensyaratkan combat dasar. Berdasarkan cakupan GDD sekarang, MVP belum selesai sampai combat tersebut tersedia dan diuji. Pengurangan scope memerlukan keputusan pemilik proyek.
3. **Bangun satu potongan combat lengkap.** HP/damage, satu senjata dan musuh, satu ruangan tambang, loot serta pemulihan/save. Perluas setelah loop ini terbukti; spesifikasi Soulslike penuh berada di roadmap lanjutan.
4. **Perkuat alasan bermain kembali.** Tambahkan tujuan restorasi/quest dan sosial bertahap sebelum ekspansi bazaar, festival, atau Modern City. Ini rekomendasi urutan, bukan pembatalan fitur.
5. **Validasi distribusi.** Uji build pada platform target, gamepad fisik, suara/visual serta sesi co-op panjang. Tes headless tidak mengukur kualitas pengalaman tersebut.

Tidak ada estimasi tanggal selesai karena kapasitas tim, jam kerja dan scope milestone belum ditetapkan. Ringkasnya, fondasi dan breadth sistem sudah kuat; pekerjaan berikutnya adalah menuntaskan integrasi, kedalaman progres dan bukti kualitas bermain.

Audit dan hasil verifikasi sesi ini: [AUDIT_2026-10-15.md](AUDIT_2026-10-15.md). Status desain terkini: [GDD.md](GDD.md).
