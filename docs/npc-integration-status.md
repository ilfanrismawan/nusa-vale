# Integrasi NPC dan pemeriksaan data

**Pembaruan 24 Oktober 2026:** roster aktif sekarang 13 resident terpusat, bukan lima. Profil hadiah lama sudah dipindahkan ke JSON masing-masing; Baskoro ikut sistem sosial/presenter Universitas. Seluruh warga mempunyai lima milestone event dialog dan reward resep. Kedai Zarathia/Joko sudah terhubung; portrait khusus si kembar/Ubay sudah dipakai. Status, lokasi pengaturan dan batas implementasi terbaru: [NPC_CENTRALIZATION_2026-10-24.md](NPC_CENTRALIZATION_2026-10-24.md). Uraian lima resident dan placeholder di bawah merupakan riwayat sebelum migrasi bila bertentangan dengan pembaruan ini.

## Yang sudah terpasang

- Wira, Ubay, Zarathia, Zarathustra dan Eep terdaftar di `scenes/npc/npc_database.tscn`.
- Format dialog string lama dan objek `{text, expression, requires_flags}` sama-sama diterima.
- `dialogue_by_hearts` memilih tingkat tertinggi yang memenuhi hati pemain. Jika tidak ada tingkat yang cocok, dialog aktivitas dipakai, kemudian `default`.
- `friendship.start` menggunakan **poin**, bukan jumlah hati. Satu hati = 250 poin; batas mengikuti `friendship.max_hearts` masing-masing NPC.
- Hadiah membaca `gift_tastes`, `gift_dialogue`, dan `birthday`. Batas satu hadiah per hari, dua per minggu; hadiah ulang tahun memiliki bonus sesuai sistem sosial.
- `service: null` menyembunyikan layanan. Wira hanya menerima konstruksi saat aktivitas `working`, selain Minggu; Ubay membuka informasi pengiriman.
- Heart event diperiksa saat memilih **Bicara**. Syarat hati, flag, cuaca, peta, waktu, serta kedekatan pemain dan NPC ke marker harus terpenuhi. Event disimpan setelah halaman terakhir selesai. Membatalkan dialog tidak menyelesaikan event.
- Status dating/married, flag cerita, event selesai, surat dan persahabatan tersimpan per karakter pemain, termasuk karakter co-op. Save lama memperoleh nilai default kosong.
- Setiap NPC memiliki node Path2D dan resource Curve2D sendiri. Kurva boleh melewati jalan yang sama, tetapi tidak berbagi resource. NPC terjadwal tidak saling mengunci pergerakan; tetap bertabrakan dengan lingkungan.

## Mengubah lewat editor

1. Buka `scenes/npc/npc_database.tscn`, pilih root, lalu buka elemen **Resident Profiles**.
2. **Schedule Source = JSON** memakai `schedules` di file sumber. Kelima NPC menggunakan pilihan ini.
3. **Schedule Source = Inspector** memakai **Default Schedule / Rainy Schedule** pada resource profil. Ubah pilihan ini bila ingin mengatur jadwal lewat Inspector; pada mode tersebut perubahan jadwal JSON tidak dipakai.
4. **Move Speed**, **Waypoint Radius**, sprite, portrait dan identitas dapat diatur dari profil. Nilai override profil mengalahkan JSON.
5. Buka peta tujuan, pilih `NPCPaths`, lalu node Path2D dengan nama NPC. Gunakan alat edit kurva bawaan Godot. Marker tujuan ada di `NPCPoints` pada peta.
6. Bila mengedit scene rute secara terpisah, tampilkan hanya peta referensi yang sesuai. Perubahan yang sudah dibuat pada instance `NPCPaths` di peta memiliki prioritas terhadap scene rute. Hill dan Farm saat ini memiliki override kurva tersebut; edit langsung dari peta untuk melihat hasil runtime yang sama.
7. Sambungkan ujung kurva pada koordinat yang sama, dengan toleransi **Join Distance** di root `NPCPaths`. `NPC Id` pada setiap kurva harus sesuai profil. Node gateway adalah Marker2D dengan **Destination Maps**; `NPC Id` kosong berarti gateway bersama.

## Urutan cerita keluarga

