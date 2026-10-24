"""Run from any directory: python tools/validate_npc_data.py. No dependencies."""
import json
import re
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ERRORS = []
WARNINGS = []
MAPS = {name: ROOT / f"scenes/world/{'interior/' if name.endswith('_home') else ''}{name}.tscn"
        for name in ('farm', 'town', 'hill', 'wira_home', 'ubay_home', 'eep_ranch', 'eep_home')}
MAPS['university'] = ROOT / 'scenes/world/interior/university.tscn'


def require(ok, location, message):
    if not ok:
        ERRORS.append(f'{location}: {message}')


def unique(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f'duplicate key: {key}')
        result[key] = value
    return result


def load(path):
    return json.loads(path.read_text(encoding='utf-8-sig'), object_pairs_hook=unique,
                      parse_constant=lambda value: (_ for _ in ()).throw(ValueError(value)))


def strings(value):
    return isinstance(value, list) and all(isinstance(item, str) and item for item in value)


def time(value):
    return isinstance(value, str) and re.fullmatch(r'(?:[01]\d|2[0-3]):[0-5]\d', value) is not None


def gift_tastes(data, location, items):
    tastes = data.get('gift_tastes', {})
    seen = set()
    aliases = {'loved': 'love', 'liked': 'like', 'neutral': 'neutral', 'disliked': 'dislike', 'hated': 'hate'}
    for key, alias in aliases.items():
        values = tastes.get(key, tastes.get(alias, data.get(key + '_items', [])))
        require(strings(values), location, f'{key} gifts must be an array of item IDs')
        if not strings(values):
            continue
        require(len(values) == len(set(values)), location, f'duplicate item in {key}')
        require(not seen.intersection(values), location, f'items occur in multiple gift categories: {sorted(seen.intersection(values))}')
        seen.update(values)
        unknown = sorted(set(values) - items)
        if unknown:
            WARNINGS.append(f'{location}/{key}: item IDs not created yet: {", ".join(unknown)}')
        for item_id in set(values) & items:
            path = ROOT / f'resources/item_data/{item_id}.tres'
            require(path.is_file(), location, f'item cannot resolve by id: {item_id}')
            if path.is_file():
                content = path.read_text(encoding='utf-8-sig')
                category = re.search(r'^category = (\d+)', content, re.M)
                require(not category or int(category[1]) not in (3, 7, 8), location, f'ungiftable item: {item_id}')
                require(not item_id.startswith('biji_daya'), location, f'protected item: {item_id}')
                require(re.search(r'^icon = ', content, re.M), location, f'missing item icon: {item_id}')


def dialogue(value, location, expressions):
    entries = value if isinstance(value, list) else [value]
    for entry in entries:
        if isinstance(entry, str):
            require(bool(entry.strip()), location, 'empty dialogue')
        elif isinstance(entry, dict):
            require(isinstance(entry.get('text'), str) and bool(entry['text'].strip()), location, 'dialogue text required')
            require(strings(entry.get('requires_flags', [])), location, 'requires_flags must be an array of strings')
            require(entry.get('expression', 'neutral') in expressions, location, 'unknown portrait expression')
        else:
            require(False, location, 'dialogue must contain strings or objects')


