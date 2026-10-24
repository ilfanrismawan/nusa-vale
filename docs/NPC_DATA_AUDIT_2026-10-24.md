# Laporan pemeriksaan data NPC — 24 Oktober 2026

**Riwayat sebelum pengerjaan:** kekurangan pada laporan ini sudah ditindaklanjuti. Status aktif setelah migrasi, bukti tes dan pekerjaan tersisa ada di [NPC_CENTRALIZATION_2026-10-24.md](NPC_CENTRALIZATION_2026-10-24.md).

Pemeriksaan statis atas workspace aktif, termasuk perubahan belum di-commit. Acuan desain: ringkasan terbaru GDD dan bagian 12; status playtest mengikuti `PLAYTEST_STATUS.md`. Tidak mengubah gameplay atau data NPC. Tidak menjalankan ulang playtest umum.

## Ringkasan hasil

- **5 resident terpusat:** Wira, Ubay, Eep, Zarathia, Zarathustra; terdaftar melalui `scenes/npc/npc_database.tscn` dan resource `*_resident.tres`.
- **7 profil sosial tambahan:** Kirana, Bahar, Joko, Ratih, Rian, Damar, Bima di `data/npc/social/gift_profiles.json`. Mereka sudah mempunyai lima kategori hadiah; bukan NPC tanpa data sama sekali. Profil hadiah tidak otomatis menyediakan jadwal, cerita, atau spawn resident.
- **Prof. Baskoro** ada pada scene Universitas, tetapi belum mempunyai profil resident maupun profil hadiah pada database tersebut.
- **Validasi aktual:** `python tools/validate_npc_data.py` selesai dengan `5 residents, 7 social profiles, 1 story file(s), 0 error(s), 0 warning(s)`.
- Hasil validator membuktikan konsistensi data yang diperiksanya, bukan kelengkapan semua target GDD, kualitas visual, atau seluruh perilaku saat dimainkan.

## Kekurangan pada lima resident

| NPC | Data yang sudah tersedia | Data/konten yang belum lengkap |
|---|---|---|
| Wira | Identitas, keluarga, ulang tahun, hadiah, jadwal normal/hujan, layanan konstruksi, satu event 8 hati, rangkaian surat keluarga, reward resep | Tidak mempunyai `dialogue_by_hearts`; belum rangkaian event 2/4/6/8/10 hati. Dialog bersyarat cerita tetap ada sehingga ini bukan berarti seluruh dialog progres tidak tersedia. |
| Ubay | Identitas, ulang tahun, hadiah, sembilan entri jadwal normal, layanan shipping, reward resep, kandidat roommate | Tidak ada jadwal hujan khusus, `dialogue_by_hearts`, maupun `heart_events`. Saat hujan memakai jadwal default. Portrait aktif masih Josh; aset Ubay sendiri sudah ada tetapi belum direferensikan JSON aktif. |
| Eep | Identitas, ulang tahun, hadiah, jadwal normal/hujan, layanan ternak dan tutup Rabu, dialog 4/8 hati, satu event 4 hati, reward resep, roommate | Belum event 2/6/8/10 hati. Tempat tinggal dijelaskan sebagai peternakan di luar gerbang barat, tetapi `home_map` masih Town dan aktivitas tidur offscreen; belum interior rumah khusus yang dituju profil ini. |
| Zarathia | Identitas/keluarga, ulang tahun, hadiah, jadwal normal/hujan, dialog 4/8 hati, satu event 4 hati, data romansa dan reward resep | Profesi penjual teh/kue belum menjadi layanan: `service: null`. Belum event 2/6/8/10 hati. Visual aktif masih Tori. Aset portrait khusus sudah ada di folder Zarathia, tetapi JSON dan resource animasi belum memakai aset tersebut. |
| Zarathustra | Identitas/keluarga, ulang tahun, hadiah, jadwal normal/hujan, dialog 4/8 hati, satu event 6 hati, data romansa dan reward resep | Belum event 2/4/8/10 hati. Visual aktif masih Manu, meskipun aset portrait khusus sudah ada. `service: null` tidak otomatis merupakan bug: profesi asisten tidak harus menjadi toko terpisah. |

