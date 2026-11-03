"""Generator interior Menara Penyihir (Hutan Dalam), pola sama dengan gen_resident_homes.py.

Jalankan dari root proyek: python tools/gen_witch_tower.py
Menulis scenes/world/interior/witch_tower.tscn. Hasilnya node biasa: geser/ubah di editor sesudahnya
(jalankan ulang generator akan menimpa perubahan editor).
Isi: lantai batu, dinding biru-abu bergaris, rak buku & ramuan, meja konter + Nyai Kenanga (toko sihir),
kuali menggelegak (ramuan lanjutan), meja jimat, altar enchant, lilin, karpet, cahaya ungu.
"""
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
import gen_resident_homes as base  # noqa: E402
from gen_resident_homes import Scene, tilemap, sprite, furniture, F, v, rect2  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "scenes/world/interior/witch_tower.tscn"

base.SHEETS.update({
    "pot": "res://assets/farm_rpg/objects/Work Benches/Kitchen pot.png",
    "alchemy": "res://assets/farm_rpg/objects/Work Benches/Alchemy Table.png",
    "candle": "res://assets/farm_rpg/objects/interior/Candle 1.png",
    "temple": "res://assets/farm_rpg/objects/interior/Temple.png",
    "altar": "res://assets/farm_rpg/objects/exterior/Deep Forest/Altar.png",
    "pillar": "res://assets/farm_rpg/objects/exterior/Deep Forest/Stone Pillar.png",
})

L, R, T, B = 7, 22, 6, base.FLOOR_BOTTOM
WALL_BLOCK = base.WALL_BLOCK["slate"] * 4
WALL_TOP, WALL_BOTTOM = base.WALL_STYLE["vstripe"]
FLOOR = (13, 2)        # batu gelap
WINDOW_X = 14
# Titik di depan pintu menara pada peta Hutan Dalam (DeepForest.tscn, node YSortEntities/WitchTower).
RETURN = (920, 306)

CANDLE_LIGHT = ("Color(1, 0.72, 0.42, 1)", 0.75, 0.9)


def animated(s, name, parent, sheet, frame_w, frame_h, frames, pos, fps=6.0):
    """AnimatedSprite2D dari potongan sheet horizontal (frames = indeks kolom).
    SpriteFrames dipakai bersama oleh semua node dengan sheet+frame+fps yang sama."""
    made = getattr(s, "anim_made", None)
    if made is None:
        made = s.anim_made = set()
    atlas_ids = []
    for f in frames:
        sid = f"Atlas_{sheet}_{f}"
        if sid not in made:
            made.add(sid)
            s.subs.append(f'[sub_resource type="AtlasTexture" id="{sid}"]\natlas = {s.tex(sheet)}\nregion = Rect2({f * frame_w}, 0, {frame_w}, {frame_h})\n')
        atlas_ids.append(sid)
    fid = "Frames_%s_%s_%g" % (sheet, "_".join(map(str, frames)), fps)
    if fid not in made:
        made.add(fid)
        frame_list = ", ".join('{\n"duration": 1.0,\n"texture": SubResource("%s")\n}' % a for a in atlas_ids)
        s.subs.append(f'[sub_resource type="SpriteFrames" id="{fid}"]\nanimations = [{{\n"frames": [{frame_list}],\n"loop": true,\n"name": &"default",\n"speed": {fps}\n}}]\n')
    s.node(f'[node name="{name}" type="AnimatedSprite2D" parent="{parent}"]', position=v(*pos), texture_filter=1,
           sprite_frames=f'SubResource("{fid}")', autoplay='&"default"', offset=v(0, -frame_h / 2))


