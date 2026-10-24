import os

ITEMS = [
    # Beds (Beds.png)
    {
        "id": "single_bed_wood",
        "file": "Beds.png",
        "rect": (0, 0, 32, 48),
        "size": (2, 2),
        "col_size": (28, 16),
        "col_offset": (0, -8),
        "sprite_offset": (0, -24),
        "name": "Tempat Tidur Tunggal Kayu",
        "desc": "Tempat tidur kayu sederhana dan nyaman untuk istirahat satu orang.",
        "price": 350,
        "category": "Beds"
    },
    {
        "id": "double_bed_wood",
        "file": "Beds.png",
        "rect": (96, 0, 48, 48),
        "size": (3, 2),
        "col_size": (44, 16),
        "col_offset": (0, -8),
        "sprite_offset": (0, -24),
        "name": "Tempat Tidur Ganda Kayu",
        "desc": "Ranjang kayu ukuran besar yang luas dan hangat untuk dua orang.",
        "price": 750,
        "category": "Beds"
    },
    {
        "id": "single_bed_blue",
        "file": "Beds.png",
        "rect": (48, 176, 32, 32),
        "size": (2, 2),
        "col_size": (28, 16),
        "col_offset": (0, -8),
        "sprite_offset": (0, -16),
        "name": "Tempat Tidur Biru",
        "desc": "Tempat tidur berseprai biru cerah dengan bantal empuk.",
        "price": 400,
        "category": "Beds"
    },
    {
        "id": "bunk_bed",
        "file": "Beds.png",
        "rect": (192, 0, 32, 64),
        "size": (2, 2),
        "col_size": (28, 16),
        "col_offset": (0, -8),
        "sprite_offset": (0, -32),
        "name": "Tempat Tidur Tingkat",
        "desc": "Ranjang tingkat dua lantai kayu kokoh, hemat ruang kamar.",
        "price": 600,
        "category": "Beds"
    },
    {
        "id": "baby_crib",
        "file": "Beds.png",
        "rect": (0, 144, 32, 32),
        "size": (2, 1),
        "col_size": (28, 12),
        "col_offset": (0, -6),
        "sprite_offset": (0, -16),
        "name": "Boks Bayi",
        "desc": "Tempat tidur bayi dari kayu halus dengan jeruji pengaman.",
        "price": 300,
        "category": "Beds"
    },

    # Chairs & Sofas
    {
        "id": "classic_chair",
        "file": "Chairs.png",
        "rect": (130, 13, 16, 20),
        "size": (1, 1),
        "col_size": (12, 8),
        "col_offset": (0, -4),
        "sprite_offset": (0, -10),
        "name": "Kursi Makan Kayu",
        "desc": "Kursi makan kayu klasik dengan sandaran punggung nyaman.",
        "price": 100,
        "category": "Seating"
    },
    {
        "id": "stool_wood",
        "file": "Chairs.png",
        "rect": (242, 15, 12, 16),
        "size": (1, 1),
        "col_size": (10, 8),
        "col_offset": (0, -4),
        "sprite_offset": (0, -8),
        "name": "Bangku Kayu Bulat",
        "desc": "Bangku kayu kecil bundar tanpa sandaran.",
        "price": 60,
        "category": "Seating"
    },
    {
        "id": "armchair_cozy",
        "file": "Sofa and armchair.png",
        "rect": (0, 0, 32, 32),
        "size": (2, 1),
        "col_size": (24, 12),
        "col_offset": (0, -6),
        "sprite_offset": (0, -16),
        "name": "Kursi Sofa Santai",
        "desc": "Satu dudukan sofa empuk dengan sandaran tangan berlapis kain.",
        "price": 250,
        "category": "Seating"
    },
    {
        "id": "sofa_living",
        "file": "Sofa and armchair.png",
        "rect": (32, 0, 48, 32),
        "size": (3, 1),
        "col_size": (40, 12),
        "col_offset": (0, -6),
        "sprite_offset": (0, -16),
        "name": "Sofa Ruang Tamu",
        "desc": "Sofa dua dudukan berlapis busa empuk yang cocok untuk ruang santai.",
        "price": 450,
        "category": "Seating"
    },
    {
        "id": "sofa_large",
        "file": "Sofa and armchair.png",
        "rect": (80, 0, 64, 32),
        "size": (4, 1),
        "col_size": (56, 12),
        "col_offset": (0, -6),
        "sprite_offset": (0, -16),
        "name": "Sofa Tamu Panjang",
        "desc": "Sofa tiga dudukan panjang untuk menyambut banyak tamu.",
        "price": 650,
        "category": "Seating"
    },

    # Tables & Desks
    {
        "id": "study_desk",
        "file": "Tables and desks.png",
        "rect": (0, 0, 32, 32),
        "size": (2, 1),
        "col_size": (28, 12),
        "col_offset": (0, -6),
        "sprite_offset": (0, -16),
        "name": "Meja Belajar",
        "desc": "Meja kayu kokoh dengan laci untuk menulis dan belajar.",
        "price": 220,
        "category": "Tables"
    },
    {
        "id": "dining_table_wood",
        "file": "Tables and desks.png",
        "rect": (64, 0, 48, 32),
        "size": (3, 1),
        "col_size": (44, 12),
        "col_offset": (0, -6),
        "sprite_offset": (0, -16),
        "name": "Meja Makan Kayu",
        "desc": "Meja makan kayu panjang untuk jamuan makan keluarga.",
        "price": 380,
        "category": "Tables"
    },
    {
        "id": "round_table",
        "file": "Tables and desks.png",
        "rect": (32, 0, 32, 32),
        "size": (2, 1),
        "col_size": (24, 12),
        "col_offset": (0, -6),
        "sprite_offset": (0, -16),
        "name": "Meja Bundar",
        "desc": "Meja bundar kayu mungil yang manis untuk teh sore.",
        "price": 180,
        "category": "Tables"
    },
    {
        "id": "nightstand",
        "file": "Tables and desks.png",
        "rect": (0, 32, 16, 16),
        "size": (1, 1),
        "col_size": (14, 8),
        "col_offset": (0, -4),
        "sprite_offset": (0, -8),
        "name": "Meja Nakas",
        "desc": "Meja nakas kecil di samping kasur untuk menaruh jam atau buku.",
        "price": 90,
        "category": "Tables"
    },

    # Storage & Closets
    {
        "id": "wardrobe_classic",
        "file": "Closet.png",
        "rect": (0, 288, 32, 48),
        "size": (2, 1),
        "col_size": (26, 10),
        "col_offset": (0, -5),
        "sprite_offset": (0, -24),
        "name": "Lemari Pakaian Kayu",
        "desc": "Lemari dua pintu berkapasitas besar untuk baju dan aksesoris.",
        "price": 350,
        "category": "Storage"
    },
    {
        "id": "bookshelf_tall",
        "file": "Closet.png",
        "rect": (0, 0, 32, 48),
        "size": (2, 1),
        "col_size": (26, 10),
        "col_offset": (0, -5),
        "sprite_offset": (0, -24),
        "name": "Rak Buku Tinggi",
        "desc": "Rak buku bertingkat yang rapi untuk koleksi buku bacaan.",
        "price": 320,
        "category": "Storage"
    },
    {
        "id": "kitchen_cabinet",
        "file": "Closet.png",
        "rect": (32, 0, 32, 48),
        "size": (2, 1),
        "col_size": (26, 10),
        "col_offset": (0, -5),
        "sprite_offset": (0, -24),
        "name": "Lemari Dapur",
        "desc": "Lemari dapur untuk menyimpan piring, cangkir, dan perlengkapan makan.",
        "price": 300,
        "category": "Storage"
    },
    {
        "id": "dresser_mirror",
        "file": "Dressers.png",
        "rect": (0, 0, 32, 32),
        "size": (2, 1),
        "col_size": (26, 10),
        "col_offset": (0, -5),
        "sprite_offset": (0, -16),
        "name": "Meja Rias Kaca",
        "desc": "Meja rias dengan cermin jernih dan laci penyimpanan bedak.",
        "price": 280,
        "category": "Storage"
    },
    {
        "id": "dresser_drawers",
        "file": "Dressers.png",
        "rect": (32, 0, 32, 32),
        "size": (2, 1),
        "col_size": (26, 10),
        "col_offset": (0, -5),
        "sprite_offset": (0, -16),
        "name": "Lemari Laci Kayu",
        "desc": "Lemari kabinet serbaguna dengan tiga susun laci geser.",
        "price": 240,
        "category": "Storage"
    },

    # Fireplaces & Lighting
    {
        "id": "fireplace_stone",
        "file": "Fireplace.png",
        "rect": (32, 0, 32, 48),
        "size": (2, 1),
        "col_size": (28, 12),
        "col_offset": (0, -6),
        "sprite_offset": (0, -24),
        "name": "Perapian Batu",
        "desc": "Perapian dari batu alam kokoh yang menghangatkan seisi rumah.",
        "price": 500,
        "category": "Hearth & Light"
    },
    {
        "id": "fireplace_brick",
        "file": "Fireplace.png",
        "rect": (64, 0, 32, 48),
        "size": (2, 1),
        "col_size": (28, 12),
        "col_offset": (0, -6),
        "sprite_offset": (0, -24),
        "name": "Perapian Bata",
        "desc": "Perapian bata merah berhias cerobong asap klasik.",
        "price": 480,
        "category": "Hearth & Light"
    },
    {
        "id": "candle_stand",
        "file": "Candle 1.png",
        "rect": (0, 0, 16, 32),
        "size": (1, 1),
        "col_size": (10, 8),
        "col_offset": (0, -4),
        "sprite_offset": (0, -16),
        "name": "Lilin Meja",
        "desc": "Tempat lilin kuningan berapi tenang pembawa suasana syahdu.",
        "price": 80,
        "category": "Hearth & Light"
    },
    {
        "id": "floor_lamp",
        "file": "Part 1 copiar.png",
        "rect": (80, 0, 16, 48),
        "size": (1, 1),
        "col_size": (10, 8),
        "col_offset": (0, -4),
        "sprite_offset": (0, -24),
        "name": "Lampu Berdiri",
        "desc": "Lampu sudut ruangan bertiang tinggi dengan kap kain lembut.",
        "price": 200,
        "category": "Hearth & Light"
    },

    # Pets
    {
        "id": "cat_tree_tall",
        "file": "cats furniture.png",
        "rect": (0, 0, 32, 64),
        "size": (2, 1),
        "col_size": (24, 12),
        "col_offset": (0, -6),
        "sprite_offset": (0, -32),
        "name": "Pohon Garukan Kucing",
        "desc": "Taman bermain panjat kucing bertingkat kesayangan anabul.",
        "price": 320,
        "category": "Pets"
    },
    {
        "id": "cat_bed",
        "file": "cats furniture.png",
        "rect": (32, 0, 32, 32),
        "size": (2, 1),
        "col_size": (22, 12),
        "col_offset": (0, -6),
        "sprite_offset": (0, -16),
        "name": "Kasur Kucing Bulu",
        "desc": "Bantalan bundar super empuk untuk tidur siang kucing peliharaan.",
        "price": 150,
        "category": "Pets"
    },
    {
        "id": "cat_bowl",
        "file": "cats furniture.png",
        "rect": (64, 0, 16, 16),
        "size": (1, 1),
        "col_size": (12, 8),
        "col_offset": (0, -4),
        "sprite_offset": (0, -8),
        "name": "Mangkuk Kucing",
        "desc": "Mangkuk pakan keramik mungil untuk makanan basah atau biskuit.",
        "price": 50,
        "category": "Pets"
    },

    # Interior & Decor
    {
        "id": "grandfather_clock",
        "file": "Part 1 copiar.png",
        "rect": (0, 0, 16, 48),
        "size": (1, 1),
        "col_size": (14, 10),
        "col_offset": (0, -5),
        "sprite_offset": (0, -24),
        "name": "Jam Bandul Antik",
        "desc": "Jam berdiri kayu antik dengan bandul yang berdentang syahdu.",
        "price": 380,
        "category": "Decor"
    },
    {
        "id": "indoor_plant_large",
        "file": "Part 1 copiar.png",
        "rect": (32, 0, 32, 48),
        "size": (2, 1),
        "col_size": (20, 10),
        "col_offset": (0, -5),
        "sprite_offset": (0, -24),
        "name": "Tanaman Palem Hias",
        "desc": "Tanaman palem hijau rimbun dalam pot keramik elegan.",
        "price": 180,
        "category": "Decor"
    },
    {
        "id": "indoor_plant_small",
        "file": "Part 1 copiar.png",
        "rect": (64, 0, 16, 32),
        "size": (1, 1),
        "col_size": (12, 8),
        "col_offset": (0, -4),
        "sprite_offset": (0, -16),
        "name": "Tanaman Pot Meja",
        "desc": "Pot sukulen mungil yang menyegarkan sudut meja atau rak.",
        "price": 90,
        "category": "Decor"
    },
    {
        "id": "painting_wall",
        "file": "Part 1 copiar.png",
        "rect": (112, 0, 32, 32),
        "size": (2, 1),
        "col_size": (28, 4),
        "col_offset": (0, -2),
        "sprite_offset": (0, -16),
        "name": "Lukisan Pemandangan",
        "desc": "Lukisan pemandangan lembah hijau dengan pigura kayu artistik.",
        "price": 220,
        "category": "Decor"
    },
    {
        "id": "gramophone",
        "file": "Part 1 copiar.png",
        "rect": (144, 0, 32, 32),
        "size": (2, 1),
        "col_size": (24, 12),
        "col_offset": (0, -6),
        "sprite_offset": (0, -16),
        "name": "Gramofon Antik",
        "desc": "Pemutar piringan hitam klasik dengan corong kuningan memukau.",
        "price": 550,
        "category": "Decor"
    },
    {
        "id": "wall_mirror",
        "file": "Part 2 copiar.png",
        "rect": (0, 0, 32, 32),
        "size": (2, 1),
        "col_size": (26, 4),
        "col_offset": (0, -2),
        "sprite_offset": (0, -16),
        "name": "Cermin Dinding",
        "desc": "Cermin dinding berbingkai ukir yang memberi kesan luas pada ruangan.",
        "price": 160,
        "category": "Decor"
    },
    {
        "id": "carpet_rug",
        "file": "Part 2 copiar.png",
        "rect": (64, 0, 48, 32),
        "size": (3, 2),
        "col_size": (44, 28),
        "col_offset": (0, -14),
        "sprite_offset": (0, -16),
        "name": "Karpet Permadani",
        "desc": "Permadani tenun bertekstur empuk penghangat lantai rumah.",
        "price": 250,
        "category": "Decor"
    },
    {
        "id": "wall_shelf",
        "file": "Others.png",
        "rect": (0, 0, 32, 32),
        "size": (2, 1),
        "col_size": (28, 6),
        "col_offset": (0, -3),
        "sprite_offset": (0, -16),
        "name": "Rak Dinding Tempel",
        "desc": "Rak dinding kayu gantung tempat memajang pernak-pernik.",
        "price": 130,
        "category": "Decor"
    },
    {
        "id": "umbrella_stand",
        "file": "Others.png",
        "rect": (32, 0, 16, 32),
        "size": (1, 1),
        "col_size": (12, 8),
        "col_offset": (0, -4),
        "sprite_offset": (0, -16),
        "name": "Tempat Payung",
        "desc": "Wadah payung di samping pintu masuk agar lantai tetap kering.",
        "price": 80,
        "category": "Decor"
    },

    # Special / Institutions
    {
        "id": "school_blackboard",
        "file": "School.png",
        "rect": (0, 0, 48, 32),
        "size": (3, 1),
        "col_size": (44, 8),
        "col_offset": (0, -4),
        "sprite_offset": (0, -16),
        "name": "Papan Tulis Hitam",
        "desc": "Papan tulis kapur lebar untuk catatan belajar atau resep berkebun.",
        "price": 250,
        "category": "Institutions"
    },
    {
        "id": "school_desk",
        "file": "School.png",
        "rect": (48, 0, 32, 32),
        "size": (2, 1),
        "col_size": (28, 12),
        "col_offset": (0, -6),
        "sprite_offset": (0, -16),
        "name": "Bangku Sekolah",
        "desc": "Satu set meja dan bangku kayu khas ruang kelas sekolah.",
        "price": 180,
        "category": "Institutions"
    },
    {
        "id": "grand_bookshelf",
        "file": "University.png",
        "rect": (0, 0, 48, 48),
        "size": (3, 1),
        "col_size": (44, 12),
        "col_offset": (0, -6),
        "sprite_offset": (0, -24),
        "name": "Rak Buku Arsip",
        "desc": "Lemari arsip buku megah perpustakaan penuh ensiklopedia.",
        "price": 450,
        "category": "Institutions"
    },
    {
        "id": "lab_alchemy_desk",
        "file": "University.png",
        "rect": (48, 0, 48, 32),
        "size": (3, 1),
        "col_size": (44, 12),
        "col_offset": (0, -6),
        "sprite_offset": (0, -16),
        "name": "Meja Laboratorium",
        "desc": "Meja riset universitas dilengkapi botol kimia dan mikroskop mini.",
        "price": 420,
        "category": "Institutions"
    },
    {
        "id": "weapon_rack",
        "file": "Blacksmith.png",
        "rect": (0, 0, 32, 48),
        "size": (2, 1),
        "col_size": (28, 10),
        "col_offset": (0, -5),
        "sprite_offset": (0, -24),
        "name": "Rak Senjata Tempa",
        "desc": "Rak kayu kokoh untuk memajang pedang dan perkakas besi.",
        "price": 300,
        "category": "Institutions"
    },
    {
        "id": "temple_bell",
        "file": "Temple.png",
        "rect": (32, 0, 32, 32),
        "size": (2, 1),
        "col_size": (26, 12),
        "col_offset": (0, -6),
        "sprite_offset": (0, -16),
        "name": "Genta Klenteng",
        "desc": "Lonceng perunggu ornamen suci penghias kuil dan ruang meditasi.",
        "price": 360,
        "category": "Institutions"
    }
]