Jumlah event resident saat ini **4**: Wira 1, Ubay 0, Eep 1, Zarathia 1, Zarathustra 1. Jika target GDD lima event per warga diterapkan pada kelima resident, masih ada **21 slot event** yang belum terisi. Ini selisih terhadap target konten, bukan 21 error validator.

Sumber: `data/npc/{wira,ubay,eep,npc_zarathia,npc_zarathustra}.json`, `data/npc/wira_family_story.json`, `data/npc/social/household_rules.json`, dan `resources/npc_data/npc_animation/npc_zarath*.tres`.

## NPC di luar resident terpusat

Ketujuh profil sosial hanya memuat nama, peran, selera hadiah, dan sebagian referensi portrait. Pada profil tersebut belum ada ulang tahun, kepribadian, cerita/event, dialog hati, atau reward surat/resep. Beberapa NPC memiliki dialog dan jadwal tersendiri dalam scene lama; data itu tetap dihitung sebagai implementasi yang sudah ada.

| NPC | Implementasi yang ditemukan | Pekerjaan yang belum tersedia/terpusat |
|---|---|---|
| Kirana | `NPCDefinition` berisi ID, nama, umur 29, sprite; profil hadiah; script NPC generik | Resource belum mengisi profesi, home map, personality, portrait, ulang tahun dan jadwal. Dialog script generik masih satu sapaan. Perlu profil dan jalur jadwal/interaksi yang lengkap. |
| Bahar | Scene NPC, portrait, jadwal dan dialog lokal, profil hadiah | Profil resident, ulang tahun, kisah pribadi, event hati, dialog progres dan reward surat. Jadwal lokal belum setara rute lintas peta resident. |
| Joko | Scene koki, portrait, jadwal/dialog lokal, profil hadiah | Profil resident, ulang tahun, event/cerita hati, reward resep khas koki. Target resep/surat semua warga belum tercapai. |
| Ratih | Scene, portrait, jadwal/dialog lokal, profil hadiah | Profil resident, ulang tahun, kisah/event hati, dialog progres dan reward surat. |
| Rian | Scene, portrait, jadwal/dialog lokal, profil hadiah | Profil resident, ulang tahun, kisah/event hati dan reward surat. Peran profil “Penjual Ternak” perlu diselaraskan dengan Eep agar pembagian peran jelas; tidak otomatis berarti layanan Rian rusak. |
| Damar | Scene turunan Tori, script carpenter, profil hadiah | `schedule = []`: belum rutinitas harian pada scene ini. Belum profil resident, ulang tahun, event/cerita dan reward surat; visual masih turunan Tori dengan tint. Pembagian profesi konstruksi dengan Wira perlu ditegaskan. |
| Bima | Scene pandai besi, script layanan upgrade/geoda dan profil hadiah | Belum jadwal mobilitas: script masih `StaticBody2D`. Belum profil resident, ulang tahun, cerita/event dan reward surat. Layanan tempa yang sudah ada tidak perlu dibuat ulang. |
| Prof. Baskoro | NPC Universitas dengan nama dan dialog `Notify`, menghadap pemain | Belum ID/profil sosial terpusat, selera hadiah, ulang tahun, persahabatan melalui script ini, jadwal, event dan reward surat. Script `university_npc.gd` saat ini hanya memutar dialog lokal. |

Sumber: `gift_profiles.json`, `npc_kirana.tres`, scene NPC terkait, `town.tscn`, scene Universitas, `scripts/npc/npc.gd`, `scripts/world/{village_npc,blacksmith_npc,university_npc}.gd`.

## Kekurangan lintas sistem/konten terhadap GDD