def main():
    items = set()
    recipe_ids = set()
    for path in (ROOT / 'resources/cooking/recipes').glob('*.tres'):
        recipe_ids.update(re.findall(r'^id = "([^"]+)"', path.read_text(encoding='utf-8-sig'), re.M))
    for path in (ROOT / 'resources').rglob('*.tres'):
        items.update(re.findall(r'^item_id = "([^"]+)"', path.read_text(encoding='utf-8-sig'), re.M))
    markers = {name: set(re.findall(r'\[node name="([^"]+)"[^\n]*parent="NPCPoints"', path.read_text(encoding='utf-8-sig')))
               for name, path in MAPS.items()}
    residents = {}
    stories = []
    events = {}
    for path in sorted((ROOT / 'data/npc').glob('*.json')):
        loc = path.name
        try:
            data = load(path)
            require(isinstance(data, dict), loc, 'root must be an object')
            if not isinstance(data, dict):
                continue
            if 'reveals' in data:
                stories.append((loc, data))
                continue
            npc_id = data.get('id')
            require(isinstance(npc_id, str) and bool(npc_id), loc, 'id required')
            require(npc_id not in residents, loc, 'duplicate NPC id')
            residents[npc_id] = data
            for field in ('name', 'role', 'biography', 'gender', 'home_map'):
                require(isinstance(data.get(field), str) and bool(data[field]), loc, f'missing {field}')
            require(type(data.get('age')) is int and data['age'] > 0, loc, 'age must be positive')
            require(strings(data.get('personality', [])) and bool(data.get('personality')), loc, 'personality required')
            service = data.get('service')
            service_type = service.get('type') if isinstance(service, dict) else service
            require(service_type in (None, '', 'shipping', 'carpenter', 'livestock', 'blacksmith', 'shop'), loc, 'unsupported service.type')
            if isinstance(service, dict):
                require(strings(service.get('available_activities', [])), loc, 'available_activities must be an array of strings')
                require(strings(service.get('closed_days', [])), loc, 'closed_days must be an array of strings')
                if service.get('presentation'):
                    require((ROOT / service['presentation'].removeprefix('res://')).is_file(), loc, 'missing service presentation resource')
                if service.get('supplies_shop'):
                    require((ROOT / service['supplies_shop'].removeprefix('res://')).is_file(), loc, 'missing supplies shop resource')
                if service_type == 'shop':
                    require(bool(service.get('stock')), loc, 'shop stock required')
                    for offer in service.get('stock', []):
                        require(offer.get('item') in items and type(offer.get('price')) is int and offer['price'] > 0, loc, 'invalid shop offer')
                        item_path = ROOT / 'resources/item_data' / (str(offer.get('item')) + '.tres')
                        if item_path.is_file():
                            price = re.search(r'^sell_price = (\d+)', item_path.read_text(encoding='utf-8-sig'), re.M)
                            require(not price or offer['price'] > int(price[1]), loc, 'shop offer must cost more than resale value')
            require(strings(data.get('offscreen_activities', [])), loc, 'offscreen_activities must be an array of strings')
            birthday = data.get('birthday', {'season': data.get('birthday_season'), 'day': data.get('birthday_day')})
            require(birthday.get('season') in ('spring', 'summer', 'fall', 'autumn', 'winter'), loc, 'invalid birthday season')
            require(type(birthday.get('day')) is int and 1 <= birthday['day'] <= 28, loc, 'birthday day must be 1..28')
            settings = data.get('friendship', {})
            maximum = settings.get('max_hearts', 10)
            require(type(maximum) is int and maximum > 0, loc, 'max_hearts must be a positive integer')
            require(type(settings.get('start', 0)) is int and 0 <= settings.get('start', 0) <= maximum * 250, loc, 'friendship.start outside point range')
            visual = data['visual']
            for field in ('sprite_frames', 'portrait'):
                require((ROOT / visual[field].removeprefix('res://')).is_file(), loc, f'missing visual.{field}: {visual[field]}')
            expressions = visual.get('expressions', visual.get('expression', {}))
            portrait_path = ROOT / visual['portrait'].removeprefix('res://')
            portrait_size = struct.unpack('>II', portrait_path.read_bytes()[16:24]) if portrait_path.is_file() and portrait_path.suffix == '.png' else None
            for key, value in expressions.items():
                require((type(value) is int and value >= 0) or (isinstance(value, list) and len(value) == 2 and all(type(n) is int and n >= 0 for n in value)), loc, f'invalid expression index {key}')
                if portrait_size:
                    columns, cell_size = visual.get('portrait_columns', 5), visual.get('portrait_cell_size', 64)
                    x, y = (value % columns, value // columns) if type(value) is int else value
                    require((x + 1) * cell_size <= portrait_size[0] and (y + 1) * cell_size <= portrait_size[1], loc, f'portrait expression outside sheet: {key}')
            for section in ('dialogue', 'dialogue_by_hearts', 'gift_dialogue', 'romance_dialogue'):
                for key, lines in data.get(section, {}).items():
                    if section == 'dialogue_by_hearts':
                        require(str(key).isdigit() and int(key) <= maximum, loc, 'heart dialogue threshold exceeds maximum')
                    dialogue(lines, f'{loc}/{section}/{key}', expressions)
            for weather, entries in data['schedules'].items():
                require(bool(entries), loc, f'empty {weather} schedule')
                previous = ''
                for entry in entries:
                    require(time(entry.get('time')), loc, f'invalid time: {entry.get("time")}')
                    require(entry['time'] > previous, loc, f'{weather} schedule must have unique ascending times')
                    previous = entry['time']
                    require(entry.get('point') in markers.get(entry.get('map'), set()), loc, f'missing marker {entry.get("map")}/{entry.get("point")}')
                    require(entry.get('activity') in data['dialogue'], loc, f'missing activity dialogue {entry.get("activity")}')
            tastes = data.get('gift_tastes', {})
            for ignored in ('likes', 'loves', 'dislikes', 'hates'):
                require(ignored not in data, loc, f'{ignored} is not read by the gift system; use gift_tastes')
            gift_tastes(data, loc, items)
            for event in data.get('heart_events', []):
                require(event.get('id') not in events, loc, 'duplicate event id')
                events[event['id']] = npc_id
                require(event.get('point') in markers.get(event.get('map'), set()), loc, 'missing heart event marker')
                require(type(event.get('hearts')) is int and 0 <= event['hearts'] <= maximum, loc, 'invalid event heart threshold')
                require(strings(event.get('requires_flags', [])) and strings(event.get('sets_flags', [])), loc, 'invalid event flags')
                require(event.get('weather', 'any') in ('any', 'clear', 'sunny', 'rain', 'rainy', 'storm', 'snow'), loc, 'unsupported event weather')
                window = event.get('time_range', [])
                require(isinstance(window, list) and len(window) == 2 and all(time(t) for t in window), loc, 'invalid event time_range')
                dialogue(event.get('lines', []), loc + '/heart_events', expressions)
            require({2, 4, 6, 8, 10}.issubset({event.get('hearts') for event in data.get('heart_events', [])}), loc, 'missing heart milestone')
            require(all(str(hearts) in data.get('dialogue_by_hearts', {}) for hearts in (2, 4, 6, 8, 10)), loc, 'missing heart dialogue tier')
            require(all(key in data.get('schedules', {}) for key in ('default', 'rainy')), loc, 'default and rainy schedules required')
            if data.get('anchored'):
                require(len({(entry['map'], entry['point']) for entries in data['schedules'].values() for entry in entries}) == 1, loc, 'anchored residents must keep one physical location')
        except (ValueError, KeyError, TypeError, AttributeError) as exc:
            ERRORS.append(f'{loc}: {exc}')
    social = load(ROOT / 'data/npc/social/gift_profiles.json')
    for npc_id, profile in social.items():
        require(npc_id not in residents, npc_id, 'duplicate resident/social profile')
        gift_tastes(profile, f'gift_profiles.json/{npc_id}', items)
    for loc, story in stories:
        for reveal in story.get('reveals', []):
            require(events.get(reveal.get('id')) == reveal.get('npc'), loc, 'story reveal does not match an NPC heart event')
    household_path = ROOT / 'data/npc/social/household_rules.json'
    household = load(household_path)
    require(type(household.get('minimum_house_level')) is int and 1 <= household['minimum_house_level'] <= 3, household_path.name, 'invalid minimum house level')
    require(type(household.get('ceremony_delay')) is int and household['ceremony_delay'] >= 1, household_path.name, 'ceremony delay must be positive')
    require(type(household.get('roommate_hearts')) is int and 1 <= household['roommate_hearts'] <= 10, household_path.name, 'invalid roommate heart threshold')
    for npc_id in household.get('roommates', []):
        require(npc_id in residents and not residents[npc_id].get('romanceable', False), household_path.name, f'roommate must be a registered nonromantic resident: {npc_id}')
    for npc_id, rewards in household.get('recipe_rewards', {}).items():
        require(npc_id in residents, household_path.name, f'unknown recipe sender: {npc_id}')
        for reward in rewards:
            require(type(reward.get('hearts')) is int and 1 <= reward['hearts'] <= 10, household_path.name, 'invalid reward heart threshold')
            require(reward.get('recipe') in recipe_ids, household_path.name, f'unknown recipe ID: {reward.get("recipe")}')
            for item_id, count in reward.get('items', {}).items():
                require(item_id in items and type(count) is int and 1 <= count <= 999, household_path.name, f'invalid reward item/count: {item_id}')
    require(set(household.get('recipe_rewards', {})) == set(residents), household_path.name, 'every resident must have social mail rewards')
    database = (ROOT / 'scenes/npc/npc_database.tscn').read_text(encoding='utf-8-sig')
    registered = {}
    for source in re.findall(r'path="res://(resources/npc_data/characters/[^\"]+_resident.tres)"', database):
        profile = (ROOT / source).read_text(encoding='utf-8-sig')
        match = re.search(r'^npc_id = "([^"]+)"', profile, re.M)
        require(match is not None, source, 'resident profile ID required')
        if match:
            require(match[1] not in registered, source, 'duplicate resident registration')
            registered[match[1]] = source
    require(set(registered) == set(residents), 'NPCDatabase', 'JSON residents and registered profiles must match')
    for message in ERRORS:
        print('ERROR:', message)
    for message in WARNINGS:
        print('WARNING:', message)
    print(f'NPC JSON: {len(residents)} residents, {len(social)} social profiles, {len(stories)} story file(s), {len(ERRORS)} error(s), {len(WARNINGS)} warning(s)')
    return bool(ERRORS)


if __name__ == '__main__':
    raise SystemExit(main())
