# Balai Nadi: papan paket kontribusi

UX terinspirasi alur community-center: pilih sayap, pilih paket, periksa slot kebutuhan, pilih bahan dan jumlah, lalu sumbangkan. Tampilan tetap memakai identitas Balai Nadi, aset project dan tema krem–olive; bukan salinan aset game lain.

## Edit di Godot

- `scenes/ui/balai_nadi_ui.tscn`: layout utama, sidebar sayap, daftar paket, detail, jumlah, status, hadiah dan stamp selesai.
- `scenes/ui/balai_wing_button.tscn`: tombol kategori sayap.
- `scenes/ui/balai_bundle_card.tscn`: ikon, nama pendek dan progres paket.
- `scenes/ui/balai_requirement_card.tscn`: ikon bahan, jumlah terkumpul, indikator progres dan tanda terpenuhi.
- `resources/ui/balai_nadi_presentation.tres`: urutan/nama sayap, ikon default/dana serta pesan sayap kosong.
- `resources/restoration/balai_nadi_catalog.tres`: daftar resource proyek aktif. Tambah resource RestorationProject di sini untuk menambah paket tanpa mengedit script UI.
- Resource proyek mengekspos requirements, wing_id, display_name, ui_short_name, ui_icon, reward_items dan completion_message.

ID proyek dan ID item harus stabil dan unik agar sesuai save. Wing ID kosong masuk Balai Utama; all dipakai sebagai kategori UI semua paket. Untuk sayap baru tambahkan ID dan label pada presentation.

Root UI mengekspos template scene, ukuran desain dan batas empat kartu per halaman. Semua posisi/ukuran berasal dari node scene. Tidak ada dropdown atau daftar yang harus digulir; paket dan kebutuhan tambahan memakai pagination.

Hover memakai highlight tema tanpa popup tooltip yang menutupi papan. Deskripsi, sisa/tersedia bahan terpilih dan hadiah tetap ditampilkan di panel detail. Style hover dapat diubah pada tema atau Theme Overrides kartu di editor.

## Alur kontribusi

Klik kartu/slot hanya memilih, tidak mengambil barang. Tombol Sumbangkan mengirim jumlah yang terlihat di SpinBox; Maks. mengisi batas bahan yang tersedia dan sisa kebutuhan. Bahan yang belum dimiliki tetap dapat diperiksa. Jika bahan lengkap akibat pengurangan kebutuhan skill, Selesaikan Paket meneruskan proses ke backend yang sama.

Progres dibagi bersama. Tas yang dipakai selalu milik pemain pembuka papan; dana diambil dari saldo bersama. Sumbangan tetap melalui transaksi BalaiNadiManager, termasuk autosave dan rollback jika save gagal. Proyek berbeda tetap independen.

Hadiah mengikuti reward_items, pesan fasilitas dan Token Talenta backend. Hadiah otomatis pada kontribusi terakhir; UI tidak menambah aksi klaim terpisah dan tidak menggandakan pembayaran/hadiah. Paket selesai mendapat stamp dan tidak dapat disumbang ulang.

Sayap tanpa proyek aktif menampilkan pesan kosong yang jelas, bukan paket atau unlock fiktif. Paket awal tetap restorasi balai, greenhouse dan bundel serangga.

## Tes

Jalankan dengan NUSA_SAVE_AUDIT=1 dan APPDATA terisolasi yang mengandung nusa-save-audit-:

- `tests/balai_bundle_ui_regression.tscn`
- `tests/balai_nadi_regression.tscn`
- `tests/greenhouse_regression.tscn`
- `tests/balai_wings_regression.tscn`

NUSA_BALAI_UI_SCREENSHOT=1 pada tes UI tanpa --headless menyimpan preview papan dan paket selesai di scratch.
