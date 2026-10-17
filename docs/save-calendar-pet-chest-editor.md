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
