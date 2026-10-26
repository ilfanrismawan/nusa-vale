"""Generate per-ingredient artisan goods (stdlib only).

Keg, Oil Maker and Fish Smoker outputs are priced relative to their ingredient
(GDD 4.11, audit 26 Oktober 2026): fruit wine x2.25, fruit juice x2.0,
beer/mead x3, pressed oil x2, smoked fish x2. Re-run after changing an
ingredient price; existing files are overwritten with the recomputed price.
"""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
ITEMS = ROOT / "resources/item_data"

WINE = 2.25
JUICE = 2.0
BREW = 3.0
SMOKED = 2.0
OIL = 2.0

# input -> (output id, multiplier, template item). Base ids beer/mead/wine are kept
# for wheat/honey/grape so bundles and cooking that ask for them stay valid.
KEG = {
    "wheat": ("beer", BREW, "beer"),
    "honey": ("mead", BREW, "mead"),
    "grape": ("wine", WINE, "wine"),
    "apple": ("apple_wine", WINE, "wine"),
    "cherry": ("cherry_wine", WINE, "wine"),
    "peach": ("peach_wine", WINE, "wine"),
    "orange": ("orange_wine", WINE, "wine"),
    "strawberry": ("strawberry_wine", WINE, "wine"),
    "blueberry": ("blueberry_wine", WINE, "wine"),
    "banana": ("banana_juice", JUICE, "wine"),
    "mango": ("mango_juice", JUICE, "wine"),
    "melon": ("melon_juice", JUICE, "wine"),
    "watermelon": ("watermelon_juice", JUICE, "wine"),
    "pineapple": ("pineapple_juice", JUICE, "wine"),
    "tomato": ("tomato_juice", JUICE, "wine"),
    "carrot": ("carrot_juice", JUICE, "wine"),
}


# Oil Maker (GDD 4.11: jagung, bunga matahari, truffle). "oil" stays the cheap
# store-bought cooking oil and is no longer a machine output.
OIL_MAKER = {
    "corn": ("corn_oil", "Minyak Jagung"),
    "sunflower": ("sunflower_oil", "Minyak Bunga Matahari"),
    "truffle": ("truffle_oil", "Minyak Truffle"),
}


def field(text, key):
    match = re.search(r'^%s\s*=\s*"?([^"\n]*)"?' % key, text, re.M)
    return match[1] if match else ""


def set_field(text, key, value):
    return re.sub(r"^%s\s*=.*$" % key, "%s = %s" % (key, value), text, count=1, flags=re.M)


# Food effect profiles (resources/cooking/effects) so every FOOD item has one.
EFFECT_SCRIPT = 'path="res://scripts/resources/food_effect_data.gd"'


def set_effect(text, profile):
    """Replace any food effect on an ItemData .tres with a single profile."""
    lines = [line for line in text.split("\n") if 'id="fx_type"' not in line and 'id="fx_profile"' not in line and not line.startswith("food_effects =")]
    last_ext = max(i for i, line in enumerate(lines) if line.startswith("[ext_resource"))
    lines[last_ext + 1:last_ext + 1] = [
        f'[ext_resource type="Script" uid="uid://vbwn6cjjdlc0" {EFFECT_SCRIPT} id="fx_type"]',
        f'[ext_resource type="Resource" path="res://resources/cooking/effects/{profile}.tres" id="fx_profile"]',
    ]
    category = next(i for i, line in enumerate(lines) if line.startswith("category ="))
    lines.insert(category, 'food_effects = Array[ExtResource("fx_type")]([ExtResource("fx_profile")])')
    return "\n".join(lines)


def effect_for(item_id):
    if item_id.endswith("_juice"):
        return "refreshing"
    if item_id.startswith("smoked_fish"):
        return "seafood"
    return "fermented"


def write_item(template_id, item_id, name, description, price):
    text = (ITEMS / f"{template_id}.tres").read_text(encoding="utf-8")
    text = re.sub(r' uid="uid://[^"]+"', "", text.split("\n", 1)[0]) + "\n" + text.split("\n", 1)[1]
    text = set_field(text, "item_id", f'"{item_id}"')
    text = set_field(text, "display_name", f'"{name}"')
    text = set_field(text, "description", f'"{description}"')
    text = set_field(text, "sell_price", str(price))
    text = set_field(text, "buy_price", str(price * 2))
    if field(text, "category") == "9":
        text = set_effect(text, effect_for(item_id))
    (ITEMS / f"{item_id}.tres").write_text(text, encoding="utf-8")


def main():
    written = 0
    for source, (output, mult, template) in KEG.items():
        source_text = (ITEMS / f"{source}.tres").read_text(encoding="utf-8")
        price = round(int(field(source_text, "sell_price")) * mult)
        label = field(source_text, "display_name")
        if output in ("beer", "mead", "wine"):
            text = (ITEMS / f"{output}.tres").read_text(encoding="utf-8")
            text = set_effect(set_field(set_field(text, "sell_price", str(price)), "buy_price", str(price * 2)), "fermented")
            (ITEMS / f"{output}.tres").write_text(text, encoding="utf-8")
        elif output.endswith("_wine"):
            write_item(template, output, f"Wine {label}", f"Wine hasil fermentasi {label} di tong fermentasi.", price)
        else:
            write_item(template, output, f"Jus {label}", f"Jus {label} hasil tong fermentasi.", price)
        written += 1
    for source, (output, name) in OIL_MAKER.items():
        price = round(int(field((ITEMS / f"{source}.tres").read_text(encoding="utf-8"), "sell_price")) * OIL)
        if output == "truffle_oil":
            text = (ITEMS / "truffle_oil.tres").read_text(encoding="utf-8")
            (ITEMS / "truffle_oil.tres").write_text(set_field(set_field(text, "sell_price", str(price)), "buy_price", str(price * 2)), encoding="utf-8")
        else:
            write_item("truffle_oil", output, name, f"{name} hasil Oil Maker, bahan masak bernilai tinggi.", price)
        written += 1
    legacy = ITEMS / "smoked_fish.tres"
    legacy.write_text(set_effect(legacy.read_text(encoding="utf-8"), "seafood"), encoding="utf-8")
    for path in sorted(ITEMS.glob("fish_*.tres")):
        text = path.read_text(encoding="utf-8")
        if field(text, "category") != "5":
            continue
        price = round(int(field(text, "sell_price")) * SMOKED)
        label = field(text, "display_name")
        write_item("smoked_fish", "smoked_" + path.stem, f"{label} Asap", f"{label} hasil pengasap ikan. Bernilai jual 2x ikan segarnya.", price)
        written += 1
    print(f"artisan goods written: {written}")


if __name__ == "__main__":
    main()