ATLAS_DIR = "resources/interior/atlas"
ITEM_DIR = "resources/item_data"
SCENE_DIR = "scenes/objects/interior"

os.makedirs(ATLAS_DIR, exist_ok=True)
os.makedirs(ITEM_DIR, exist_ok=True)
os.makedirs(SCENE_DIR, exist_ok=True)

for it in ITEMS:
    item_id = it["id"]
    file = it["file"]
    rx, ry, rw, rh = it["rect"]
    sx, sy = it["size"]
    cw, ch = it["col_size"]
    cox, coy = it["col_offset"]
    sox, soy = it["sprite_offset"]
    name = it["name"]
    desc = it["desc"]
    price = it["price"]

    # 1. AtlasTexture .tres
    atlas_content = f"""[gd_resource type="AtlasTexture" format=3]

[ext_resource type="Texture2D" path="res://assets/farm_rpg/objects/interior/{file}" id="1_tex"]

[resource]
atlas = ExtResource("1_tex")
region = Rect2({rx}, {ry}, {rw}, {rh})
filter_clip = true
"""
    with open(f"{ATLAS_DIR}/{item_id}.tres", "w", encoding="utf-8") as f:
        f.write(atlas_content)

    # 2. ItemData .tres
    item_content = f"""[gd_resource type="Resource" script_class="ItemData" format=3]

[ext_resource type="Script" path="res://scripts/data/item_data.gd" id="1_item"]
[ext_resource type="Texture2D" path="res://resources/interior/atlas/{item_id}.tres" id="2_icon"]

[resource]
script = ExtResource("1_item")
item_id = "{item_id}"
display_name = "{name}"
category = 8
icon = ExtResource("2_icon")
description = "{desc}"
placeable = true
placement_size = Vector2i({sx}, {sy})
sell_price = {price}
"""
    with open(f"{ITEM_DIR}/{item_id}.tres", "w", encoding="utf-8") as f:
        f.write(item_content)

    # 3. Object Scene .tscn
    scene_content = f"""[gd_scene format=3]

[ext_resource type="Texture2D" path="res://resources/interior/atlas/{item_id}.tres" id="1_tex"]

[sub_resource type="RectangleShape2D" id="BodyShape"]
size = Vector2({cw}, {ch})

[node name="{item_id}" type="StaticBody2D"]
y_sort_enabled = true

[node name="Sprite2D" type="Sprite2D" parent="."]
position = Vector2({sox}, {soy})
texture = ExtResource("1_tex")

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
position = Vector2({cox}, {coy})
shape = SubResource("BodyShape")
"""
    with open(f"{SCENE_DIR}/{item_id}.tscn", "w", encoding="utf-8") as f:
        f.write(scene_content)

