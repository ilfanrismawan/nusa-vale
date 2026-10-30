"""Generator interior rumah warga Town (pola sama dengan ubay_home.tscn).

Jalankan dari root proyek: python tools/gen_resident_homes.py
Menulis scenes/world/interior/town/<rumah>.tscn. Setiap rumah: lantai/dinding/bingkai TileMapLayer,
tabrakan dinding, hiasan dinding & lantai, perabot (StaticBody2D + bayangan), kursi duduk, pencahayaan,
pemain, pintu keluar, dan ResidentRoom (titik & jalur NPC penghuni).
"""
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "scenes/world/interior/town"

SHEETS = {
    "beds": "res://assets/farm_rpg/objects/interior/Beds.png",
    "dressers": "res://assets/farm_rpg/objects/interior/Dressers.png",
    "tables": "res://assets/farm_rpg/objects/interior/Tables and desks.png",
    "sofa": "res://assets/farm_rpg/objects/interior/Sofa and armchair.png",
    "fireplace": "res://assets/farm_rpg/objects/interior/Fireplace.png",
    "smith": "res://assets/farm_rpg/objects/interior/Blacksmith.png",
    "part1": "res://assets/farm_rpg/objects/interior/Part 1 copiar.png",
    "part11": "res://assets/farm_rpg/objects/interior/Part 11 copiar.png",
    "others": "res://assets/farm_rpg/objects/interior/Others.png",
    "doors": "res://assets/farm_rpg/objects/interior/Doors, windows and curtains.png",
    "box": "res://assets/farm_rpg/objects/exterior/Box.png",
}

# Blok warna dinding (4 tile) di Tileset House: kolom kiri/tengah/kanan = 4b+1..4b+3.
WALL_BLOCK = {"peach": 0, "rose": 1, "slate": 2, "white": 3, "pink": 4, "magenta": 5, "tan": 6,
              "cream": 7, "teal": 8, "blue": 9, "orange": 10, "brown": 11, "yellow": 12}
# Pola dinding = (baris atas, baris bawah) di tileset.
WALL_STYLE = {"plain": (6, 7), "vstripe": (10, 11), "hstripe": (14, 15)}

# Bingkai gelap (atlas Tileset House), sama dengan rumah Ubay.
F_TL, F_TOP, F_TR, F_SIDE = (1, 0), (2, 3), (3, 0), (0, 1)
F_BL, F_BR, F_DOOR_L, F_DOOR_R = (1, 2), (3, 2), (3, 3), (1, 3)
WINDOW = [(41, 2), (42, 2), (43, 2)]
DOOR_COLS = (14, 15)  # lorong pintu x 224..256
FLOOR_BOTTOM = 15     # baris lantai terakhir; lorong di baris 16-17


def tilemap(cells):
    data = bytearray(struct.pack("<H", 0))
    for (x, y), (ax, ay) in cells:
        data += struct.pack("<hhhhhh", x, y, 0, ax, ay, 0)
    return "PackedByteArray(" + ", ".join(str(b) for b in data) + ")"


class Scene:
    def __init__(self):
        self.ext = {}
        self.subs = []
        self.nodes = []
        self.shape_ids = {}

    def res(self, kind, path):
        key = (kind, path)
        if key not in self.ext:
            self.ext[key] = f"r{len(self.ext) + 1}"
        return f'ExtResource("{self.ext[key]}")'

    def tex(self, sheet):
        return self.res("Texture2D", SHEETS[sheet])

    def rect(self, w, h):
        key = (w, h)
        if key not in self.shape_ids:
            sid = f"Rect_{len(self.shape_ids) + 1}"
            self.shape_ids[key] = sid
            self.subs.append(f'[sub_resource type="RectangleShape2D" id="{sid}"]\nsize = Vector2({w:g}, {h:g})\n')
        return f'SubResource("{self.shape_ids[key]}")'

    def node(self, header, **props):
        lines = [header]
        for k, v in props.items():
            lines.append(f"{k} = {v}")
        self.nodes.append("\n".join(lines) + "\n")

    def text(self):
        out = ['[gd_scene format=3]\n']
        for (kind, path), rid in self.ext.items():
            out.append(f'[ext_resource type="{kind}" path="{path}" id="{rid}"]')
        out.append("")
        out.extend(self.subs)
        out.extend(self.nodes)
        return "\n".join(out)


