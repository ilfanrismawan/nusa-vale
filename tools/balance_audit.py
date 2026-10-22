"""Reproducible cooking valuation and progression report (stdlib only).

Run without arguments for a dry report; --write-cooking-prices applies the
documented valuation to ItemData resources after validating the whole graph.
Godot regressions remain the authority for resolved runtime Resources.
"""
from pathlib import Path
import argparse
import json
import math
import re

ROOT = Path(__file__).resolve().parents[1]


def fields(path):
    text = path.read_text(encoding="utf-8-sig").split("[resource]")[-1]
    result = {}
    for key, raw in re.findall(r"^(\w+)\s*=\s*([^\n]+)", text, re.M):
        try:
            result[key] = json.loads(raw.strip())
        except ValueError:
            result[key] = raw.strip()
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--write-cooking-prices", action="store_true")
    parser.add_argument("--output")
    args = parser.parse_args()
    paths = {p.stem: p for p in (ROOT / "resources/item_data").glob("*.tres")}
    items = {key: fields(path) for key, path in paths.items()}
    recipes = {}
    for path in (ROOT / "resources/cooking/recipes").glob("*.tres"):
        raw = path.read_text(encoding="utf-8-sig")
        data = fields(path)
        refs = dict(re.findall(r'path="res://resources/item_data/([^"/]+)\.tres" id="([^"]+)"', raw))
        ref = re.fullmatch(r'ExtResource\("([^"]+)"\)', data.get("output_item", ""))
        output = next((name for name, rid in refs.items() if ref and rid == ref[1]), data["id"])
        match = re.search(r"ingredients\s*=.*?\{([^}]+)\}", raw, re.S)
        ingredients = {key: int(count) for key, count in re.findall(r'"([^"]+)"\s*:\s*(\d+)', match[1])}
        if output in recipes:
            raise ValueError(f"Multiple valuation recipes for {output}")
        recipes[output] = (ingredients, int(data.get("output_count", 1)))

    values, cash_costs, active = {}, {}, set()

    def value(item_id):
        if item_id in values:
            return values[item_id], cash_costs[item_id]
        if item_id not in items:
            raise ValueError(f"Unknown ingredient {item_id}")
        if item_id in active:
            raise ValueError(f"Cooking dependency cycle at {item_id}")
        active.add(item_id)
        data = items[item_id]
        buy = data.get("buy_price", 0)
        # Conservative: assume any positively priced ingredient can be bought.
        discount = 0.65 if data.get("category") == 1 else 0.85
        cash = max(1, math.floor(buy * discount + 0.5)) if buy > 0 else math.inf
        price = int(data.get("sell_price", 0))
        if item_id in recipes:
            ingredients, count = recipes[item_id]
            parts = [(n, value(key)) for key, n in ingredients.items()]
            opportunity = sum(n * pair[0] for n, pair in parts)
            crafted_cash = sum(n * pair[1] for n, pair in parts) / count
            cash = min(cash, crafted_cash)
            price = max(1, math.floor(opportunity * 1.10 / count + 0.5))
            if math.isfinite(cash):
                # All food shipping bonuses total at most 30%. Retain a 10%
                # spread even after best buy discount and all sale bonuses.
                price = min(price, max(1, math.floor(cash * 0.90 / 1.30)))
        active.remove(item_id)
        values[item_id], cash_costs[item_id] = price, cash
        return price, cash

    for output in recipes:
        value(output)
    rows = []
    for output, (ingredients, count) in sorted(recipes.items()):
        price, cash = value(output)
        total = sum(value(key)[0] * n for key, n in ingredients.items())
        rows.append({"item": output, "before": items[output].get("sell_price", 0), "after": price,
                     "count": count, "input_value": total,
                     "minimum_cash_cost_per_unit": cash if math.isfinite(cash) else None})
    if args.write_cooking_prices:
        for row in rows:
            path = paths[row["item"]]
            text = path.read_text(encoding="utf-8-sig")
            replacement = f'sell_price = {row["after"]}'
            if re.search(r"^sell_price\s*=", text, re.M):
                text = re.sub(r"^sell_price\s*=.*$", replacement, text, flags=re.M)
            else:
                text = text.rstrip() + "\n" + replacement + "\n"
            if row["before"] != row["after"]:
                path.write_text(text, encoding="utf-8")
    report = {"recipe_count": len(rows), "changed": sum(row["before"] != row["after"] for row in rows),
              "cooking": rows}
    copper = fields(ROOT / "resources/tool_data/pickaxe_copper.tres")["upgrade_cost_money"]
    starter_seeds = 5 * items["seed_strawberry"]["buy_price"] + 3 * items["seed_carrot"]["buy_price"]
    starter_gross = 10 * items["strawberry"]["sell_price"] + 3 * items["carrot"]["sell_price"]
    report["starter"] = {"cash": 100, "harvest_gross": starter_gross, "replant": starter_seeds,
                         "copper": copper, "remaining_after_both": 100 + starter_gross - starter_seeds - copper}
    report["house_prices"] = [fields(ROOT / f"resources/house/house_level_{n}.tres")["price"] for n in range(1, 4)]
    report["cash_scenarios"] = []
    for players, side_income in [(1, 0), (1, 205), (2, 205), (4, 205)]:
        # A wallet model, not an automated/manual playthrough. Initial free seeds;
        # five-day watered cycles, no crop losses, 5 side-activity days/week.
        money, plots = 100, 8 * players
        targets = [("copper_per_player", copper * players),
                   ("medium_bag_per_player", items["backpack_medium"]["buy_price"] * players),
                   ("iron_per_player", fields(ROOT / "resources/tool_data/pickaxe_iron.tres")["upgrade_cost_money"] * players),
                   ("kitchen_shared", report["house_prices"][0])]
        milestones, index, expanded = {}, 0, False
        for day in range(1, 113):
            if (day - 1) % 7 < 5:
                money += side_income * players
            if day >= 6 and (day - 1) % 5 == 0:
                money += starter_gross * (plots / 8)
                money -= starter_seeds * (plots / 8)  # replacement seeds reserved immediately
            if day >= 6 and index < len(targets) and money >= targets[index][1] + 35:
                name, cost = targets[index]
                money -= cost
                milestones[name] = day
                index += 1
            if index > 0 and not expanded and day >= 6 and (day - 1) % 5 == 0 and money >= starter_seeds * players + 35:
                money -= starter_seeds * players
                plots += 8 * players
                expanded = True
        report["cash_scenarios"].append({"players": players, "side_income_per_workday_per_player": side_income,
                                          "milestone_funding_days": milestones, "ending_cash": round(money)})
    report["cave_matched_armor"] = []
    for floor, tier, role_attack in [(3, "wood", 0), (8, "copper", 5), (15, "copper", 10), (30, "iron", 20), (50, "gold", 20), (70, "crimson", 20), (90, "shadow", 20)]:
        band_path = next(path for path in (ROOT / "resources/cave/bands").glob("*.tres")
                         if fields(path).get("first_floor", 1) <= floor <= fields(path).get("last_floor", 20))
        raw = band_path.read_text(encoding="utf-8-sig")
        defense = sum(items[part + "_" + tier].get("defense_bonus", 0) for part in ("helmet", "armor", "leggings", "boots"))
        enemies = re.findall(r'path="res://resources/enemies/([^"/]+)\.tres"', raw)
        report["cave_matched_armor"].append({"floor": floor, "armor": tier, "defense": defense,
            "reference_role_attack": role_attack,
            "basic_hits_to_defeat": {enemy: math.ceil(fields(ROOT / f"resources/enemies/{enemy}.tres").get("max_hp", 20) / max(1, items["sword_" + tier]["attack_bonus"] + role_attack - fields(ROOT / f"resources/enemies/{enemy}.tres").get("defense", 0))) for enemy in enemies},
            "incoming_damage": {enemy: max(1, fields(ROOT / f"resources/enemies/{enemy}.tres").get("attack", 5) - defense) for enemy in enemies}})
    if args.output:
        Path(args.output).write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f'Cooking valuation: {len(rows)} recipes, {report["changed"]} price changes; graph validated.')
    for row in rows:
        if row["item"] in ("coffee", "omelet", "butter", "apple_pie", "vegetable_soup"):
            print(f'{row["item"]}: {row["before"]} -> {row["after"]} G; inputs {row["input_value"]} G')


if __name__ == "__main__":
    main()