print(f"Generated {len(ITEMS)} atlas textures, item data resources, and scenes successfully.")

# 4. Generate Gallery Scene
gallery_lines = [
    '[gd_scene format=3]',
    ''
]
for i, it in enumerate(ITEMS):
    item_id = it["id"]
    gallery_lines.append(f'[ext_resource type="PackedScene" path="res://scenes/objects/interior/{item_id}.tscn" id="{i+1}"]')

gallery_lines.append('')
gallery_lines.append('[node name="InteriorObjectGallery" type="Node2D"]')
gallery_lines.append('y_sort_enabled = true')
gallery_lines.append('')

# Place them in a grid: 6 items per row, spacing x=80, y=90
for i, it in enumerate(ITEMS):
    row = i // 6
    col = i % 6
    pos_x = 60 + col * 90
    pos_y = 60 + row * 90
    gallery_lines.append(f'[node name="{it["id"]}" parent="." instance=ExtResource("{i+1}")]')
    gallery_lines.append(f'position = Vector2({pos_x}, {pos_y})')
    gallery_lines.append('')

with open(f"{SCENE_DIR}/interior_object_gallery.tscn", "w", encoding="utf-8") as f:
    f.write("\n".join(gallery_lines))

print("Generated interior_object_gallery.tscn successfully.")