def station(s, name, pos, region_size, station_id, message, sprite_fn, light=None, sign=None):
    """StaticBody2D bertombol interaksi (witch_station.gd) + sprite/animasi di dalamnya."""
    w, h = region_size
    s.node(f'[node name="{name}" type="StaticBody2D" parent="Perabot"]', position=v(*pos),
           script=s.res("Script", "res://scripts/world/witch_station.gd"), station=f'"{station_id}"',
           message='"' + message.replace('"', '\\"') + '"', sign_text=f'"{sign or ""}"')
    s.node(f'[node name="Shadow" type="Sprite2D" parent="Perabot/{name}"]', z_index=-1, position=v(0, -1),
           scale=v(round(w / 24.6, 3), 0.6), texture=s.res("Texture2D", "res://resources/world/shop_fx/soft_shadow.tres"))
    sprite_fn(f"Perabot/{name}")
    ch = min(12, max(6, h // 3))
    s.node(f'[node name="CollisionShape2D" type="CollisionShape2D" parent="Perabot/{name}"]',
           position=v(0, -ch / 2), shape=s.rect(max(6, w - 4), ch))
    if light:
        color, energy, scale, dy = light
        s.node(f'[node name="Cahaya" type="PointLight2D" parent="Perabot/{name}"]', position=v(0, dy), color=color,
               energy=energy, texture=s.res("Texture2D", "res://resources/world/shop_fx/light_radial.tres"), texture_scale=scale)


def build():
    s = Scene()
    left_px, right_px, top_px = 16 * L, 16 * (R + 1), 16 * T
    wall_top_row = T - 2
    tileset = s.res("TileSet", "res://resources/world/house_interior_tileset.tres")
    s.subs.append('[sub_resource type="ShaderMaterial" id="FloorWear"]\nshader = ' + s.res("Shader", "res://shaders/floor_wear.gdshader")
                  + '\nshader_parameter/grime_color = Color(0.16, 0.12, 0.24, 1)\nshader_parameter/block_size = 2.0\n'
                  'shader_parameter/grime_strength = 0.16\nshader_parameter/stain_strength = 0.2\nshader_parameter/stain_scale = 28.0\n')
    s.subs.append('[sub_resource type="ShaderMaterial" id="VignetteMaterial"]\nshader = ' + s.res("Shader", "res://shaders/room_vignette.gdshader")
                  + '\nshader_parameter/vignette_color = Color(0.07, 0.03, 0.12, 1)\nshader_parameter/strength = 0.5\n'
                  'shader_parameter/inner_radius = 0.5\nshader_parameter/outer_radius = 1.15\n')
    s.node('[node name="WitchTowerInterior" type="Node2D"]', y_sort_enabled="true",
           script=s.res("Script", "res://scripts/world/witch_tower_interior.gd"), room_title='"Menara Penyihir"', default_zoom="2.0")

    # Lantai + lorong pintu
    floor = [((x, y), FLOOR) for y in range(T, B + 1) for x in range(L, R + 1)]
    floor += [((x, y), FLOOR) for y in (B + 1, B + 2) for x in base.DOOR_COLS]
    s.node('[node name="Lantai" type="TileMapLayer" parent="."]', z_index=-12, material='SubResource("FloorWear")',
           texture_filter=1, tile_map_data=tilemap(floor), tile_set=tileset)
    walls = []
    for i, row in enumerate((WALL_TOP, WALL_BOTTOM)):
        for x in range(L, R + 1):
            col = WALL_BLOCK + 1 if x == L else (WALL_BLOCK + 3 if x == R else WALL_BLOCK + 2)
            if i == 0 and WINDOW_X <= x < WINDOW_X + 3:
                walls.append(((x, wall_top_row), base.WINDOW[x - WINDOW_X]))
            else:
                walls.append(((x, wall_top_row + i), (col, row)))
    s.node('[node name="Dinding" type="TileMapLayer" parent="."]', z_index=-11, texture_filter=1,
           tile_map_data=tilemap(walls), tile_set=tileset)
    fy = wall_top_row - 1
    fr = [((L - 1, fy), base.F_TL), ((R + 1, fy), base.F_TR)] + [((x, fy), base.F_TOP) for x in range(L, R + 1)]
    fr += [((L - 1, y), base.F_SIDE) for y in range(fy + 1, B + 1)] + [((R + 1, y), base.F_SIDE) for y in range(fy + 1, B + 1)]
    fr += [((L - 1, B + 1), base.F_BL), ((R + 1, B + 1), base.F_BR)]
    d0, d1 = base.DOOR_COLS
    fr += [((x, B + 1), base.F_TOP) for x in range(L, d0 - 1)] + [((d0 - 1, B + 1), base.F_DOOR_L)]
    fr += [((d1 + 1, B + 1), base.F_DOOR_R)] + [((x, B + 1), base.F_TOP) for x in range(d1 + 2, R + 1)]
    fr += [((d0 - 1, B + 2), base.F_SIDE), ((d1 + 1, B + 2), base.F_SIDE)]
    s.node('[node name="Bingkai" type="TileMapLayer" parent="."]', z_index=-10, texture_filter=1,
           tile_map_data=tilemap(fr), tile_set=tileset)

    # Tabrakan dinding (sama dengan rumah warga)
    s.node('[node name="TabrakanDinding" type="StaticBody2D" parent="."]')
    door_l, door_r = 16 * d0, 16 * (d1 + 1)
    bottom_y = 16 * (B + 1)
    for name, (cx, cy, w, h) in {
        "Atas": ((left_px + right_px) / 2, (16 * fy + top_px + 6) / 2, right_px - left_px + 32, top_px + 6 - 16 * fy),
        "Kiri": (left_px - 12, (16 * fy + bottom_y + 16) / 2, 24, bottom_y + 16 - 16 * fy),
        "Kanan": (right_px + 12, (16 * fy + bottom_y + 16) / 2, 24, bottom_y + 16 - 16 * fy),
        "BawahKiri": ((left_px + door_l) / 2, bottom_y + 8, door_l - left_px, 16),
        "BawahKanan": ((door_r + right_px) / 2, bottom_y + 8, right_px - door_r, 16),
        "LorongKiri": (door_l - 8, bottom_y + 36, 16, 40),
        "LorongKanan": (door_r + 8, bottom_y + 36, 16, 40),
    }.items():
        s.node(f'[node name="{name}" type="CollisionShape2D" parent="TabrakanDinding"]', position=v(cx, cy), shape=s.rect(w, h))

    # Hiasan dinding
    s.node('[node name="HiasanDinding" type="Node2D" parent="."]', z_index=-9)
    wall_mid = 16 * wall_top_row + 16
    sprite(s, "Gorden", "HiasanDinding", "doors", (96, 16, 48, 16), (16 * WINDOW_X + 24, wall_mid))
    sprite(s, "JamTua", "HiasanDinding", "part1", (161, 2, 13, 13), (200, wall_mid))
    sprite(s, "Bingkai", "HiasanDinding", "part1", (18, 17, 12, 15), (300, wall_mid + 2))
    # Hiasan lantai: karpet merah dari pintu ke tengah ruangan.
    s.node('[node name="HiasanLantai" type="Node2D" parent="."]', z_index=-8)
    sprite(s, "KarpetPintu", "HiasanLantai", "temple", (103, 16, 34, 44), (240, 252))
    sprite(s, "KarpetDalam", "HiasanLantai", "temple", (103, 16, 34, 44), (240, 210))
    s.node('[node name="BayanganDindingAtas" type="Sprite2D" parent="HiasanLantai"]', position=v((left_px + right_px) / 2, top_px + 4),
           scale=v((right_px - left_px) / 16, 0.5), texture=s.res("Texture2D", "res://resources/world/shop_fx/wall_shadow.tres"))

    # Perabot biasa
    s.node('[node name="Perabot" type="Node2D" parent="."]', y_sort_enabled="true")
    for item in [
        F("RakBuku1", "others", (1, 46, 30, 34), (130, 124), message="Buku-buku tua: Herbarium Gaib, Tata Rune Jawa Kuno, Catatan Bulan Purnama."),
        F("RakBuku2", "others", (39, 45, 34, 35), (164, 125), message="Satu buku bergerak sendiri saat kamu mendekat... lalu diam lagi."),
        F("RakRamuan", "smith", (114, 65, 28, 31), (318, 123), message="Rak bahan sihir: toples Debu Bintang, Embun Bulan, dan akar yang masih berdenyut."),
        F("Cermin", "others", (33, 7, 14, 25), (344, 121), message="Cermin tua. Bayanganmu tersenyum sedetik lebih lama darimu."),
        F("Tanaman1", "part1", (65, 158, 14, 17), (118, 252)),
        F("Tanaman2", "part1", (80, 158, 15, 17), (360, 252)),
        F("MejaKonter", "tables", (200, 200, 51, 20), (176, 178), on=[("LilinKonter", "part1", (244, 8, 8, 8), (-16, -18))]),
    ]:
        furniture(s, item)
    # Konter meneruskan interaksi ke Nyai Kenanga (interact_forward.gd).
    _retarget_counter(s)

    # Nyai Kenanga di balik konter.
    appearance_id = "Appearance_Kenanga"
    s.subs.append(f'[sub_resource type="Resource" id="{appearance_id}"]\nscript = ' + s.res("Script", "res://scripts/data/character_appearance.gd")
                  + '\nskin = "skin_2"\neyes = "eyes_female"\neye_color = "green"\nhair = "hair_lyria"\nhair_color = "black"\n'
                  'outfit = "outfit_cardigan"\noutfit_color = "blue"\nhead = "head_wizard"\n')
    s.node('[node name="NyaiKenanga" type="StaticBody2D" parent="Perabot"]', position=v(176, 158),
           script=s.res("Script", "res://scripts/world/witch_npc.gd"), npc_name='"Nyai Kenanga"',
           appearance=f'SubResource("{appearance_id}")', shop_data=s.res("Resource", "res://resources/shop/magic_shop.tres"),
           lines='PackedStringArray("Selamat datang di menaraku, murid muda. Lihat-lihat dulu tongkat dan bahan sihirnya.", '
                 '"Hutan ini berbisik kalau bulan penuh. Jangan lupa bawa kemenyan.", '
                 '"Debu Bintang paling bagus dicampur saat kuali sedang berwarna ungu.", '
                 '"Penunggu di altar sebelah itu teman lamaku. Bawakan sesajen yang pantas.")')
    s.node('[node name="AnimatedSprite2D" type="AnimatedSprite2D" parent="Perabot/NyaiKenanga"]', texture_filter=1, offset=v(0, -10))
    s.node('[node name="CollisionShape2D" type="CollisionShape2D" parent="Perabot/NyaiKenanga"]', position=v(0, -4), shape=s.rect(12, 8))

    # Stasiun sihir
    station(s, "Kuali", (322, 196), (32, 32), "cauldron",
            "Kuali Nyai Kenanga menggelegak hijau. Racik ramuan lanjutan di sini.",
            lambda p: animated(s, "Api", p, "pot", 32, 32, [1, 2, 3, 4], (0, 0), fps=7.0),
            light=("Color(0.55, 1, 0.6, 1)", 0.9, 1.3, -20), sign="Kuali")
    station(s, "MejaJimat", (136, 206), (32, 32), "charm",
            "Meja jimat: tinta perak, benang kantil, dan papan rune.",
            lambda p: animated(s, "Buku", p, "alchemy", 32, 32, [0, 1, 2], (0, 0), fps=2.0),
            light=("Color(0.8, 0.7, 1, 1)", 0.6, 1.0, -18), sign="Meja Jimat")
    station(s, "AltarEnchant", (296, 156), (40, 30), "enchant",
            "Altar enchant: batu tua yang dingin, ukiran rune berpendar pelan.",
            lambda p: sprite(s, "Batu", p, "altar", (0, 0, 48, 48)),
            light=("Color(0.55, 0.95, 1, 1)", 0.4, 0.9, -16), sign="Altar Enchant")
    # Lilin berkedip
    for i, (x, y) in enumerate([(268, 154), (332, 154), (110, 196), (370, 196)]):
        s.node(f'[node name="Lilin{i + 1}" type="StaticBody2D" parent="Perabot"]', position=v(x, y))
        animated(s, "Api", f"Perabot/Lilin{i + 1}", "candle", 16, 32, [0, 1, 2, 3], (0, 0), fps=6.0)
        s.node(f'[node name="Cahaya" type="PointLight2D" parent="Perabot/Lilin{i + 1}"]', position=v(0, -16), color=CANDLE_LIGHT[0],
               energy=CANDLE_LIGHT[1], texture=s.res("Texture2D", "res://resources/world/shop_fx/light_radial.tres"), texture_scale=CANDLE_LIGHT[2])
        s.node(f'[node name="CollisionShape2D" type="CollisionShape2D" parent="Perabot/Lilin{i + 1}"]', position=v(0, -3), shape=s.rect(10, 6))

    # Pencahayaan: ungu temaram, tanpa sinar matahari (menara hutan selalu redup).
    s.node('[node name="Pencahayaan" type="Node2D" parent="."]')
    s.node('[node name="WarnaRuangan" type="CanvasModulate" parent="Pencahayaan"]', color="Color(0.62, 0.58, 0.8, 1)")
    s.node('[node name="CahayaJendela" type="PointLight2D" parent="Pencahayaan"]', position=v(16 * WINDOW_X + 24, top_px + 8),
           color="Color(0.75, 0.8, 1, 1)", energy=0.35, texture=s.res("Texture2D", "res://resources/world/shop_fx/light_radial.tres"),
           texture_scale=1.7)
    s.node('[node name="Vignette" type="ColorRect" parent="Pencahayaan"]', z_index=20, material='SubResource("VignetteMaterial")',
           offset_left=f"{left_px - 16:g}", offset_top=f"{16 * fy:g}", offset_right=f"{right_px + 16:g}", offset_bottom=f"{bottom_y + 32:g}",
           mouse_filter=2)

    # Pemain + pintu keluar
    s.node('[node name="Player" parent="." instance=' + s.res("PackedScene", "res://scenes/player/Player.tscn") + ']', position=v(240, 248))
    s.node('[node name="Camera2D" parent="Player/CharacterBody2D" index="2"]', limit_left=0, limit_top=16 * fy - 8, limit_right=480, limit_bottom=320)
    s.node('[node name="ExitDoor" type="Area2D" parent="."]', position=v(240, 304),
           script=s.res("Script", "res://scripts/world/exit_door_school.gd"), target_scene='"res://scenes/world/DeepForest.tscn"',
           spawn_position=v(*RETURN))
    s.node('[node name="CollisionShape2D" type="CollisionShape2D" parent="ExitDoor"]', shape=s.rect(32, 16))
    s.node('[node name="SpawnPoint" type="Marker2D" parent="."]', position=v(240, 248))
    return s.text()


def _retarget_counter(s):
    """Konter (node terakhir yang ditulis furniture()) memakai interact_forward.gd -> ../NyaiKenanga."""
    script = s.res("Script", "res://scripts/world/interact_forward.gd")
    for i, text in enumerate(s.nodes):
        if text.startswith('[node name="MejaKonter" type="StaticBody2D"'):
            s.nodes[i] = text.rstrip("\n") + f"\nscript = {script}\ntarget = NodePath(\"../NyaiKenanga\")\n"


if __name__ == "__main__":
    OUT.write_text(build(), encoding="utf-8", newline="\n")
    print("ditulis", OUT)
