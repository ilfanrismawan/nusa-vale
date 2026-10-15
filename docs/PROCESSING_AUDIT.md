# Audit pengolahan dan feedback

13 Oktober 2026. Durasi berikut berasal dari resource resep dan implementasi aktif StructureManager, tanpa perubahan keseimbangan durasi.

| Mesin/resep | Detik aktif |
|---|---:|
| Furnace: Copper / Iron / Gold | 3,5 / 4 / 4,5 |
| Furnace: Platinum / Crimson / Frost | 5 / 5,5 / 6 |
| Furnace: Shadow / Fairy / Obsidian | 6,5 / 7 / 8 |
| Preserves Jar: seluruh 4 resep | 5 |
| Dehydrator: seluruh 2 resep | 5 |
| Mayonnaise Maker / Cheese Press / Loom | 20 |

Waktu menggunakan detik nyata saat DayCycle berjalan. Pause menghentikan proses dan feedback; tidur/offline tidak memberi catch-up. Sisa waktu dan hasil siap disimpan. Menu mesin memperlihatkan sisa waktu dan status dijeda.

## Perbaikan

- Loader resep mendukung `.tres.remap` pada ekspor dan mencegah resep duplikat.
- Hasil siap mengalahkan job lama yang bersamaan pada save, sehingga bahan tidak diproses ulang.
- Pengambilan hasil memperbarui status sebelum notifikasi inventory, mencegah pengambilan berulang dari callback. Tas penuh mempertahankan hasil.
- UID bangunan dipertahankan saat load, termasuk nomor tidak berurutan.

## VFX dan SFX

Furnace memakai percikan hangat dan cahaya berkedip; preserves memakai gelembung; dehydrator memakai aliran udara hangat. Mayones memakai partikel krim, keju memakai warna emas, dan tenun memakai serpihan serat. Mesin bergetar lembut saat berjalan. Loop suara spasial berbeda untuk tiap mesin, mengikuti bus SFX, berhenti ketika proses selesai/dijeda, dan kembali saat dilanjutkan. Hasil siap memakai bunyi penanda dan sparkle.

Placement bangunan yang berhasil memakai `resources/feedback/building_place.tres`: debu tanah, sparkle sudut, suara tanah, dan getaran kamera ringan. Placement ditolak tidak memunculkan feedback keberhasilan. Konteks pemain dipakai agar feedback co-op muncul pada pemain yang menempatkan.

Audio di `assets/audio/sfx/machines` dibuat secara prosedural; provenance ada pada `SOURCES.md`. Sprite mesin menggunakan aset proyek.

`tests/production_audit.tscn` memeriksa semua durasi resep, batas penyelesaian, pengambilan sekali, pause, save/load, status hasil/job, serta feedback running/selesai dan konfigurasi placement. Script furnace lama di `scripts/world/furnace.gd` adalah prototipe yang tidak dipakai scene gameplay; audit ini mencakup mesin crafted yang dikelola StructureManager.

Hasil: audit pengolahan, pause/resume feedback mesin ternak, audit save, regresi placement, pintu/Toko Ternak, dan NPC lulus dengan `failures=0`. Audit save sengaja memicu kegagalan I/O untuk menguji pemulihan; pesan error tersebut merupakan kasus uji yang diharapkan. Pengulangan regresi struktur timeout sebelum pemeriksaan pertama. Suite keseluruhan belum dinyatakan bersih.
