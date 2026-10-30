"""Make raw produce, forage and artisan goods edible with stamina below finished goods.

Usage: python -I tools/rebalance_edible.py [--dry-run]

Rules (docs/EDIBLE_BALANCE.md):
- Base stamina = round(k * sqrt(sell_price)), clamped per group.
- Every edible input is capped at CAP_RATIO of the cheapest edible product made from it
  (cooking recipes, artisan machines, preserves jar, dehydrator), so a raw item never
  equals or beats what it turns into. Products are resolved first (FOOD fixed, then
  artisan goods), then their inputs.
- Quality variants (_silver/_gold/_large...) scale the base value but stay under the cap.
Writes `edible = true` and `stamina_restore = N` into resources/item_data/<id>.tres.
"""
import math
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ITEMS = os.path.join(ROOT, "resources", "item_data")
CAP_RATIO = 0.7
VARIANT_CAP_RATIO = 0.85

CROP_EXCLUDE = {"wheat", "rice", "sunflower"}
PRODUCE = {"artichoke", "avocado", "cranberry", "lemon", "sweet_potato", "peanut", "coconut",
           "green_coconut", "asparagus", "green_pepper"}
FORAGE = {"common_mushroom", "hazelnut", "wild_berry", "spring_onion", "winter_root", "truffle", "mooncap"}
ANIMAL = {"chicken_egg", "duck_egg", "ostrich_egg", "cow_milk", "goat_milk", "buffalo_milk"}
ARTISAN = {"cheese", "goat_cheese", "buffalo_cheese", "mayonnaise", "duck_mayonnaise", "butter", "cream",
           "yogurt", "honey", "maple_syrup", "blueberry_jam", "strawberry_jam", "dried_fruit", "raisins",
           "pickled_cucumber", "pickled_tomato", "chocolate", "peanut_butter"}
# group: (k, min, max) for the base item; quality variants may rise to VARIANT_MAX.
GROUPS = {"crop": (1.0, 4, 14), "forage": (1.0, 4, 14), "animal": (1.2, 6, 15), "artisan": (1.5, 8, 22)}
VARIANT_MAX = {"crop": 14, "forage": 14, "animal": 18, "artisan": 26}
VARIANTS = {"silver": 1.15, "gold": 1.3, "large": 1.15, "large_silver": 1.3, "large_gold": 1.5}
CATEGORIES = ["ALL", "SEED", "CROP", "TOOL", "MATERIAL", "FISH", "FORAGE", "EQUIPMENT", "BUILDING", "FOOD"]


def read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


def field(text, name):
    m = re.search(r"^%s = (.+)$" % name, text, re.M)
    return m.group(1).strip() if m else None


def load_items():
    items = {}
    for name in os.listdir(ITEMS):
        if not name.endswith(".tres"):
            continue
        text = read(os.path.join(ITEMS, name))
        item_id = (field(text, "item_id") or '""').strip('"') or name[:-5]
        cat = field(text, "category")
        items[item_id] = {
            "file": name,
            "category": CATEGORIES[int(cat)] if cat else "MATERIAL",
            "sell": int(field(text, "sell_price") or 0),
            "stamina": int(field(text, "stamina_restore") or 0),
            "name": (field(text, "display_name") or '""').strip('"'),
        }
    return items


def split_variant(item_id):
    for suffix in sorted(VARIANTS, key=len, reverse=True):
        if item_id.endswith("_" + suffix):
            return item_id[: -len(suffix) - 1], suffix
    return item_id, None


def group_of(item_id, item):
    base, _ = split_variant(item_id)
    if item["category"] == "CROP" and base not in CROP_EXCLUDE:
        return "crop"
    if base in PRODUCE:
        return "crop"
    if base in FORAGE:
        return "forage"
    if base in ANIMAL:
        return "animal"
    if base in ARTISAN:
        return "artisan"
    return None


