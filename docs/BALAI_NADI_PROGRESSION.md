# Balai Nadi dan perkembangan lembah

Balai Nadi adalah pusat kontribusi dan restorasi komunitas. Greenhouse adalah fasilitas terpisah di farm, terbuka sebagai reward permintaan **Sayap Alam — Kebun Sepanjang Musim**. Akses Balai memiliki papan sendiri di farm dan melewati eksterior balai.

## MVP berjalan

- Restorasi bangunan: 100 wood, 50 stone, 500 dana bersama. Penyelesaian mengubah visual balai.
- Permintaan Sayap Alam: 150 wood, 75 stone, 5 copper bar. Reward greenhouse dapat digunakan menanam sepanjang musim.
- Proyek dapat dikerjakan secara bebas dan bertahap. Greenhouse tidak mensyaratkan restorasi bangunan selesai terlebih dahulu.
- SaveManager menyimpan kontribusi, dana, WorldState, dan UnlockManager dalam satu transaksi; kegagalan save mengembalikan kontribusi.
- Tahap Terbengkalai → Pemulihan → Kehidupan Kembali mengikuti kontribusi dan penyelesaian kedua proyek. Tahap Lembah Berkembang masih menjadi target.

## Empat sayap dan perluasan

| Sayap | Target |
| --- | --- |
| Alam | Kebun komunitas, koleksi tanaman, hasil panen, sumber daya alam |
| Karya | Bengkel, resep crafting, perbaikan fasilitas, upgrade tool |
| Niaga | Pasar, merchant, jaringan perdagangan, peluang ekonomi |
| Pengetahuan | Perpustakaan, mineral, artefak, spesimen, pengetahuan dunia |

Karya, Niaga, dan Pengetahuan ditampilkan sebagai rancangan, belum memberi reward. Proyek baru menggunakan RestorationProject dengan wing_id, requirements, completion_flag, dan unlock_id. Pertahankan ID proyek lama agar save kompatibel.

Loop: aktivitas bebas → kontribusi → fasilitas pulih → aktivitas dan peluang baru → aktivitas bebas. Setiap proyek lanjutan harus membuka fungsi nyata serta perubahan visual. Target berikutnya: satu proyek Karya yang membuka layanan bengkel; kemudian Niaga dengan pasokan/permintaan, Pengetahuan dengan koleksi penemuan, NPC aktif, festival, dan persyaratan akses modern city.

Alternatif pendanaan untuk menggantikan material, ekonomi dinamis, NPC dinamis, festival, dan modern city belum diimplementasikan. MVP saat ini mensyaratkan bahan **dan** dana pada restorasi bangunan.
