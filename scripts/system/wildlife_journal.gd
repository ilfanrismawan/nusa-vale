class_name WildlifeJournal
extends RefCounted
## Catatan Satwa (GDD 4.10.13): satwa liar yang pernah diamati dari dekat tanpa membuatnya kabur.
## Data per save di GameState.wildlife_seen {id: kali diamati}; id = nama file resources/wildlife/<id>.tres.
## Jenis baru memberi EXP Peramu; catatan lengkap memberi bonus sekali.

const FIRST_EXP := 20
const COMPLETE_EXP := 100
## Pertama kali memberi makan satu jenis satwa.
const FEED_EXP := 10
## Kunci catatan lengkap di wildlife_seen (bukan id satwa).
const COMPLETE_KEY := "_complete"
## Awalan kunci jumlah pemberian makan: "fed:<id>".
const FED_PREFIX := "fed:"


static func id_of(data: Resource) -> String:
	return data.resource_path.get_file().get_basename()


static func ids() -> PackedStringArray:
	var result: PackedStringArray = []
	for data in load("res://scripts/world/wildlife_spawner.gd").all_data():
		result.append(id_of(data))
	result.sort()
	return result


static func seen_count() -> int:
	var count := 0
	for id in ids():
		count += 1 if int(GameState.wildlife_seen.get(id, 0)) > 0 else 0
	return count


## Mencatat satu pengamatan. Mengembalikan true bila jenisnya baru.
static func observe(data: Resource, player_data: PlayerData) -> bool:
	var id := id_of(data)
	var first := int(GameState.wildlife_seen.get(id, 0)) == 0
	GameState.wildlife_seen[id] = mini(int(GameState.wildlife_seen.get(id, 0)) + 1, 9999)
	if not first:
		return false
	SkillSystem.gain(player_data, &"forager", FIRST_EXP)
	var count := seen_count()
	Notify.say("Kamu mengamati %s dari dekat. Catatan Satwa %d/%d." % [data.display_name, count, ids().size()])
	if count >= ids().size() and not GameState.wildlife_seen.has(COMPLETE_KEY):
		GameState.wildlife_seen[COMPLETE_KEY] = 1
		SkillSystem.gain(player_data, &"forager", COMPLETE_EXP)
		Notify.say("Catatan Satwa lengkap! Pengamat sejati: +%d EXP Peramu." % COMPLETE_EXP)
	return true


## Mencatat pemberian makan. Jenis yang pertama kali diberi makan memberi EXP Peramu.
static func feed(data: Resource, food: ItemData, player_data: PlayerData) -> void:
	var key := FED_PREFIX + id_of(data)
	var first := int(GameState.wildlife_seen.get(key, 0)) == 0
	GameState.wildlife_seen[key] = mini(int(GameState.wildlife_seen.get(key, 0)) + 1, 9999)
	if first:
		SkillSystem.gain(player_data, &"forager", FEED_EXP)
	Notify.say("Kamu memberi %s kepada %s. Ia jinak padamu." % [food.display_name, data.display_name])


static func fed_count(data: Resource) -> int:
	return int(GameState.wildlife_seen.get(FED_PREFIX + id_of(data), 0))


static func text() -> String:
	var lines: PackedStringArray = []
	var hints := {"any": "kapan saja", "day": "siang", "night": "malam", "twilight": "senja"}
	for data in load("res://scripts/world/wildlife_spawner.gd").all_data():
		var count := int(GameState.wildlife_seen.get(id_of(data), 0))
		if count > 0:
			var fed := fed_count(data)
			lines.append("%s · diamati %dx%s (%s)" % [data.display_name, count, (", diberi makan %dx" % fed) if fed > 0 else "", hints.get(data.time, data.time)])
		else:
			lines.append("???")
	lines.sort()
	var header := "CATATAN SATWA (%d/%d)%s" % [seen_count(), ids().size(), " · lengkap" if GameState.wildlife_seen.has(COMPLETE_KEY) else ""]
	return header + "\nDekati pelan tanpa berlari, berhenti di luar jarak kabur, lalu tunggu sejenak.\n\n" + "\n".join(lines)


static func valid_save(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	for key in value:
		if not key is String or not RanchHusbandry.integer(value[key]) or int(value[key]) < 0 or int(value[key]) > 9999:
			return false
	return true


static func load_save(value: Variant) -> void:
	GameState.wildlife_seen = (value as Dictionary).duplicate() if valid_save(value) else {}
