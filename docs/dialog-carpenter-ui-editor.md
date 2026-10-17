# Dialog NPC dan pertukangan

## Scene yang dapat diedit

- `scenes/ui/npc_dialog_ui.tscn`: potret, panel dialog, nama, peran, area teks bergulir, nomor halaman, tombol lanjut/tutup. Pilih root untuk mengubah teks tombol, petunjuk kontrol, dan ukuran desain.
- `scenes/ui/carpenter_menu.tscn`: potret penjual, katalog bangunan, panel rincian, bahan, saldo, dan tombol pilih lokasi.
- `scenes/ui/carpenter_building_card.tscn`: template kartu bangunan.
- `scenes/ui/blacksmith_material_row.tscn`: template baris bahan yang digunakan bersama blacksmith.
- `resources/ui/carpenter_presentation.tres`: nama default, sapaan, gambar pengganti, urutan bangunan, pesan ketersediaan, dan warna jumlah bahan.
- `resources/ui/cooking_theme.tres`: tema bersama. Jadikan subresource lokal bila hanya ingin mengubah satu scene.

Semua posisi dan ukuran kontrol berasal dari node scene, bukan pembuatan layout melalui script. Root Design diskalakan proporsional terhadap viewport, termasuk viewport co-op.

## Data dan perilaku

Nama, peran, potret, dan isi percakapan tetap berasal dari Inspector NPC (`VillageNPC`). Carpenter menerima nama/potret NPC yang berinteraksi; gambar pengganti pada resource presentation memiliki prioritas.

Ikon, nama, deskripsi dan ukuran bangunan berasal dari resource ItemData bangunan. Harga/bahan tetap mengikuti sumber ekonomi yang sudah ada, yaitu `StructureManager.CONSTRUCTION` (belum dipindahkan menjadi resource oleh perubahan UI ini). UI tidak menyalin harga atau kebutuhan bahan.

Memilih kartu tidak membayar apa pun. Pilih lokasi hanya membuka BuildingPlacement; biaya dibayar pada konfirmasi lokasi. Batal tetap gratis. Enter menjalankan aksi, Esc menutup; navigasi controller memakai perangkat milik pemain yang membuka UI.

Dialog panjang dapat digulir; E/Enter melanjutkan halaman. Penutupan atau penghapusan scene melepaskan kunci kontrol pemain.

## Pengujian

Gunakan APPDATA terisolasi dan NUSA_SAVE_AUDIT=1 untuk menjalankan `tests/dialog_carpenter_ui_regression.tscn`, `tests/npc_interaction_regression.tscn`, `tests/service_ui_regression.tscn`, dan `tests/carpenter_regression.tscn`.
NUSA_UI_SCREENSHOT=1 pada regresi UI (tanpa --headless) menyimpan preview di scratch.