def load_products():
    """input id -> set of output ids."""
    uses = {}

    def add(src, dst):
        uses.setdefault(src, set()).add(dst)

    recipes = os.path.join(ROOT, "resources", "cooking", "recipes")
    for name in os.listdir(recipes):
        if not name.endswith(".tres"):
            continue
        text = read(os.path.join(recipes, name))
        out = re.search(r'path="res://resources/item_data/([^"]+)\.tres" id="2_output"', text)
        block = re.search(r"ingredients = Dictionary\[String, int\]\(\{(.*?)\}\)", text, re.S)
        if out and block:
            for ing in re.findall(r'"([^"]+)":', block.group(1)):
                add(ing, out.group(1))
    for folder in ("preserves_jar", "dehydrator"):
        path = os.path.join(ROOT, "resources", folder)
        for name in os.listdir(path):
            if name.endswith(".tres"):
                text = read(os.path.join(path, name))
                src, dst = field(text, "input_item_id"), field(text, "output_item_id")
                if src and dst:
                    add(src.strip('"'), dst.strip('"'))
    sm = read(os.path.join(ROOT, "autoload", "structure_manager.gd"))
    block = re.search(r"const ARTISANS := \{(.*?)\n\}", sm, re.S)
    for src, dst in re.findall(r'"([a-z_]+)": "([a-z_]+)"', block.group(1)):
        add(src, dst)
    return uses


def main():
    dry = "--dry-run" in sys.argv
    items = load_items()
    uses = load_products()
    edible = {i: g for i, it in items.items() if (g := group_of(i, it))}
    value = {i: it["stamina"] for i, it in items.items() if it["category"] == "FOOD"}

    def base_value(item_id):
        k, lo, hi = GROUPS[edible[item_id]]
        return max(lo, min(hi, round(k * math.sqrt(max(items[item_id]["sell"], 1)))))

    def cap_of(base, ratio):
        products = [value[p] for p in uses.get(base, ()) if p in value and value[p] > 0]
        return (min(products), math.floor(ratio * min(products))) if products else (None, None)

    bases = sorted({split_variant(i)[0] for i in edible if split_variant(i)[0] in items})
    # Artisan first so raw inputs are capped against their final artisan value.
    order = [b for b in bases if edible.get(b) == "artisan"] + [b for b in bases if edible.get(b) != "artisan"]
    report = []
    for _ in range(3):
        for b in order:
            v = base_value(b)
            product, cap = cap_of(b, CAP_RATIO)
            if cap is not None:
                v = max(1, min(v, cap))
            value[b] = v
    for b in order:
        product, cap = cap_of(b, CAP_RATIO)
        report.append((b, edible[b], items[b]["sell"], value[b], product))
    for item_id in sorted(edible):
        base, suffix = split_variant(item_id)
        if suffix is None or base not in value:
            continue
        v = min(VARIANT_MAX[edible[item_id]], max(value[base] + 1, round(value[base] * VARIANTS[suffix])))
        product, cap = cap_of(base, VARIANT_CAP_RATIO)
        if cap is not None:
            v = max(value[base], min(v, cap))
        value[item_id] = v
        report.append((item_id, edible[item_id], items[item_id]["sell"], v, product))

    changed = 0
    for item_id in edible:
        if item_id not in value:
            continue
        path = os.path.join(ITEMS, items[item_id]["file"])
        text = read(path)
        new = re.sub(r"^edible = .*\n", "", text, flags=re.M)
        new = re.sub(r"^stamina_restore = .*\n", "", new, flags=re.M)
        new = re.sub(r"(\[resource\]\nscript = [^\n]+\n)",
                     lambda m: m.group(1) + "edible = true\nstamina_restore = %d\n" % value[item_id], new, count=1)
        if new != text:
            changed += 1
            if not dry:
                with open(path, "w", encoding="utf-8", newline="\n") as f:
                    f.write(new)
    report.sort(key=lambda r: (r[1], r[0]))
    for r in report:
        print("%-28s %-8s sell=%-5d stamina=%-3d min_product=%s" % r)
    print("edible items: %d, files changed: %d%s" % (len(edible), changed, " (dry run)" if dry else ""))


if __name__ == "__main__":
    main()