| NPC | Hati minimal | Cuaca | Peta / marker | Waktu | Prasyarat |
| --- | --- | --- | --- | --- | --- |
| Zarathia | 4 | Cerah | Hill / wira_overlook | 16:30â€“18:00 | Belum selesai |
| Zarathustra | 6 | Cerah | Town / town_square | 17:00â€“19:00 | Cerita Zarathia selesai |
| Wira | 8 | Cerah | Hill / wira_overlook | 18:30â€“21:00 | Cerita Zarathustra selesai |

Waktu akhir tidak termasuk jendela event. Dekati NPC yang sudah sampai di marker, lalu pilih **Bicara**. Setelah tiga cerita selesai, surat Yayas dijadwalkan dua hari kemudian. Pilih **Baca Surat** pada menu Wira setelah hari pengiriman. Menyelesaikan seluruh halaman surat memasang flag `family_letter_read`; dialog terkait surat baru terbuka setelah itu.

Konfigurasi urutan dan surat berada di `data/npc/wira_family_story.json`. File ini merupakan data cerita, bukan profil NPC. Syaratnya digabung dengan `heart_events` milik NPC yang memiliki ID event sama.

## Romance yang tersedia

Zarathia dan Zarathustra memakai `romanceable: true`. Menu **Nyatakan Perasaan** memeriksa `romance.dating_hearts`; setelah dating muncul **Melamar**, memakai `romance.marriage_hearts`. Tanggapan membaca `romance_dialogue`. Status berubah setelah dialog penerimaan selesai; membatalkan dialog tidak mengubah status. Satu karakter pemain hanya dapat berkomitmen kepada satu NPC.

Tindak lanjut 22 Oktober: upacara dialog di rumah, household pasangan/teman sekamar, jadwal pulang rumah, bantuan harian dan surat resep tersedia melalui `NPCHousehold`; lihat [laporan implementasi](IMPLEMENTATION_SOCIAL_ROLE_2026-10-22.md). `romance.spouse_home_map` belum menjadi pemilih scene; rumah bersama saat ini memakai `interior_house.tscn`. Sinematik khusus dan kehidupan keluarga lanjutan masih target. Profesi penjual teh Zarathia juga belum membuka toko karena data layanannya masih `null`.

## Hasil pemeriksaan JSON

Lima file NPC dan satu file cerita dapat diparse. Kesalahan penulisan Wira (koma berlebih, kurung dan tanda kutip), referensi marker/aset si kembar, serta `autumn` ke `fall` telah diperbaiki. Field `likes` Ubay diubah menjadi `gift_tastes.liked` agar benar-benar terbaca oleh sistem hadiah. Teks cerita dipertahankan. Nama ibu pada surat adalah Yayas; ID internal surat `letter_from_laras` tetap dipertahankan sebagai identitas event.

Seluruh daftar hadiah telah diperbarui memakai item proyek yang memiliki ikon. Lima kategori tersedia untuk 12 NPC. Lihat [daftar hadiah dan lokasi pengaturannya](npc-gifts.md). Profil NPC lama berada di `data/npc/social/gift_profiles.json`; profil tersebut tidak menambah spawn atau jadwal.

Zarathia sementara memakai sprite/portrait **Tori**, Zarathustra memakai **Manu** dari paket aset proyek. Resource animasi mereka terpisah. Ganti `visual.sprite_frames` / `visual.portrait` di JSON atau override resource profil saat artwork khusus tersedia. Ubay tetap memakai aset yang sebelumnya direferensikan profilnya.

## Menjalankan validator

Jalankan dari terminal di root proyek:

```powershell
python tools/validate_npc_data.py
```

Validator memeriksa sintaks ketat termasuk key duplikat, ID NPC/event, file visual, marker jadwal/event, urutan waktu, dialog/ekspresi, batas hati, ulang tahun, jenis layanan, dan ID hadiah terhadap resource item. Error menghasilkan exit code 1; ID hadiah yang belum dibuat dilaporkan sebagai warning. Hasil setelah perbaikan: **0 error, 0 warning**.

Pengujian Godot tersedia pada `tests/residents_regression.tscn`, `tests/npc_paths_regression.tscn`, `tests/npc_inspector_regression.tscn`, `tests/npc_social_regression.tscn`, `tests/npc_story_regression.tscn`, dan `tests/npc_gifts_regression.tscn`. Tes yang menyentuh save memakai APPDATA terpisah dengan nama `nusa-save-audit-*`; jangan menjalankannya menggunakan folder save pemain.

Detail jadwal dan konfigurasi Eep tersedia di [panduan Eep](eep-npc.md).
