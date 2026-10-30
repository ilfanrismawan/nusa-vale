# Mengatur Satwa dan Horor di editor

- UI inventory: buka `scenes/ui/inventory_settings.tscn`. Bagian Horor dan Satwa berada di `Pages/Left/Horror` dan `Pages/Left/Wildlife`; catatannya di `Pages/Right/HorrorJournal` dan `WildlifeJournal`. Edit teks, posisi, ukuran, dan scale langsung di Inspector. Pilihan kesulitan tetap diisi dari katalog game.
- Satwa di peta: pilih node `WildlifeSpawner` pada scene Farm, Forest, DeepForest, atau mountain. Atur `enabled`, `location_id`, `max_animals`, `species`, jarak pemain, dan path layer di Inspector. Resource pada daftar species menyimpan musim, jam, bobot kemunculan, makanan, dan tampilan satwa. Scene dasar: `scenes/world/wildlife_spawner.tscn`.
- Progres horor: buka `scenes/horror/horror_settings.tscn`. Node Horror menyediakan katalog `profiles` dan `difficulties`, jadwal Kliwon, serta batas pencurian Tuyul. Buka resource profil/kesulitan dari Inspector untuk mengubah nilainya. GameState memakai scene ini saat mulai.
- Efek malam: buka `scenes/effects/night_horror.tscn`, pilih NightHorror. Pengaturan rasa takut, suara, layar, kejadian, dan penunggu tersedia di Inspector.
- Teks menu/inventory memakai `assets/fonts/m5x7.ttf` dengan ukuran dasar 16. Gunakan scale, posisi, dan ruang layout untuk menyesuaikan ukuran visual.

Pengaturan konten di scene/resource tidak mengganti pilihan kesulitan atau aksesibilitas yang sudah tersimpan oleh pemain.
