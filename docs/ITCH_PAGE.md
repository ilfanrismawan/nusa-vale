# Halaman itch.io — draf dan checklist upload

Pembaruan: 3 November 2026. Draf teks halaman Nusa Vale di itch.io; ubah bebas sebelum dipakai.
Gambar halaman ada di `docs/itch/` (cover, screenshot, GIF).

## Pengaturan halaman

- **Kind of project**: Downloadable. Rilis Windows dulu (preset `Windows Desktop` atau `Windows Demo`). Preset Web dan macOS belum diuji.
- **Classification**: Games. **Release status**: In development (alpha).
- **Genre**: Simulation. **Tags**: farming, life-sim, pixel-art, cozy, local-co-op, split-screen, horror, indonesia, fishing, dungeon.
- **Languages**: Indonesian (seluruh UI dan dialog berbahasa Indonesia).
- **Inputs**: Keyboard, Mouse, Xbox/USB controller (co-op lokal).
- **AI generation disclosure**: Yes. Musik dibuat dengan Google Gemini; sebagian gambar dan efek suara dibuat dengan bantuan AI (sesuai layar Kredit).
- **Cover image**: `docs/itch/cover_630x500.png` (630×500).
- **Screenshots**: `docs/itch/screenshot_*.png` (1280×720). Itch menampilkan 3–5 screenshot di samping deskripsi.
- **GIF**: `docs/itch/gameplay.gif` dapat dimasukkan ke deskripsi (itch mendukung GIF animasi di badan halaman).

## Deskripsi (Bahasa Indonesia)

**Nusa Vale** adalah game bertani dan kehidupan desa bergaya pixel art dengan nuansa Nusantara.
Warisi sebidang lahan di lembah, tanam sayur dan buah, rawat ternak, kenali warga desa, lalu jelajahi
hutan dan gua tambang. Tapi hati-hati: lewat tengah malam, lembah tidak sepenuhnya sepi.

- **Bertani & beternak**: cangkul, tanam, siram, panen; kandang ayam dan barn, rumah kaca, mesin pengolah hasil panen.
- **Memancing, memasak, mengumpulkan**: sungai, kolam, dan laut; resep masakan dengan efek makanan.
- **Upgrade alat & rumah**: tempa bijih di tungku, tingkatkan alat dan perluas rumah.
- **Warga desa**: jadwal harian, hadiah kesukaan, dan kisah persahabatan.
- **Gua & pertarungan**: turun lantai demi lantai, lawan monster dan boss.
- **Horor tengah malam**: makhluk legenda Nusantara muncul setelah pukul 00.00 (bisa diatur atau dimatikan di Pengaturan).
- **Co-op lokal layar terbagi**: main berdua di satu PC dengan controller.

Versi ini masih **alpha**: konten, keseimbangan ekonomi, dan teks masih terus diperbarui. Save tersimpan otomatis saat tidur.

## Description (English)

**Nusa Vale** is a pixel-art farming and village life game inspired by the Indonesian archipelago.
Inherit a plot of land in the valley, grow crops, raise animals, befriend the villagers and explore the
forest and mines. But be careful: after midnight, the valley is not as quiet as it seems.

Farming and livestock, fishing, cooking, tool and house upgrades, villager friendships, a mine with
monsters and bosses, optional midnight horror featuring Indonesian folklore, and local split-screen co-op.

**Note:** the game is currently in **Indonesian only**. Alpha build; progress saves when you sleep.

## Kontrol

| Aksi | Keyboard / mouse | Controller |
|---|---|---|
| Jalan | WASD | D-pad / stik kiri |
| Lari | Shift (tahan) | RT (tahan) |
| Pakai alat / serang | Klik kiri / C | X |
| Interaksi / bicara | E / X / klik kanan | A |
| Ganti slot alat | Roda mouse / panah kiri-kanan / 1–8 | LB / RB |
| Halaman hotbar | Tab | Back |
| Tas / menu | I / Esc | B / Start |
| Rapikan tas | R | Klik stik kanan |
| Peta lembah | M | — |
| Siul peliharaan | Q | Klik stik kiri |
| Lompat | Spasi | A |
| Combat: roll / tangkis / lock-on / Weapon Art | Spasi / klik kanan / Q / F | B / LB / klik stik kanan / LT |

Sumber: `scripts/player/input_layout.gd`. Tombol bisa diubah pemain di Pengaturan.

## Kredit (salin dari layar Kredit)

- Dibuat oleh Awenk Jaya Kusuma
- Grafis: Tiny Farm RPG Asset Pack oleh Maeve Devs; Castle Mountain Path oleh PIXEL_1992; gambar tambahan dibuat untuk Nusa Vale, sebagian dengan bantuan AI
- Musik: dibuat dengan Google Gemini
- Efek suara: Kenney (CC0); efek tambahan dibuat untuk Nusa Vale, sebagian dengan bantuan AI
- Font: m5x7 oleh Daniel Linssen (CC0)
- Engine: Godot Engine (MIT)

Belum dicek: apakah sprite musuh, NPC, dan hewan di `assets/farm_rpg` berasal dari paket Maeve Devs lain
yang perlu disebut terpisah, serta ketentuan pemakaian komersial musik Gemini.

## Checklist sebelum menekan Publish

1. Export ulang `Windows Desktop` (dan `Windows Demo` bila dirilis) dari editor setelah `git pull`.
2. Jalankan exe hasil export: jendela terbuka normal (bukan minimize), menu utama, mulai game baru, tidur sekali (save), keluar, Lanjutkan.
3. Zip folder build (`NusaVale.exe` + `NusaVale.pck`), atau upload dengan butler:
   `butler push ../nusa-build/windows <user>/nusa-vale:windows --userversion 0.1.0`
4. Isi AI disclosure, bahasa, tag, dan input di halaman itch.
5. Atur halaman sebagai Draft / Restricted dulu, unduh dari itch dan coba sekali, baru Public.
