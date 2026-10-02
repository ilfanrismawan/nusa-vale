# Panduan Desain Game: Menanamkan "Sense of Purpose" & Memicu "One More Day Syndrome" di Nusa Vale

Dokumen ini disusun khusus untuk proyek **Nusa Vale** (Farming & Life Simulation RPG berbasis Godot 4). Tujuannya adalah merancang ekosistem gameplay yang membuat pemain merasa memiliki **tujuan hidup yang bermakna (purpose)**, memiliki ikatan emosional dengan dunia game, serta tidak ingin berhenti bermain (*One More Day Syndrome*).

---

## 1. Diagnosis Masalah: Mengapa Pemain Cepat Bosan di Game Farming Sim?

Banyak game simulasi pertanian terjebak dalam masalah **"Grind Hampa"**:
1. **Loop Finansial Tertutup tanpa Arah**: Pemain mencangkul $\rightarrow$ menanam $\rightarrow$ menyiram $\rightarrow$ panen $\rightarrow$ jual di shipping bin $\rightarrow$ dapat uang. Namun pemain kemudian bertanya: *"Untuk apa aku butuh 50.000 koin ini kalau desanya tetap sepi dan tidak ada hal baru yang terjadi?"*
2. **Tidak Ada "Stakes" atau Misi Besar**: Pemain tidak merasa keberadaannya dibutuhkan oleh dunia game.
3. **Loop Harian yang Terlalu Sinkron**: Jika semua hal selesai di hari yang sama, pemain merasa sudah tidak ada urusan lagi dan mudah menutup game.

Kunci game seperti *Stardew Valley*, *Animal Crossing*, atau *Rune Factory* bukan sekadar grafis imut atau cangkul-mencangkul, melainkan **psikologi keterikatan (attachment), progres berjenjang (layered progression), dan antisipasi hari esok (interlocking loops)**.

---

## 2. Fondasi Psikologi: Self-Determination Theory (SDT)

Pemain betah bermain puluhan hingga ratusan jam jika 3 kebutuhan psikologis dasar ini terpenuhi:

```
                  ┌────────────────────────────────────────┐
                  │          SENSE OF PURPOSE              │
                  │   ("Desa Nusa Vale membutuhkanku")     │
                  └──────────────────┬─────────────────────┘
                                     │
         ┌───────────────────────────┼───────────────────────────┐
         ▼                           ▼                           ▼
  [ 1. AUTONOMY ]             [ 2. COMPETENCE ]          [ 3. RELATEDNESS ]
  Bebas memilih peran:        Rasa bertambah mahir:      Koneksi emosional:
  Petani, Koki, Penjelajah,   Upgrade alat, buka bibit   Warga desa, festival,
  Dekorator, Peternak         baru, otomatisasi kerja    gotong royong, budaya
```

### A. Autonomy (Kebebasan Menentukan Jalan Hidup)
- Jangan paksa pemain hanya menjadi petani strawberry. Berikan cabang minat:
  - *Agronomist*: Fokus meneliti silang tanaman, pupuk, dan kualitas bintang emas.
  - *Culinary & Forager*: Memasak kuliner tradisional nusantara dari hasil jelajah hutan.
  - *Artisan / Pengrajin*: Mengolah bahan mentah (kopi mentah $\rightarrow$ kopi sangrai $\rightarrow$ bubuk kopi premium).
  - *Socialite*: Menjalin persahabatan erat dan memecahkan rahasia masa lalu tiap warga desa.

### B. Competence (Rasa Menjadi Semakin Cakap dan Efisien)
- Awal game: Menyiram 20 petak tanah menguras 80% energi dan setengah hari. Pemain merasa lambat tapi gigih.
- Pertengahan: Pemain meng-upgrade alat (Cangkul Tembaga bisa mencangkul $1 \times 3$ petak sekaligus).
- Lanjutan: Pemain membuat saluran irigasi tradisional (sistem Subak) atau sprinkler otomatis.
- **Prinsip**: Kemudahan harus *diperjuangkan*. Saat pekerjaan yang tadinya berat menjadi mudah berkat usaha pemain, otak melepaskan dopamin kepuasan (*mastery*).

### C. Relatedness (Dibutuhkan dan Diterima oleh Komunitas)
- Pemain bukan sekadar penyewa lahan; mereka adalah penyelamat dan jiwa dari Nusa Vale.
- Sentuhan lokal: Budaya **Gotong Royong** dan rasa kekeluargaan yang tulus dari warga desa.

---

## 3. Piramida Purpose 3 Tingkat (Layered Goals)

Rasa bertujuan dibangun dari interaksi tiga lapisan target waktu:

