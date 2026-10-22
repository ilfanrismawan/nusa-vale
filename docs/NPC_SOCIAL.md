# Status terbaru — 22 Oktober 2026

Kunci persahabatan permanen, household/upacara dasar, pasangan/roommate dan surat resep sudah ditambahkan. Panduan dan batas implementasi terkini: [IMPLEMENTATION_SOCIAL_ROLE_2026-10-22.md](IMPLEMENTATION_SOCIAL_ROLE_2026-10-22.md), [GDD bagian 12](GDD.md#12-hubungan-sosial-persahabatan--warga-desa-npc-schedules--friendship-terpasang-sebagian--keputusan). Isi tahap pertama di bawah adalah riwayat; pernyataan “belum dibuat” tidak berlaku untuk fitur yang sudah dijelaskan pada laporan terbaru.

# Persahabatan NPC tahap pertama

Sumber kode: `scripts/npc/npc_social_service.gd`. Hubungan berada di `PlayerData.friendships`, bukan saldo/world bersama. Save v19 menyimpan hubungan P1 di `player.friendships` dan P2–P4 dalam `coop_players`. Save lama tanpa field ini tetap diterima.

## Cara bermain

Pada Wira/Ubay, pilih **Bicara** untuk mendapat poin sapaan harian dan melihat jumlah hati. Pilih barang di hotbar sebelum memulai dialog, lalu klik tombol **Hadiah 1× …** atau tekan Y gamepad. Menutup dialog dengan B/Esc tidak memberikan hadiah. Slot yang dipakai adalah slot saat dialog dibuka. Alat, senjata, equipment, bangunan dan Biji Daya ditolak.

Sapaan memberi +20 sekali sehari. Hadiah dibatasi sekali sehari dan dua per minggu; hadiah ulang tahun dapat melampaui kuota minggu itu. Minggu dihitung hari 1–7, 8–14, dan seterusnya. Reaksi loved/liked/neutral/disliked/hated memberi +80/+45/+20/−20/−40, dikali delapan pada ulang tahun. Tidak ada penambahan biaya uang.

## Mengatur warga

Warga JSON memakai field opsional di tingkat atas `data/npc/<id>.json`:

```json
{
  "loved_items": ["wood"],
  "liked_items": [],
  "disliked_items": [],
  "hated_items": [],
  "birthday_season": "spring",
  "birthday_day": 4
}
```

Ini contoh konfigurasi, bukan tanggal/selera resmi Wira. Gunakan ID item dari `resources/item_data`, musim `spring`, `summer`, `fall`, `winter` dan tanggal 1–28. Tanpa preferensi, barang dinilai neutral. Tanpa tanggal, bonus ulang tahun tidak aktif. `NPCDefinition` juga menyediakan field yang sama di Inspector.

Integrasi UI saat ini berada pada `VillageNPC` dengan `npc_id` terdaftar di `NPCDatabase`. Menambahkan NPC baru ke database saja belum mengubah script NPC lain yang tidak menggunakan alur dialog ini.

Poin dibatasi 0–2.500 (250 per hati). Grace decay sementara 14 hari tanpa percakapan; setelah itu −2 poin per hari. Pada 2.500 poin decay berhenti. Nilai grace dan batas satu hadiah/hari masih pilihan pacing sementara yang tercatat di GDD.

## Batas tahap ini

Preferensi dan ulang tahun warga belum ditentukan sebagai konten. Heart events, quest, surat, resep hadiah, romansa dan panel daftar semua hubungan belum dibuat. Tes headless tidak menggantikan pemeriksaan tampilan atau gamepad fisik.

Tes: jalankan `tools/verify_mvp.ps1 -Scenes tests/npc_social_regression.tscn`. Runner mengisolasi save otomatis; tes menolak menulis file jika dijalankan tanpa lingkungan audit.
