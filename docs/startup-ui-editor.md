# Main menu dan kustomisasi karakter

Kustomisasi terbaru memakai tab dan pagination tanpa scroll; lihat `docs/character-setup-no-scroll.md`. Pemilihan pet menggunakan kartu, bukan dropdown.

## Edit tampilan di Godot

- `scenes/ui/main_menu.tscn`: judul, subjudul, panel krem, tombol game baru/muat/co-op/pengaturan/keluar. Co-op sekarang merupakan node scene, bukan duplikasi tombol melalui kode.
- `scenes/ui/character_creator_ui.tscn`: tiga panel preview, pilihan penampilan, dan profil petani. Layout, ukuran font, posisi tombol, serta teks label dapat diedit langsung.
- `scenes/ui/character_option_row.tscn`: template baris pilihan penampilan.
- `scenes/ui/startup_background.tscn`: gambar pegunungan bawaan project dan lapisan gradient. Ganti texture Mountains untuk mengganti latar kedua layar.
- `resources/ui/startup_form_theme.tres`: warna, font, bentuk input, dropdown, dan popup.
- `resources/ui/cooking_theme.tres`: tema bersama dengan UI cooking dan layanan NPC.

Pilih root CharacterCreatorUI untuk mengubah panjang maksimum nama/farm, pesan validasi, label musim, skala preview, dan ukuran desain. Root Design diskalakan proporsional mengikuti viewport. Kolom pilihan dan bahan karakter tetap mengikuti katalog penampilan project.

## Profil wajib pada game baru

Nama karakter, nama farm, musim, dan tanggal ulang tahun wajib diisi. Teks yang hanya berisi spasi ditolak. Tombol Selesai nonaktif hingga seluruh input lengkap; pemanggilan konfirmasi langsung juga divalidasi.

Ulang tahun menggunakan kalender game, bukan kalender Masehi: empat musim dan tanggal 1–28, mengikuti DayCycle.SEASONS dan DayCycle.DAYS_PER_SEASON. Tidak memerlukan tahun lahir.

Game baru solo dan slot baru co-op membuka form ini sebelum menyimpan/memulai permainan. Save co-op yang sudah ada tetap dapat langsung dilanjutkan. Lemari hanya mengubah penampilan: tidak memaksa isi ulang profil dan tidak menimpa nama, farm, atau ulang tahun.

## Penyimpanan

Nama farm merupakan data bersama di GameState.farm_name. Ulang tahun dimiliki masing-masing PlayerData (birthday_season dan birthday_day). Keduanya disimpan melalui SaveManager dan kompatibel dengan save lama yang belum memiliki kolom tersebut. Data lama tanpa profil tetap dapat dimuat; tidak diberi ulang tahun palsu.

## Validasi

Tes khusus: `tests/startup_ui_regression.tscn`. Jalankan dengan NUSA_SAVE_AUDIT=1 dan APPDATA terisolasi yang mengandung nusa-save-audit-. NUSA_STARTUP_SCREENSHOT=1 tanpa --headless menyimpan preview kedua layar di scratch.