def v(x, y):
    return f"Vector2({x:g}, {y:g})"


def rect2(r):
    return f"Rect2({r[0]}, {r[1]}, {r[2]}, {r[3]})"


def sprite(s, name, parent, sheet, region, pos=None, z=None):
    props = {}
    if pos is not None:
        props["position"] = v(*pos)
    if z is not None:
        props["z_index"] = z
    props.update({"texture_filter": 1, "texture": s.tex(sheet), "offset": v(0, -region[3] / 2),
                  "region_enabled": "true", "region_rect": rect2(region)})
    s.node(f'[node name="{name}" type="Sprite2D" parent="{parent}"]', **props)


def furniture(s, item):
    """item: dict name, sheet, region, pos, [solid=True], [on=[(name, sheet, region, (dx,dy))]], [message]."""
    name, region = item["name"], item["region"]
    w, h = region[2], region[3]
    props = {"position": v(*item["pos"])}
    if item.get("message"):
        props["script"] = s.res("Script", "res://scripts/world/school_notice.gd")
        props["message"] = '"' + item["message"].replace('"', '\\"') + '"'
    s.node(f'[node name="{name}" type="StaticBody2D" parent="Perabot"]', **props)
    s.node(f'[node name="Shadow" type="Sprite2D" parent="Perabot/{name}"]', z_index=-1, position=v(0, -1),
           scale=v(round(w / 24.6, 3), 0.6), texture=s.res("Texture2D", "res://resources/world/shop_fx/soft_shadow.tres"))
    sprite(s, "Sprite2D", f"Perabot/{name}", item["sheet"], region)
    if item.get("solid", True):
        cw, ch = max(4, w - 4), item.get("depth", min(10, max(4, h // 3)))
        s.node(f'[node name="CollisionShape2D" type="CollisionShape2D" parent="Perabot/{name}"]',
               position=v(0, -ch / 2), shape=s.rect(cw, ch))
    for child_name, sheet, reg, (dx, dy) in item.get("on", []):
        sprite(s, child_name, f"Perabot/{name}", sheet, reg, (dx, dy))
    if item.get("light"):
        color, energy, scale = item["light"]
        s.node(f'[node name="Cahaya" type="PointLight2D" parent="Perabot/{name}"]', position=v(0, -h / 2),
               color=color, energy=energy, texture=s.res("Texture2D", "res://resources/world/shop_fx/light_radial.tres"),
               texture_scale=scale)


def build(house):
    s = Scene()
    L, R, T = house["L"], house["R"], house["T"]
    B = FLOOR_BOTTOM
    left_px, right_px = 16 * L, 16 * (R + 1)
    top_px = 16 * T
    wall_top_row = T - 2
    # Sumber dasar
    s.res("Script", "res://scripts/world/node_interior.gd")
    tileset = s.res("TileSet", "res://resources/world/house_interior_tileset.tres")
    s.subs.append('[sub_resource type="ShaderMaterial" id="FloorWear"]\nshader = ' + s.res("Shader", "res://shaders/floor_wear.gdshader")
                  + f'\nshader_parameter/grime_color = {house["grime"]}\nshader_parameter/block_size = 2.0\n'
                  'shader_parameter/grime_strength = 0.12\nshader_parameter/stain_strength = 0.18\nshader_parameter/stain_scale = 28.0\n')
    s.subs.append('[sub_resource type="ShaderMaterial" id="VignetteMaterial"]\nshader = ' + s.res("Shader", "res://shaders/room_vignette.gdshader")
                  + '\nshader_parameter/vignette_color = Color(0.09, 0.04, 0.05, 1)\nshader_parameter/strength = 0.42\n'
                  'shader_parameter/inner_radius = 0.55\nshader_parameter/outer_radius = 1.2\n')
    s.node(f'[node name="{house["node"]}" type="Node2D"]', y_sort_enabled="true",
           script=s.res("Script", "res://scripts/world/node_interior.gd"), room_title=f'"{house["title"]}"', default_zoom="2.0")

    # Lantai (+ lorong pintu)
    floor = [((x, y), house["floor"]) for y in range(T, B + 1) for x in range(L, R + 1)]
    floor += [((x, y), house["floor"]) for y in (B + 1, B + 2) for x in DOOR_COLS]
    s.node('[node name="Lantai" type="TileMapLayer" parent="."]', z_index=-12, material='SubResource("FloorWear")',
           texture_filter=1, tile_map_data=tilemap(floor), tile_set=tileset)
    # Dinding 2 baris
    b = WALL_BLOCK[house["wall"]] * 4
    top_row, bottom_row = WALL_STYLE[house["wall_style"]]
    window_x = house.get("window_x", 14)
    walls = []
    for i, row in enumerate((top_row, bottom_row)):
        for x in range(L, R + 1):
            col = b + 1 if x == L else (b + 3 if x == R else b + 2)
            if i == 0 and window_x <= x < window_x + 3:
                walls.append(((x, wall_top_row), WINDOW[x - window_x]))
            else:
                walls.append(((x, wall_top_row + i), (col, row)))
    s.node('[node name="Dinding" type="TileMapLayer" parent="."]', z_index=-11, texture_filter=1,
           tile_map_data=tilemap(walls), tile_set=tileset)
    # Bingkai
    fy = wall_top_row - 1
    frame = [((L - 1, fy), F_TL), ((R + 1, fy), F_TR)] + [((x, fy), F_TOP) for x in range(L, R + 1)]
    frame += [((L - 1, y), F_SIDE) for y in range(fy + 1, B + 1)] + [((R + 1, y), F_SIDE) for y in range(fy + 1, B + 1)]
    frame += [((L - 1, B + 1), F_BL), ((R + 1, B + 1), F_BR)]
    frame += [((x, B + 1), F_TOP) for x in range(L, DOOR_COLS[0] - 1)] + [((DOOR_COLS[0] - 1, B + 1), F_DOOR_L)]
    frame += [((DOOR_COLS[1] + 1, B + 1), F_DOOR_R)] + [((x, B + 1), F_TOP) for x in range(DOOR_COLS[1] + 2, R + 1)]
    frame += [((DOOR_COLS[0] - 1, B + 2), F_SIDE), ((DOOR_COLS[1] + 1, B + 2), F_SIDE)]
    s.node('[node name="Bingkai" type="TileMapLayer" parent="."]', z_index=-10, texture_filter=1,
           tile_map_data=tilemap(frame), tile_set=tileset)

    # Tabrakan dinding
    s.node('[node name="TabrakanDinding" type="StaticBody2D" parent="."]')
    door_l, door_r = 16 * DOOR_COLS[0], 16 * (DOOR_COLS[1] + 1)
    bottom_y = 16 * (B + 1)
    walls_c = {
        "Atas": ((left_px + right_px) / 2, (16 * fy + top_px + 6) / 2, right_px - left_px + 32, top_px + 6 - 16 * fy),
        "Kiri": (left_px - 12, (16 * fy + bottom_y + 16) / 2, 24, bottom_y + 16 - 16 * fy),
        "Kanan": (right_px + 12, (16 * fy + bottom_y + 16) / 2, 24, bottom_y + 16 - 16 * fy),
        "BawahKiri": ((left_px + door_l) / 2, bottom_y + 8, door_l - left_px, 16),
        "BawahKanan": ((door_r + right_px) / 2, bottom_y + 8, right_px - door_r, 16),
        "LorongKiri": (door_l - 8, bottom_y + 36, 16, 40),
        "LorongKanan": (door_r + 8, bottom_y + 36, 16, 40),
    }
    for name, (cx, cy, w, h) in walls_c.items():
        s.node(f'[node name="{name}" type="CollisionShape2D" parent="TabrakanDinding"]', position=v(cx, cy), shape=s.rect(w, h))

    # Hiasan dinding
    s.node('[node name="HiasanDinding" type="Node2D" parent="."]', z_index=-9)
    wall_mid = 16 * wall_top_row + 16
    sprite(s, "Gorden", "HiasanDinding", "doors", house["curtain"], (16 * window_x + 24, wall_mid))
    for name, sheet, reg, x, dy in house.get("wall_decor", []):
        sprite(s, name, "HiasanDinding", sheet, reg, (x, wall_mid + dy))
    # Hiasan lantai
    s.node('[node name="HiasanLantai" type="Node2D" parent="."]', z_index=-8)
    sprite(s, "KesetPintu", "HiasanLantai", "part11", (276, 19, 25, 10), (240, bottom_y + 12))
    for name, sheet, reg, pos in house.get("rugs", []):
        sprite(s, name, "HiasanLantai", sheet, reg, pos)
    shadow = s.res("Texture2D", "res://resources/world/shop_fx/wall_shadow.tres")
    s.node('[node name="BayanganDindingAtas" type="Sprite2D" parent="HiasanLantai"]', position=v((left_px + right_px) / 2, top_px + 4),
           scale=v((right_px - left_px) / 16, 0.5), texture=shadow)

    # Perabot
    s.node('[node name="Perabot" type="Node2D" parent="."]', y_sort_enabled="true")
    for item in house["furniture"]:
        furniture(s, item)
    seat = s.res("PackedScene", "res://scenes/world/exterior/object/seat.tscn")
    for i, (x, y, facing) in enumerate(house.get("seats", [])):
        s.node(f'[node name="Kursi{i + 1}" parent="Perabot" instance={seat}]', position=v(x, y), facing=facing)

    # Pencahayaan
    s.node('[node name="Pencahayaan" type="Node2D" parent="."]')
    s.node('[node name="WarnaRuangan" type="CanvasModulate" parent="Pencahayaan"]', color=house["modulate"])
    s.node('[node name="CahayaJendela" type="PointLight2D" parent="Pencahayaan"]', position=v(16 * window_x + 24, top_px + 8),
           color="Color(0.9, 0.95, 1, 1)", energy=0.4, texture=s.res("Texture2D", "res://resources/world/shop_fx/light_radial.tres"),
           texture_scale=1.7)
    s.node('[node name="Vignette" type="ColorRect" parent="Pencahayaan"]', z_index=20, material='SubResource("VignetteMaterial")',
           offset_left=f"{left_px - 16:g}", offset_top=f"{16 * fy:g}", offset_right=f"{right_px + 16:g}", offset_bottom=f"{bottom_y + 32:g}",
           mouse_filter=2)

    # Pemain, pintu keluar, penghuni
    s.node('[node name="Player" parent="." instance=' + s.res("PackedScene", "res://scenes/player/Player.tscn") + ']', position=v(240, 256))
    s.node('[node name="Camera2D" parent="Player/CharacterBody2D" index="2"]', limit_left=0, limit_top=16 * fy - 8, limit_right=480, limit_bottom=320)
    s.node('[node name="ExitDoor" type="Area2D" parent="."]', position=v(240, 304),
           script=s.res("Script", "res://scripts/world/exit_door_school.gd"), target_scene='"res://scenes/world/town.tscn"',
           spawn_position=v(*house["return"]))
    s.node('[node name="CollisionShape2D" type="CollisionShape2D" parent="ExitDoor"]', shape=s.rect(32, 16))
    s.node('[node name="SpawnPoint" type="Marker2D" parent="."]', position=v(240, 256))
    point_name, point = house["resident"]
    s.node('[node name="ResidentRoom" type="Node2D" parent="."]', script=s.res("Script", "res://scripts/npc/resident_room.gd"),
           map_id=f'"{house["file"]}"', door_position=v(240, 296), hall_position=v(240, house["hall_y"]),
           points='{\n"%s": %s\n}' % (point_name, v(*point)))
    return s.text()


def F(name, sheet, region, pos, **kw):
    d = {"name": name, "sheet": sheet, "region": region, "pos": pos}
    d.update(kw)
    return d


CANDLE_LIGHT = ("Color(1, 0.74, 0.42, 1)", 0.8, 1.0)
FIRE_LIGHT = ("Color(1, 0.6, 0.3, 1)", 1.0, 1.6)

HOUSES = [
    {   # Bahar, nelayan sepuh: biru laut, akuarium, tong ikan.
        "file": "house_blue", "node": "HouseBlueInterior", "title": "Rumah Biru", "return": (553, 803),
        "L": 8, "R": 21, "T": 7, "floor": (23, 1), "wall": "blue", "wall_style": "hstripe", "window_x": 13,
        "curtain": (48, 16, 48, 16), "grime": "Color(0.18, 0.22, 0.3, 1)", "modulate": "Color(0.74, 0.78, 0.84, 1)",
        "hall_y": 208, "resident": ("bahar_home", (176, 180)),
        "wall_decor": [("LukisanLaut", "part1", (37, 0, 20, 16), 184, 2), ("JamDinding", "part1", (161, 2, 13, 13), 312, 0),
                       ("Kalender", "part1", (260, 4, 9, 12), 152, 2)],
        "rugs": [("KarpetOval", "part11", (162, 106, 27, 21), (296, 212))],
        "furniture": [
            F("Kasur", "beds", (263, 2, 18, 34), (152, 152), message="Kasur Pak Bahar. Seprainya bergambar ombak."),
            F("MejaSampingKasur", "dressers", (64, 8, 16, 16), (176, 128), on=[("Lilin", "part1", (244, 8, 8, 8), (0, -14))]),
            F("KursiSantai", "sofa", (264, 107, 17, 20), (208, 130)),
            F("LemariRendah", "dressers", (2, 98, 27, 12), (300, 128), on=[("Akuarium", "part1", (7, 128, 33, 16), (0, -10))],
              message="Akuarium Pak Bahar: ikan-ikan kecil dari tangkapan pertama musim ini."),
            F("Tanaman", "part1", (1, 160, 11, 16), (340, 130)),
            F("MejaBundar", "tables", (6, 230, 22, 20), (296, 206), on=[("Cangkir", "part1", (244, 8, 8, 8), (-3, -13))]),
            F("TongIkan", "smith", (201, 64, 15, 25), (336, 252)),
            F("TongJaring", "smith", (231, 36, 17, 21), (318, 252)),
            F("RakJoran", "smith", (146, 71, 28, 23), (156, 252), message="Rak joran dan tombak ikan Pak Bahar, semua diminyaki rapi."),
        ],
        "seats": [(276, 208, 3), (316, 208, 2)],
    },
    {   # Damar, tukang bangunan: bata, meja kerja, peti & papan kayu.
        "file": "house_brick", "node": "HouseBrickInterior", "title": "Rumah Bata", "return": (776, 814),
        "L": 9, "R": 20, "T": 6, "floor": (14, 0), "wall": "brown", "wall_style": "plain", "window_x": 14,
        "curtain": (0, 16, 48, 16), "grime": "Color(0.3, 0.17, 0.12, 1)", "modulate": "Color(0.8, 0.72, 0.66, 1)",
        "hall_y": 200, "resident": ("damar_home", (304, 176)),
        "wall_decor": [("RakPerkakas", "smith", (149, 18, 20, 13), 176, 4), ("Kalender", "part1", (260, 4, 9, 12), 288, 2),
                       ("JamDinding", "part1", (161, 2, 13, 13), 200, 0)],
        "rugs": [("KarpetKotak", "part11", (65, 64, 30, 47), (304, 248))],
        "furniture": [
            F("Kasur", "beds", (7, 269, 33, 34), (304, 146), message="Kasur Pak Damar, masih ada serbuk kayu di ujungnya."),
            F("LemariRendah", "dressers", (2, 114, 27, 12), (264, 112)),
            F("MejaKerja", "tables", (224, 225, 63, 30), (184, 166),
              on=[("Kapak", "smith", (85, 22, 8, 8), (-18, -24)), ("Papan", "smith", (112, 22, 16, 7), (10, -24))],
              message="Meja kerja Damar: denah balai desa digambar dengan arang."),
            F("Peti1", "box", (3, 3, 11, 13), (160, 238), on=[("Peti2", "box", (3, 3, 11, 13), (0, -11))]),
            F("Peti3", "box", (3, 3, 11, 13), (174, 238)),
            F("TumpukanPapan", "smith", (115, 7, 26, 7), (200, 244)),
            F("KursiMerah", "sofa", (136, 107, 17, 20), (322, 230)),
            F("Tanaman", "part1", (16, 162, 11, 14), (156, 112)),
        ],
        "seats": [(184, 184, 0)],
    },
    {   # Ratih, tabib & herbalis: toska, rak ramuan, banyak tanaman.
        "file": "herbal_house", "node": "HerbalHouseInterior", "title": "Rumah Toska", "return": (902, 803),
        "L": 8, "R": 21, "T": 7, "floor": (30, 0), "wall": "teal", "wall_style": "vstripe", "window_x": 14,
        "curtain": (96, 16, 48, 16), "grime": "Color(0.14, 0.24, 0.2, 1)", "modulate": "Color(0.76, 0.82, 0.76, 1)",
        "hall_y": 208, "resident": ("ratih_home", (312, 180)),
        "wall_decor": [("Bingkai", "part1", (18, 17, 12, 15), 296, 0), ("JamDinding", "part1", (161, 2, 13, 13), 216, 0)],
        "rugs": [("KarpetHijau", "part11", (129, 64, 30, 47), (184, 214))],
        "furniture": [
            F("Kasur", "beds", (71, 2, 18, 34), (336, 152), message="Kasur Ratih. Ada bantal kecil berisi daun lavender."),
            F("RakRamuan", "smith", (114, 65, 28, 31), (160, 128), message="Rak ramuan Ratih: sirih, kunyit, jahe, semua berlabel rapi."),
            F("RakBuku", "others", (1, 46, 30, 34), (196, 128)),
            F("Cermin", "others", (33, 7, 14, 25), (264, 128)),
            F("Tanaman1", "part1", (65, 158, 14, 17), (288, 128)),
            F("Tanaman2", "part1", (80, 158, 15, 17), (140, 184)),
            F("Tanaman3", "part1", (1, 160, 11, 16), (140, 220)),
            F("Tanaman4", "part1", (32, 177, 14, 15), (344, 220)),
            F("KotakBunga", "part1", (96, 154, 48, 21), (176, 252)),
            F("MejaBundar", "tables", (133, 230, 22, 21), (300, 238), on=[("Teko", "part1", (244, 8, 8, 8), (0, -13))]),
        ],
        "seats": [(280, 240, 3), (320, 240, 2)],
    },
    {   # Rian, perawat ternak: kayu hangat, kasur ganda jingga, rak buku hewan.
        "file": "house_tall", "node": "HouseTallInterior", "title": "Rumah Bertingkat", "return": (276, 798),
        "L": 9, "R": 20, "T": 6, "floor": (26, 0), "wall": "orange", "wall_style": "hstripe", "window_x": 15,
        "curtain": (144, 48, 48, 16), "grime": "Color(0.3, 0.2, 0.12, 1)", "modulate": "Color(0.82, 0.74, 0.66, 1)",
        "hall_y": 200, "resident": ("rian_home", (176, 176)),
        "wall_decor": [("LukisanSapi", "part1", (37, 0, 20, 16), 208, 2), ("Kalender", "part1", (260, 4, 9, 12), 176, 2)],
        "rugs": [("KarpetBelang", "part11", (226, 74, 27, 21), (288, 206))],
        "furniture": [
            F("Kasur", "beds", (7, 365, 33, 34), (176, 146), on=[("Boneka", "part1", (130, 97, 13, 15), (8, -14))],
              message="Kasur Rian. Boneka sapinya hadiah dari Eep."),
            F("RakBuku", "others", (81, 48, 30, 32), (304, 112), message="Buku perawatan ternak, ditandai dengan bulu ayam."),
            F("LemariRendah", "dressers", (98, 98, 27, 12), (264, 112)),
            F("Meja", "tables", (200, 200, 51, 20), (288, 196)),
            F("Tanaman", "part1", (65, 177, 15, 15), (336, 248)),
            F("EmberSusu", "smith", (233, 70, 15, 19), (156, 248)),
            F("PetiPakan", "box", (3, 3, 11, 13), (172, 248)),
        ],
        "seats": [(276, 212, 0), (300, 212, 0)],
    },
    {   # Kirana, perangkai bunga: merah muda, vas bunga di mana-mana.
        "file": "house_pink", "node": "HousePinkInterior", "title": "Rumah Merah Muda", "return": (184, 798),
        "L": 8, "R": 21, "T": 7, "floor": (31, 1), "wall": "pink", "wall_style": "vstripe", "window_x": 15,
        "curtain": (144, 16, 48, 16), "grime": "Color(0.3, 0.16, 0.2, 1)", "modulate": "Color(0.84, 0.76, 0.8, 1)",
        "hall_y": 208, "resident": ("kirana_home", (296, 180)),
        "wall_decor": [("Bingkai1", "part1", (18, 17, 12, 15), 168, 0), ("Bingkai2", "part1", (50, 17, 12, 15), 192, 0)],
        "rugs": [("KarpetBesar", "part11", (4, 117, 70, 40), (176, 214))],
        "furniture": [
            F("Kasur", "beds", (295, 269, 33, 34), (320, 152), message="Kasur Kirana, ditaburi kelopak mawar kering."),
            F("Sofa", "sofa", (130, 11, 29, 20), (176, 130)),
            F("Cermin", "others", (17, 7, 14, 25), (264, 130)),
            F("MejaBundar", "tables", (37, 230, 22, 21), (176, 196), on=[("Vas", "part1", (0, 178, 13, 11), (0, -14))]),
            F("Vas1", "part1", (65, 177, 15, 15), (144, 130)),
            F("Vas2", "part1", (81, 177, 15, 15), (212, 130)),
            F("Vas3", "part1", (32, 177, 14, 15), (344, 240)),
            F("KotakBunga", "part1", (96, 154, 48, 21), (176, 252), message="Rangkaian bunga pesanan untuk festival, masih disiram tiap pagi."),
        ],
        "seats": [(176, 214, 0)],
    },
    {   # Mbah Darmi, sesepuh: kayu tua, perapian, jam tua, lilin.
        "file": "house_west", "node": "HouseWestInterior", "title": "Rumah Barat", "return": (136, 369),
        "L": 9, "R": 21, "T": 7, "floor": (16, 0), "wall": "rose", "wall_style": "plain", "window_x": 12,
        "curtain": (0, 48, 48, 16), "grime": "Color(0.25, 0.13, 0.1, 1)", "modulate": "Color(0.7, 0.62, 0.6, 1)",
        "hall_y": 208, "resident": ("darmi_home", (184, 180)),
        "wall_decor": [("FotoKeluarga", "part1", (19, 38, 11, 10), 248, 2), ("Bingkai", "part1", (34, 38, 11, 10), 264, 2)],
        "rugs": [("KarpetMerah", "part11", (84, 117, 70, 40), (296, 220))],
        "furniture": [
            F("Kasur", "beds", (7, 50, 18, 34), (160, 152), message="Kasur Mbah Darmi, berselimut kain batik lawas."),
            F("MejaLilin", "tables", (5, 262, 22, 21), (192, 128), light=CANDLE_LIGHT,
              on=[("Lilin", "part1", (244, 8, 8, 8), (0, -15))]),
            F("JamTua", "part1", (145, 3, 13, 29), (216, 128), message="Jam tua peninggalan suami Mbah Darmi; masih berdentang tiap petang."),
            F("Perapian", "fireplace", (34, 6, 28, 42), (296, 128), light=FIRE_LIGHT),
            F("KursiGoyang", "sofa", (296, 107, 17, 20), (296, 176)),
            F("RakBuku", "others", (39, 45, 34, 35), (332, 128)),
            F("Cermin", "others", (1, 7, 14, 25), (156, 240)),
            F("Tanaman", "part1", (16, 162, 11, 14), (340, 244)),
        ],
        "seats": [],
    },
    {   # Empu Bima: rumah & bengkel, lantai bata gelap, tungku, rak senjata.
        "file": "blacksmith", "node": "BlacksmithInterior", "title": "Rumah & Bengkel Pandai Besi", "return": (1307, 962),
        "L": 8, "R": 21, "T": 6, "floor": (13, 2), "wall": "slate", "wall_style": "plain", "window_x": 16,
        "curtain": (96, 48, 48, 16), "grime": "Color(0.12, 0.1, 0.1, 1)", "modulate": "Color(0.7, 0.66, 0.66, 1)",
        "hall_y": 200, "resident": ("bima_home", (312, 176)),
        "wall_decor": [("RakPerkakas", "smith", (149, 18, 20, 13), 208, 4), ("Pedang", "smith", (180, 8, 9, 15), 232, 2)],
        "rugs": [],
        "furniture": [
            F("Kasur", "beds", (199, 98, 18, 34), (336, 146), message="Kasur Empu Bima. Ada sarung tangan kulit tergantung di ujungnya."),
            F("Tungku", "smith", (48, 0, 16, 16), (168, 112), light=FIRE_LIGHT),
            F("Landasan", "smith", (71, 2, 17, 13), (176, 160)),
            F("RakSenjata1", "smith", (98, 39, 28, 20), (216, 112)),
            F("RakSenjata2", "smith", (130, 38, 28, 21), (272, 112)),
            F("Konter", "smith", (2, 64, 45, 32), (180, 240),
              message="Rumah dan bengkel Empu Bima. Upgrade alat dilayani di tungku depan, 08.00–17.00."),
            F("Tong1", "smith", (201, 64, 15, 25), (144, 250)),
            F("Tong2", "smith", (233, 70, 15, 19), (300, 250)),
            F("Zirah1", "smith", (49, 68, 15, 28), (320, 250)),
            F("Zirah2", "smith", (65, 68, 15, 28), (340, 250)),
        ],
        "seats": [],
    },
]


if __name__ == "__main__":
    for house in HOUSES:
        path = OUT / f"{house['file']}.tscn"
        path.write_text(build(house), encoding="utf-8", newline="\n")
        print("wrote", path.relative_to(ROOT))


def preview_ops(house):
    """Daftar gambar (z, sheet_path, region, top-left) untuk pratinjau headless."""
    ops = []
    L, R, T, B = house["L"], house["R"], house["T"], FLOOR_BOTTOM
    tiles = "res://assets/farm_rpg/tileset/int/Tileset House.png"
    def tile(x, y, a, z):
        ops.append((z, tiles, (a[0] * 16, a[1] * 16, 16, 16), (x * 16, y * 16)))
    for y in range(T, B + 1):
        for x in range(L, R + 1):
            tile(x, y, house["floor"], 0)
    for y in (B + 1, B + 2):
        for x in DOOR_COLS:
            tile(x, y, house["floor"], 0)
    b = WALL_BLOCK[house["wall"]] * 4
    top_row, bottom_row = WALL_STYLE[house["wall_style"]]
    wx = house.get("window_x", 14)
    for i, row in enumerate((top_row, bottom_row)):
        for x in range(L, R + 1):
            col = b + 1 if x == L else (b + 3 if x == R else b + 2)
            a = WINDOW[x - wx] if i == 0 and wx <= x < wx + 3 else (col, row)
            tile(x, T - 2 + i, a, 1)
    def spr(sheet, reg, pos, z):
        ops.append((z, SHEETS[sheet], reg, (pos[0] - reg[2] / 2, pos[1] - reg[3])))
    wall_mid = 16 * (T - 2) + 16
    spr("doors", house["curtain"], (16 * wx + 24, wall_mid), 2)
    for _, sheet, reg, x, dy in house.get("wall_decor", []):
        spr(sheet, reg, (x, wall_mid + dy), 2)
    for _, sheet, reg, pos in house.get("rugs", []):
        spr(sheet, reg, pos, 3)
    items = sorted(house["furniture"], key=lambda f: f["pos"][1])
    for f in items:
        spr(f["sheet"], f["region"], f["pos"], 10 + f["pos"][1] / 1000)
        for _, sheet, reg, (dx, dy) in f.get("on", []):
            spr(sheet, reg, (f["pos"][0] + dx, f["pos"][1] + dy), 10 + f["pos"][1] / 1000 + 0.0001)
    for x, y, _ in house.get("seats", []):
        spr("chairs", (146, 15, 11, 16), (x, y), 10 + y / 1000)
    p = house["resident"][1]
    spr("chairs", (2, 10, 13, 21), p, 99)  # penanda titik NPC
    ops.sort(key=lambda o: o[0])
    return [{"tex": o[1], "region": list(o[2]), "pos": list(o[3])} for o in ops]


SHEETS["chairs"] = "res://assets/farm_rpg/objects/interior/Chairs.png"
if __name__ == "__main__":
    import json
    (ROOT / "scratch/home_preview_ops.json").write_text(json.dumps({h["file"]: preview_ops(h) for h in HOUSES}), encoding="utf-8")
    print("preview ops written")