```
               ▲
              / \
             /   \      MACRO-GOAL (Musiman / Sepanjang Game)
            /     \     "Kembalikan Kejayaan Lumbung Adat Nusa Vale"
           /───────\    
          /         \   MESO-GOAL (Mingguan / 1-3 Jam Sesi)
         /           \  "Kumpulkan 3.000 Koin + 50 Kayu Ulin untuk Renovasi Dermaga"
        /─────────────\ 
       /               \ MICRO-GOAL (Harian / 5-15 Menit)
      /                 \ "Hari ini benih melon panen, beli bibit baru, antar pesanan Bu Siti"
     /───────────────────\
```

### Tingkat 1: Micro-Goals (Harian, 5–15 Menit)
Tujuan instan saat pemain membuka matanya di kasur pagi hari:
- *"Tanaman strawberry-ku hari ini panen!"*
- *"Hari ini Selasa, toko bibit buka sampai jam 4 sore, aku harus bergegas."*
- *"Di Papan Pengumuman Desa, Pak RT butuh 3 buah kelapa untuk persiapan upacara besok."*
- *"Hari ini hujan! Aku tidak perlu menyiram tanaman, ini hari yang tepat untuk eksplorasi gua atau memancing ikan langka."*

### Tingkat 2: Meso-Goals (Mingguan / Musiman, 1–3 Jam)
Target jangka menengah yang membuat koin emas dan sumber daya memiliki fungsi krusial:
- **Upgrade Peralatan**: Membutuhkan 2.000 koin + 5 bijih tembaga di Pandai Besi.
- **Pembangunan Fasilitas**: Membangun kandang ayam (butuh kayu, batu, dan koin).
- **Persiapan Festival Musim**:
  - Misalnya: *Festival Sedekah Bumi* di hari ke-24. Pemain berlomba menyiapkan 1 komoditas kualitas tertinggi untuk persembahan lumbung desa demi berkah panen musim depan.
- **Investasi Musiman**: Mengumpulkan modal koin di akhir musim untuk memborong bibit musim berikutnya di hari pertama.

### Tingkat 3: Macro-Goals (Visi Utama Game, Puluhan Jam)
Inilah yang menjawab pertanyaan fundamental pemain: **"Mengapa aku berada di Nusa Vale?"**

#### Rekomendasi Narasi Macro: "Revitalisasi Lumbung Hayat & Membangun Desa Adat"
> *Dahulu Nusa Vale adalah desa subur yang makmur berkat harmoni warganya dan berkah "Pohon Hayat / Lumbung Pusaka". Namun generasi muda merantau ke kota besar, lahan terlantar, fasilitas desa runtuh (jembatan putus, dermaga hancur, mata air tersumbat).*
> 
> *Kakek/keluargamu mewariskan sebidang tanah tua ini. Kepala Desa dan warga menyambutmu dengan harapan: bisakah kamu mengembalikan denyut nadi kehidupan Nusa Vale?*

#### Mekanik: "Papan Pemugaran Desa" (Community Restoration Project)
Mirip Community Center pada Stardew Valley, tetapi dengan nuansa kearifan lokal (Lumbung Gotong Royong):
1. **Bundel Pertanian Tropis**: Sumbangkan 5 Kopi, 5 Kakao, 5 Padi, 5 Kelapa $\rightarrow$ **Hadiah: Buka Sistem Irigasi Parit Sawah**.
2. **Bundel Perkayuan Hutan**: Sumbangkan Kayu Jati & Damar $\rightarrow$ **Hadiah: Perbaikan Jembatan Seberang Jurang** (membuka akses ke Hutan Bambu & Area Tambang Tua).
3. **Bundel Kuliner Desa**: Sumbangkan hidangan tradisional $\rightarrow$ **Hadiah: Toko Kelontong kini mendatangkan pedagang rempah eksotis setiap akhir pekan**.
4. **Bundel Nelayan Pesisir**: Sumbangkan aneka ikan pesisir $\rightarrow$ **Hadiah: Dermaga nelayan aktif kembali**, kapal pedagang antar pulau singgah membawa bibit langka.

Setiap kali satu proyek selesai:
- Lingkungan visual desa berubah secara nyata (jembatan yang tadinya patah kini berdiri kokoh, air sungai yang tadinya keruh menjadi jernih).
- Warga desa menggelar syukuran kecil dan dialog mereka berubah memuji peranmu. Pemain melihat **dampak langsung dari tindakannya**.

---

## 4. Formula "One More Day Syndrome": Siklus yang Saling Bertumpuk (Interlocking Loops)

