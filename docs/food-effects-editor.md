# Mengatur manfaat, buff, dan debuff makanan

126 item FOOD memiliki stamina_restore dan referensi food_effects. Sebelas bahan olahan resep seperti tepung, adonan, dan mentega tetap MATERIAL; bukan hidangan yang dimakan.

## Mengedit satu makanan

1. Buka ItemData makanan di resources/item_data.
2. Ubah stamina_restore untuk pemulihan langsung.
3. Buka array food_effects, lalu pilih resource efek dari resources/cooking/effects atau buat FoodEffectData baru.
4. Gunakan Make Unique pada resource efek bila perubahan hanya boleh memengaruhi satu makanan. Mengubah resource bersama akan memengaruhi seluruh makanan yang merujuknya.
5. Edit Label FoodEffectsLabel pada scenes/ui/hud.tscn untuk posisi dan tampilan indikator efek aktif.

Resep dan detail inventory menampilkan angka efek dari resource yang sama dengan simulasi gameplay. HUD menampilkan nama efek, jumlah stack, dan sisa waktu. Description merupakan penjelasan bebas; bukan rumus simulasi.

## Parameter FoodEffectData

| Field | Arti |
| --- | --- |
| id | Identitas efek untuk penumpukan; tidak bergantung ID/nama makanan |
| display_name / description | Nama HUD dan penjelasan di Inspector |
| duration_seconds | Durasi dalam detik gameplay aktif |
| movement_multiplier | 1 netral, 1.15 lebih cepat 15%, 0.9 lebih lambat 10% |
| stamina_cost_multiplier | 1 netral, 0.8 hemat 20%, 1.1 boros 10% pada spend_stamina |
| stamina_per_tick | Positif memulihkan, negatif menguras stamina |
| tick_interval | Jarak antar tick dalam detik |
| stacking | REFRESH, REPLACE, atau STACK |
| max_stacks | Batas tumpukan untuk mode STACK |

REFRESH memperbarui efek dengan ID sama, menjaga sisa durasi terpanjang, dan tidak menambah kekuatan. REPLACE mengganti efek serta memulai ulang durasi dan jam tick. STACK menambah tumpukan sampai max_stacks sambil memperbarui durasi. Setiap pemasangan menyalin konfigurasi resource; perubahan saat game berjalan berlaku pada konsumsi berikutnya.

Efek dengan ID berbeda berjalan bersamaan. Multiplier gerak dan biaya stamina dikalikan; kekuatan tiap efek berpangkat jumlah stack. Pemulihan/pengurasan setiap tick dikalikan stack. Stamina selalu dibatasi antara 0 dan max_stamina. Penghematan pecahan diakumulasi agar diskon juga berfungsi pada aksi berbiaya 1 stamina.

## Profil awal

| Profil | Manfaat / konsekuensi |
| --- | --- |
| balanced | Gerak +5%, biaya stamina -5%, 90 detik |
| refreshing | Gerak +15%, 60 detik |
| steady_work | Biaya stamina -20%, 120 detik |
| warming | Biaya -10%, +1 stamina/8 detik, 120 detik |
| protein | Biaya -15%, +1 stamina/10 detik, 100 detik |
| hearty | Biaya -20%, gerak -5%, 120 detik |
| caffeine | Gerak +20%, biaya +10%, 90 detik |
| sugar_rush | Gerak +15%, biaya +15%, 45 detik |
| spicy | Gerak +12%, -1 stamina/8 detik, 64 detik |
| fried_heaviness | Gerak -8%, biaya +5%, 60 detik |
| cooling | Gerak +8%, biaya -5%, 75 detik |
| herbal | +2 stamina/6 detik, 90 detik |
| seafood | Gerak +5%, biaya -15%, 90 detik |
| bread_energy | Biaya stamina -10%, 90 detik |
| fermented | Biaya -15%, +1 stamina/10 detik, 100 detik |

Semua angka di tabel adalah konfigurasi awal pada .tres dan dapat diubah lewat Inspector. Tidak ada pemetaan nama makanan ke efek di kode runtime.