1. **Jadwal musiman/festival belum terwakili pada data kelima resident.** Data baru berisi `default` dan, untuk empat resident, `rainy`. Pemilih `NPCDatabase.schedule_entry()` hanya memilih hujan/default, ditambah override household. Data jadwal musim dingin/festival membutuhkan dukungan pemilih jadwal, bukan sekadar menambah JSON. Tutup toko Minggu/Rabu bukan jadwal libur khusus.
2. **Heart event masih dialog berhalaman yang dipicu melalui Bicara**, bukan seluruh rangkaian sinematik otomatis saat masuk lokasi dan pilihan jawaban bercabang sebagaimana target GDD 12.3. Data event yang ditemukan berisi `lines`, syarat dan flag; belum cabang pilihan.
3. **Surat resep/bingkisan baru mencakup lima resident**, masing-masing satu reward di `household_rules.json`; tujuh profil tambahan dan Baskoro belum mempunyai reward di konfigurasi itu.
4. **Romansa dasar sudah ada**, termasuk dating/lamaran untuk si kembar, syarat rumah, upacara dialog, household, bantuan harian, serta roommate Ubay/Eep. Yang belum terpasang menurut GDD terkini: bouquet, pendant, gate hati 9–10 melalui bouquet, sinematik/undangan tamu, dan aktivitas keluarga lanjutan. Jangan menandai seluruh pernikahan/roommate sebagai belum dikerjakan.
5. **`romance.spouse_home_map` belum menentukan scene tujuan.** Kedua kandidat berisi `player_farm_house`, sementara household memakai entri `player_home` dan rumah bersama yang sudah tersedia. Field tersebut belum menjadi konfigurasi rumah alternatif yang efektif.
6. **Konten permintaan warga/Help Wanted dan festival sosial masih target GDD.** Belum ditemukan data request/bouquet/pendant atau pilihan dialog bercabang dalam penelusuran kode/data terkait. Jangan menganggap menambah selera hadiah saja sudah memenuhi fitur ini.

## Konsistensi yang perlu dirapikan

- Ringkasan roster lama GDD masih menyebut Wira sebagai penjelajah, sementara resident aktif adalah tukang kayu; Ubay sudah kurir, bukan sekadar warga yang bersantai. Catatan keputusan terbuka tentang nama kurir juga tertinggal dari implementasi Ubay.
- `ToriNPC.tscn` memakai `npc_id = "wira"` dan masih di-instance di Town, sementara Wira juga terdaftar sebagai resident terjadwal. Perlu pemeriksaan khusus penanganan instance lama sebelum migrasi/menghapusnya; temuan statis ini belum membuktikan dua Wira tampil bersamaan saat runtime.
- Folder portrait khusus Zarathia, Zarathustra dan Ubay sudah ada. Kekurangannya adalah integrasi referensi aktif, sehingga tidak tepat melaporkan semua artwork tersebut “belum dibuat”. Kesesuaian layout ekspresi perlu diperiksa sebelum mengganti referensi.
- Field `gender` tidak seragam: terisi pada Eep dan si kembar, tidak pada Wira/Ubay. Ini kelengkapan metadata opsional; belum ada bukti menyebabkan gameplay gagal.
- Yayas secara eksplisit berstatus `offscreen`; tidak adanya scene Yayas bukan otomatis kekurangan implementasi tanpa keputusan menghadirkannya secara fisik.

## Urutan tindak lanjut yang disarankan

1. Selaraskan identitas/peran aktif dan referensi visual yang asetnya sudah tersedia; tetapkan pembagian Wira–Damar serta Eep–Rian dan status instance Tori lama.
2. Lengkapi konten pada sistem yang sudah tersedia: dialog progres Ubay/Wira, event Ubay, variasi dialog/event lima resident, serta reward surat. Tentukan balancing hadiah/reward agar mendukung prioritas ekonomi aktif.
3. Migrasikan NPC lama secara bertahap ke profil resident, mulai dari NPC layanan yang sering ditemui. Isi ulang tahun, kepribadian, rumah/rute, cerita dan reward; pertahankan layanan yang sudah bekerja.
4. Setelah konten dasar merata, perluas sistem untuk jadwal musim/festival, pilihan dialog, sinematik, bouquet/pendant dan fitur sosial lanjutan.

Milestone playtest inti solo/co-op tetap **lulus/selesai menurut pemilik**. Pengujian berikutnya cukup terarah pada perubahan NPC yang benar-benar dilakukan. Audit ini hanya menjalankan validator Python; tidak mengklaim suite Godot atau pemeriksaan visual runtime terbaru lulus.