Mengapa pemain berniat berhenti jam 10 malam tapi tiba-tiba sudah jam 2 subuh? Jawabannya adalah **Overlapping Asynchronous Cycles**:

```
Hari 1: [Tanam Jagung (Panen Hari 5)] ──┐
Hari 2: [Titip Beli Kandang Ayam (Selesai Hari 4)] ────┐
Hari 3: [Upgrade Cangkul di Pandai Besi (Selesai Hari 5)] ──┐
Hari 4: [Kandang Ayam Selesai!] ◄────────────────────────┘
        └─> "Tanggung, besok jagung panen dan cangkulku jadi, main 1 hari lagi deh!"
Hari 5: [Jagung Panen + Cangkul Jadi!] ◄──────────────────┴──────────────────────┘
        └─> "Wah cangkul baru! Coba buat petak baru deh... sekalian beli anak ayam!"
        ... Loop berulang tanpa pernah ada titik kosong ...
```

### Aturan Emas Siklus Tumpang Tindih:
1. **Jangan biarkan semua timer selesai di hari yang sama**: Jika bibit, upgrade bangunan, dan alat selesai di waktu yang berbeda-beda, pemain selalu memiliki alasan untuk melihat apa yang terjadi besok pagi.
2. **Kotak Surat Pagi Hari (Surprise & Anticipation)**: Saat bangun tidur, berikan ikon surat di kotak pos. Surat dari warga berisi hadiah resep, cerita unik, undangan festival, atau pesanan darurat.
3. **Dinamika Cuaca**:
   - Hari Cerah: Hari kerja standar.
   - Hari Hujan: Bonus siram otomatis gratis! Menghemat stamina pemain untuk melakukan petualangan lain.
   - Hari Badai / Kabut: Memunculkan ikan langka, tanaman liar khusus, atau kejadian misterius di desa.

---

## 5. Cita Rasa & Identitas Nusantara (Soul of Nusa Vale)

Agar Nusa Vale tidak terasa seperti "kloning Stardew Valley berbalut nama Indonesia", integrasikan elemen budaya yang organik ke dalam mekanik:

| Fitur | Implementasi Gameplay Unik |
|---|---|
| **Sistem Irigasi Subak / Parit** | Alih-alih hanya sprinkler modern, buat pemain bisa menggali parit kecil yang mengalirkan air dari mata air ke petakan sawah terasering. |
| **Papan Gotong Royong** | Tiap minggu ada kerja bakti membersihkan desa. Membantu warga meningkatkan "Keharmonisan Desa" yang membuka diskon belanja atau bibit spesial. |
| **Tanaman & Rempah Asli** | Padi sawah/gogo, cabai rawit, jahe merah, kunyit, cengkeh, kopi arabika, durian, manggis, kelapa kopyor. |
| **Dapur Tradisional (Tungku/Pawon)** | Mengolah hasil panen menjadi: Nasi Liwet, Sambal Terasi, Wedang Jahe, Es Cendol, Kolak Pisang, Rendang. Memberi buff stamina maksimal, kecepatan jalan, atau ketahanan begadang. |
| **Pasar Kaget / Pasar Malam** | Di hari pasaran tertentu (misal tiap malam Minggu atau siklus 5 harian ala Weton), lapangan desa berubah menjadi pasar malam dengan pedagang keliling menjual furnitur dan bibit langka. |
| **Musik Gamelan / Akustik Santai** | Musik dinamis berganti instrumen bambu/angklung/suling saat sore menjelang malam, memberi rasa relaksasi mendalam (*cozy escapism*). |

---

## 6. Desain Arsitektur Teknis di Godot 4

Untuk mewujudkan sistem purpose ini ke dalam kode GDScript Nusa Vale yang sudah ada (`DayCycle`, `GameState`, `FarmManager`):

### Diagram Modul yang Perlu Ditambahkan:

```
                      ┌──────────────────────┐
                      │    DayCycle.gd       │
                      └──────────┬───────────┘
                                 │ day_passed(day)
                                 ▼
                      ┌──────────────────────┐
                      │    QuestManager.gd   │ ◄── [Papan Pengumuman & Daily Request]
                      └──────────┬───────────┘
                                 │
         ┌───────────────────────┼───────────────────────┐
         ▼                       ▼                       ▼
┌──────────────────┐   ┌───────────────────┐   ┌───────────────────┐
│TownRestoration.gd│   │ NPCFriendship.gd  │   │  GameState.gd     │
│(Lumbung Komunal) │   │ (Relasi & Dialog) │   │  (Uang, Inv, Stat)│
└──────────────────┘   └───────────────────┘   └───────────────────┘
```

### 1. Struktur Blueprint: `TownRestorationManager.gd` (Autoload)
Mengelola status pemugaran desa (Macro-Goals):

