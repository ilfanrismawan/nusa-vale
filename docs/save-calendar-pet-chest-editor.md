# Save/load, kalender, pet, dan peti

Pembaruan kustomisasi: profil dan pet kini berada pada tab tersendiri tanpa scroll. Pemilihan pet menggunakan kartu visual dan pagination; lihat `docs/character-setup-no-scroll.md`.

## Scene dan resource editor

- `scenes/ui/save_slot_menu.tscn`: layar slot dan modal konfirmasi.
- `scenes/ui/save_slot_card.tscn`: kartu slot, nama pemain/farm, tanggal, saldo, waktu simpan, aksi dan hapus.
- `scenes/ui/birthday_calendar.tscn`: popup kalender dengan navigasi musim.
- `scenes/ui/calendar_day.tscn`: template tombol tanggal.
- `scenes/ui/character_creator_ui.tscn`: tab profil, penampilan dan pet tanpa scroll, tombol kalender, kartu pilihan pet, preview ikon dan nama pet.
- `resources/pets/dog.tres`, `resources/pets/cat.tres`: ID, nama tampilan dan ikon pet dari asset project.
- Pilih root CharacterCreatorUI dan edit array pet_options untuk menambah/mengurutkan pilihan pet. Pet baru memakai script Resource `scripts/resources/starter_pet_option.gd`. ID harus unik dan stabil agar tetap sesuai save.
- `scenes/ui/chest_ui.tscn`: dua grid tas/peti, status, info item, bahan upgrade, tombol kemas.
- `scenes/ui/chest_item_slot.tscn`: ukuran, ikon dan jumlah item per slot.

Warna dan font mengikuti cooking_theme.tres serta startup_form_theme.tres. Layout tetap node native; script hanya mengisi daftar dinamis dan menghubungkannya ke sistem permainan.

## Kalender dan pet

Klik tombol ulang tahun, ganti musim dengan panah, lalu pilih tanggal. Kalender mengikuti DayCycle.SEASONS dan DAYS_PER_SEASON. Memilih tanggal mengisi profil; batal/Esc tidak mengganti tanggal sebelumnya.

Kalender menampilkan ikon musim, ikon kue pada judul, dan penanda kue pada tanggal ulang tahun yang telah dipilih. Pilih root BirthdayCalendar untuk mengganti birthday_icon dan array season_icons lewat Inspector. Ukuran/posisi ikon ada pada node scene; penanda tanggal ada pada template calendar_day.tscn. Ikon menggunakan asset project, bukan emoji font.

Pet bersifat opsional melalui pilihan Tanpa pet. Bila memilih pet, namanya wajib diisi dan tidak boleh hanya spasi. Pilihan dan nama disimpan per pemain sebagai PlayerData.pet_id dan pet_name. Lemari tetap hanya mengganti penampilan.

Perubahan ini menambah pilihan/profil pet dan penyimpanannya; belum menambahkan AI pet yang berjalan/mengikuti pemain di dunia. Ikon dapat diganti melalui resource pet.

## Save/load

Semua mode lama tetap tersedia: game baru, muat, simpan, dan co-op. Slot kosong tidak dapat dimuat. Hapus, timpa slot, serta pemuatan yang membuang progres tetap memakai konfirmasi. Data lama tanpa pet tetap dapat dibaca.

## Chest

Klik item pada tas untuk menyimpan satu tumpukan; klik item peti untuk mengambilnya. Transfer parsial/peti penuh mengikuti StructureManager.transfer sehingga tidak membuang sisa item. Kapasitas mengikuti tier resource item dan ukuran tas pemilik UI.

Upgrade memakai recipe yang sudah ada. Isi dan posisi peti tidak berubah. Peti berisi tidak dapat dikemas. Peti tetap dipakai bersama; tas yang menerima/membayar selalu milik pemain yang membuka UI. Scene otomatis disegarkan ketika pemain lain mengubah isi peti.

## Tes

Gunakan NUSA_SAVE_AUDIT=1 dan APPDATA terisolasi yang mengandung nusa-save-audit-. Jalankan:

- `tests/slot_calendar_pet_chest_regression.tscn`
- `tests/startup_ui_regression.tscn`
- `tests/structure_regression.tscn`
- `tests/save_regression.tscn`

NUSA_SERVICE_SCREENSHOT=1 pada tes khusus tanpa --headless menyimpan preview slot, kalender, pet, dan peti di scratch.

## Mengatur gambar peti per tier

Buka `resources/item_data/wooden_chest.tres`, `copper_chest.tres`, `iron_chest.tres`, atau `gold_chest.tres` di Inspector. Pada **Chest Visuals**, atur **Chest Closed Texture**, **Chest Open Texture**, dan **Chest Open Distance** (jarak kaki player ke pusat peti dalam piksel; default 34).

Setiap tier memiliki pasangan AtlasTexture sendiri di `resources/icons/icon_<tier>_chest.tres` dan `icon_<tier>_chest_open.tres`. Expand texture lalu edit **Atlas / Region**, atau ganti dengan Texture2D lain. Sprite sheet `chest.png` memakai baris y=0 untuk tertutup dan y=16 untuk terbuka, ukuran 16×16; kolom kayu x=232, tembaga x=40, besi x=8, emas x=104. Kedua state harus memakai kolom tier yang sama. Ikon inventory memakai gambar tertutup. Jika tekstur terbuka belum diisi, peti memakai tekstur tertutup miliknya sendiri.

### Delapan tier chest

| Tier | Item | Slot | Kolom atlas | Bahan crafting / upgrade |
| --- | --- | --- | --- | --- |
| 1 | wooden_chest | 24 | 232 | Resep kayu yang sudah ada |
| 2 | copper_chest | 36 | 40 | 5 copper_bar + 30 wood |
| 3 | iron_chest | 48 | 8 | 8 iron_bar + 40 wood |
| 4 | gold_chest | 60 | 104 | 10 gold_bar + 50 wood |
| 5 | platinum_chest | 72 | 72 | 12 platinum_bar + 60 wood |
| 6 | crimson_chest | 84 | 168 | 14 crimson_bar + 70 wood |
| 7 | frost_chest | 96 | 136 | 16 frost_bar + 80 wood |
| 8 | shadow_chest | 108 | 200 | 18 shadow_bar + 90 wood |

Empat nama tier baru mengikuti urutan material game; pasangan warna aset ditetapkan melalui resource masing-masing. Semua tekstur, jarak, kapasitas dan bahan resep bisa diedit di resource Inspector. Upgrade mempertahankan isi peti dan peti dapat dibuat langsung dari menu crafting Bangunan.
