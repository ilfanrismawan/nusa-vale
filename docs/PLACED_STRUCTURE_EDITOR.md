# Mengedit placed structure dan balon hasil

Buka `scenes/objects/placed_structure.tscn` di editor Godot. Scene ini dipakai StructureManager untuk objek yang ditempatkan pemain, termasuk furnace dan keg.

- `ReadyBubble/Background`: ubah Texture dan Region > Rect, atau gunakan Region Editor untuk memilih gambar pada spritesheet. Offset, Position, Scale, dan Modulate juga bisa diedit.
- `ReadyBubble/ProductIcon`: atur posisi dan scale ikon di dalam balon. Secara default texture mengikuti item hasil produksi.
- `ReadyBubble`: atur Position sebagai offset dasar dan Scale untuk ukuran keseluruhan balon.
- Node utama `PlacedStructure`, grup **Balon Hasil Produksi**: aktif/nonaktifkan balon, atur faktor tinggi terhadap mesin, amplitudo dan kecepatan gerakan melayang, serta ukuran ikon produk.

Untuk memakai ikon tetap, matikan **Use Product Icon** pada node utama, lalu isi Texture pada `ReadyBubble/ProductIcon`. Untuk posisi balon sepenuhnya dari scene, set **Ready Height Factor** ke 0; untuk balon diam, set **Ready Bob Amplitude** ke 0.

Background bawaan memakai `assets/farm_rpg/ui/dialogue box.png`, Region `Rect2(96, 64, 16, 16)`, scale 1.5 (ukuran balon 24×24 piksel). Ikon produk berada di layer depan (`z_index = 1`), di tengah isi balon. `Ready Icon Size` mengatur ukuran ikon tanpa mengubah ukuran background.

Grup **Juice Balon** mengatur animasi muncul (pop, overshoot, squash/stretch), denyut dan goyangan halus ketika produk siap, serta gerakan naik dan fade saat produk diambil. Matikan `Bubble Juice Enabled` untuk tampilan langsung tanpa transisi tersebut. Posisi, scale, rotation, dan modulate dasar dari scene tetap dipertahankan. `Ready Bob Amplitude` dan `Ready Bob Speed` mengatur gerakan melayang secara terpisah; gerakan berhenti mengikuti pause game.

Node **ReadySound** mengatur SFX sekali saat produk pertama terdeteksi siap. Ubah `Stream`, `Volume dB`, `Max Distance` (radius dengar, bawaan 160 piksel), dan `Attenuation` di Inspector. Matikan `Enabled` pada script node ini untuk menonaktifkan SFX. Pemain harus berada di radius tersebut dan dunia 2D yang sama pada saat kejadian; selesai saat jauh tidak mengantrekan suara untuk diputar ketika pemain mendekat. Pengecekan hanya memakai karakter Player, sehingga wrapper scene di titik asal peta tidak membuat suara keliru. Furnace mandiri juga menyediakan node ReadySound dengan aturan jarak yang sama.

`Crop Product Sheet` mengambil satu frame dari gambar ikon mentah yang berisi beberapa sprite. Atur `Product Frame Size` (bawaan 16×16) dan `Product Frame` (kolom, baris; mulai dari 0) di Inspector. Ikon berupa `AtlasTexture` tetap mengikuti potongan yang sudah diatur pada resource item. Untuk mengubah gambar produk tertentu, edit properti `icon` pada `resources/item_data/<produk>.tres`.

Balon terlihat di editor untuk memudahkan pengaturan. Saat game berjalan, balon hanya muncul jika mesin memiliki hasil siap diambil. Perubahan scene berlaku pada semua placed structure yang memakai scene ini; tidak perlu membuat save baru.

Sprite objek dan ukuran tabrakan tetap disesuaikan otomatis dengan jenis item. Warna/jumlah partikel dan cahaya dapat berubah mengikuti status mesin. Scene furnace mandiri `scenes/objects/furnace.tscn` memakai sistem terpisah.
