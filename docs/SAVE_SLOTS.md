# Slot Save Game

Catatan desain sistem simpan/muat (pengganti bagian save di GDD; `docs/GDD.md`
belum ada di repo, pindahkan isi ini ke GDD saat file itu dibuat).

## Ringkas

- 3 slot: `user://saves/slot_1.json` .. `slot_3.json`. Tiap slot punya `.bak`
  (cadangan otomatis) dan `.tmp` sendiri, dengan alur tulis aman yang sama
  seperti versi satu-file.
- Slot aktif = `SaveManager.current_slot`. Auto-save saat tidur/pingsan masuk ke
  slot aktif. Slot terakhir diingat di `user://saves/slots.cfg` dan dimuat
  otomatis saat game dibuka (perilaku lama).
- Save lama `user://nusa_vale_save.json` (+ `.bak`) disalin ke slot 1 saat game
  pertama dibuka, lalu file lama diganti nama menjadi `*.migrated` (tidak dihapus).
  Jika slot 1 sudah terisi, dipakai slot kosong pertama.

## Menu slot (`scripts/ui/save_slot_menu.gd`, class `SaveSlotMenu`)

Tiap slot menampilkan: nama karakter, musim + hari + tahun, uang, waktu simpan.
Slot kosong tertulis "Kosong". Slot terisi punya tombol Hapus (dengan konfirmasi).

| Dari mana | Tombol | Mode | Perilaku |
|---|---|---|---|
| Menu utama | Game Baru | `NEW_GAME` | Pilih slot, slot terisi minta konfirmasi timpa, lalu buat karakter. Game langsung disimpan ke slot itu. |
| Menu utama | Muat Game (dulu "Lanjutkan") | `LOAD` | Hanya slot terisi; bangun di rumah. |
| Menu utama | Co-op Lokal | `PLAY` | Slot kosong = game baru (disimpan langsung), terisi = lanjutkan; lalu lobby. |
| Menu pause (Esc) | Simpan Game | `SAVE` | Simpan kapan saja; slot lain yang terisi minta konfirmasi timpa. Slot tujuan jadi slot aktif. |
| Menu pause (Esc) | Muat Game | `LOAD` | Konfirmasi "progres yang belum disimpan akan hilang", lalu bangun di rumah. Dinonaktifkan saat co-op (muat dari menu utama). |

Nama karakter diketik di layar Penampilan Karakter saat Game Baru (maks 16
huruf). Kosong = "Petani". Lemari di rumah tidak mengubah nama.

## Format save (versi 7)

Tambahan dari versi 6:
- `saved_at`: waktu simpan (unix, UTC). Save lama memakai waktu ubah file.
- `player.name` dan `coop_players[i].name`: nama pemain. Save lama = kosong.

Save versi 1-6 tetap termuat.

## Keputusan yang diambil Claude (belum ada di GDD)

- Simpan manual bisa kapan saja dari menu pause (bukan hanya lewat tidur).
- Game Baru dan co-op di slot kosong langsung menyimpan supaya slot terisi.
- Muat saat co-op hanya dari menu utama.
- Posisi pemain tidak disimpan; setelah muat selalu bangun di rumah (sama seperti
  "Lanjutkan" sebelumnya).

## Changelog

- 2026-10-11: Slot save (3 slot), menu Simpan/Muat/Hapus, migrasi save lama ke
  slot 1, nama karakter, `SAVE_VERSION` 6 -> 7. Tes di `tests/save_regression.gd`.