```gdscript
extends Node
# Autoload: TownRestoration

signal bundle_completed(bundle_id: String)
signal area_unlocked(area_name: String)

# Status penyelesaian donasi persembahan lumbung desa
var bundles: Dictionary = {
    "jembatan_hutan": {
        "required_items": { "wood": 50, "stone": 20, "money": 1000 },
        "donated_items": { "wood": 0, "stone": 0, "money": 0 },
        "completed": false,
        "reward_description": "Membuka akses jembatan ke Hutan Bambu & Tambang"
    },
    "bibit_rempah": {
        "required_items": { "strawberry": 10, "honey": 2 },
        "donated_items": { "strawberry": 0, "honey": 0 },
        "completed": false,
        "reward_description": "Toko kini menjual bibit Kopi & Rempah"
    }
}

func donate(bundle_id: String, item_id: String, amount: int) -> bool:
    if not bundles.has(bundle_id) or bundles[bundle_id]["completed"]:
        return false
    
    var bundle = bundles[bundle_id]
    if not bundle["required_items"].has(item_id):
        return false
        
    var needed = bundle["required_items"][item_id] - bundle["donated_items"][item_id]
    var actual_donate = mini(needed, amount)
    
    if actual_donate <= 0:
        return false
        
    if GameState.remove_item(item_id, actual_donate):
        bundle["donated_items"][item_id] += actual_donate
        _check_completion(bundle_id)
        return true
    return false

func _check_completion(bundle_id: String) -> void:
    var bundle = bundles[bundle_id]
    for item in bundle["required_items"]:
        if bundle["donated_items"][item] < bundle["required_items"][item]:
            return
            
    bundle["completed"] = true
    bundle_completed.emit(bundle_id)
    print("Selamat! Proyek %s telah selesai!" % bundle_id)
```

### 2. Struktur Blueprint: `DailyQuestManager.gd` (Autoload)
Memberikan micro-goals harian yang di-refresh tiap `DayCycle.day_passed`:

```gdscript
extends Node
# Autoload: QuestManager

signal quests_updated

var active_daily_quests: Array[Dictionary] = []

func _ready() -> void:
    DayCycle.day_passed.connect(_on_new_day)

func _on_new_day(_day_number: int) -> void:
    generate_daily_board_quests()

func generate_daily_board_quests() -> void:
    active_daily_quests.clear()
    # Contoh random generator misi harian
    active_daily_quests.append({
        "id": "quest_1",
        "npc_name": "Pak RT",
        "title": "Bahan Sedekah Desa",
        "item_target": "strawberry",
        "amount_target": 3,
        "reward_money": 120,
        "reward_friendship": 15,
        "description": "Pak RT membutuhkan 3 strawberry segar untuk jamuan tamu desa sore ini."
    })
    quests_updated.emit()
```

---

## 7. Action Plan Checklist (Langkah Kerja Bertahap)

Berikut adalah urutan fitur yang paling efektif untuk dikembangkan agar perubahan langsung terasa:

- [ ] **Fase 1: Memberikan Alasan Belanja (Sink Finansial & Meso-Goal)**
  - Tambahkan upgrade alat (Cangkul Level 2 yang bisa mencangkul beberapa tile).
  - Tambahkan harga mahal untuk ekspansi ransel (misal: 24 slot seharga 1.500 koin) agar pemain punya motivasi mengumpulkan uang panen.
- [ ] **Fase 2: Membangun Narasi & Macro-Goal**
  - Pasang objek "Jembatan Rusak" di map luar rumah dengan papan interaksi: *"Dibutuhkan 50 Kayu dan 500 Koin untuk memperbaiki jembatan menuju Lembah Seberang"*.
  - Buat area di balik jembatan tersebut yang memiliki sumber daya baru (batu tembaga, pohon ulin, ikan air deras).
- [ ] **Fase 3: Papan Pengumuman Harian (Micro-Goal)**
  - Letakkan papan pengumuman kayu di depan toko bibit/balai desa.
  - Setiap hari tampilkan 1–2 permintaan warga dengan batas waktu 2 hari dalam game.
- [ ] **Fase 4: Sistem Hubungan Warga (Relatedness)**
  - Tambahkan dialog unik yang berubah seiring reputasi pemain naik.
  - Berikan hadiah kejutan di kotak surat ketika persahabatan mencapai level tertentu.
- [ ] **Fase 5: Kalender & Festival Desa**
  - Tampilkan kalender di dinding rumah pemain dengan tanggal festival yang dilingkari merah agar pemain selalu mengantisipasi tanggal tersebut.
