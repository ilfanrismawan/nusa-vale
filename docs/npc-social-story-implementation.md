# Lanjutan implementasi NPC: dialog, relationship, layanan, heart event, dan save

Kerjakan berurutan. Panduan ini menyesuaikan file proyek saat pemeriksaan tanggal
20 Oktober 2026. Normalizer di `resident_profile.gd` sudah terpasang.
Kode di bawah adalah perubahan yang perlu Anda terapkan; bukan laporan bahwa
fitur-fitur ini sudah dipasang atau diuji dalam game.

Selesaikan sintaks JSON Wira lebih dahulu. Tambahkan aset, profil, marker dan
Path2D Zarathia/Zarathustra sesuai panduan registrasi sebelumnya.

## 1. Siapkan data progres per pemain (dasar untuk bagian 3–7)

Buka `scripts/system/player_data.gd`. Tambahkan variabel dan fungsi berikut di
level kelas, sejajar dengan `friendships`.

```gdscript
var story_flags: Dictionary = {}
var completed_events: Dictionary = {}
# NPC ID -> "dating" atau "married". Tidak ada entri berarti single.
var romances: Dictionary = {}

func has_story_flags(required: Variant) -> bool:
	if not (required is Array or required is PackedStringArray):
		return false
	for flag in required:
		if not bool(story_flags.get(str(flag), false)):
			return false
	return true

func social_progress() -> Dictionary:
	return {
		"flags": story_flags.duplicate(true),
		"events": completed_events.duplicate(true),
		"romances": romances.duplicate(true)
	}

static func valid_social_progress(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	for key in ["flags", "events", "romances"]:
		var entries: Variant = value.get(key, {})
		if not entries is Dictionary or entries.size() > 2048:
			return false
		for id in entries:
			if not id is String or id.is_empty() or id.length() > 256:
				return false
			if key == "romances":
				if not entries[id] is String or entries[id] not in ["dating", "married"]:
					return false
			elif not entries[id] is bool:
				return false
	return true

func load_social_progress(value: Variant) -> void:
	story_flags.clear()
	completed_events.clear()
	romances.clear()
	if not valid_social_progress(value):
		return
	story_flags = value.get("flags", {}).duplicate(true)
	completed_events = value.get("events", {}).duplicate(true)
	romances = value.get("romances", {}).duplicate(true)
```

Di awal `reset_to_starter()`, tambahkan:

```gdscript
	story_flags.clear()
	completed_events.clear()
	romances.clear()
```

Di dictionary hasil `to_dict()`, tambahkan satu field:

```gdscript
		"npc_progress": social_progress(),
```

Di awal `load_dict(data: Dictionary)`, tambahkan:

```gdscript
	load_social_progress(data.get("npc_progress", {}))
```

## 2. Buat resolver dialog (bagian 3)

Ganti seluruh isi `scripts/npc/npc_dialogue_resolver.gd` dengan:

```gdscript
class_name NPCDialogueResolver
extends RefCounted

static func packet(raw: Variant, player_data: PlayerData) -> Dictionary:
	var lines := PackedStringArray()
	var expressions := PackedStringArray()
	var entries: Array = []
	if raw is Array:
		entries = raw
	elif raw is PackedStringArray:
		entries = Array(raw)
	elif raw is String or raw is Dictionary:
		entries = [raw]
	for entry in entries:
		var text := ""
		var expression := "neutral"
		if entry is String:
			text = entry
		elif entry is Dictionary:
			var required: Variant = entry.get("requires_flags", [])
			if player_data == null:
				if not required is Array or not required.is_empty():
					continue
			elif not player_data.has_story_flags(required):
				continue
			text = str(entry.get("text", ""))
			expression = str(entry.get("expression", entry.get("expressions", "neutral")))
		if not text.is_empty():
			lines.append(text)
			expressions.append(expression)
	return {"lines": lines, "expressions": expressions}

static func resolve(player_data: PlayerData, npc_id: String, activity: String) -> Dictionary:
	var definition: Dictionary = NPCDatabase.residents.get(npc_id, {})
	var dialogue: Dictionary = definition.get("dialogue", {})
	var result := packet(dialogue.get(activity, []), player_data)
	if result.lines.is_empty():
		result = packet(dialogue.get("default", []), player_data)
	var hearts := int(float(NPCSocialService.points(player_data, npc_id)) / NPCSocialService.POINTS_PER_HEART)
	var tiers: Dictionary = definition.get("dialogue_by_hearts", {})
	var best := -1
	for key in tiers:
		if not str(key).is_valid_int():
			continue
		var threshold := int(key)
		if threshold > hearts or threshold <= best:
			continue
		var candidate := packet(tiers[key], player_data)
		if not candidate.lines.is_empty():
			result = candidate
			best = threshold
	return result
```

Aturan pemilihan di atas: heart event diprioritaskan oleh actor pada langkah 6;
untuk obrolan biasa, tier hati tertinggi yang memenuhi syarat menggantikan
dialog aktivitas. Jika tidak ada tier yang cocok, gunakan aktivitas/default.

## 3. Perbarui relationship dan hadiah (bagian 4)

Buka `scripts/npc/npc_social_service.gd`. Pertahankan fungsi hadiah beserta
larangan alat, batas harian, batas mingguan, dan bonus ulang tahun yang ada.

Tambahkan fungsi berikut:

```gdscript
static func max_hearts(id: String) -> int:
	var definition: Dictionary = NPCDatabase.residents.get(id, {})
	var settings: Dictionary = definition.get("friendship", {})
	return maxi(1, int(settings.get("max_hearts", 10)))

static func max_points(id: String) -> int:
	return max_hearts(id) * POINTS_PER_HEART
```

Ganti fungsi `_entry()`:

```gdscript
static func _entry(data: PlayerData, id: String) -> Dictionary:
	if not data.friendships.has(id):
		var definition: Dictionary = NPCDatabase.residents.get(id, {})
		var settings: Dictionary = definition.get("friendship", {})
		data.friendships[id] = {
			"points": clampi(int(settings.get("start", 0)), 0, max_points(id)),
			"talk_day": 0, "gift_day": 0, "week": -1,
			"gifts": 0, "birthday_year": -1,
			"decay_day": DayCycle.current_day
		}
	var entry: Dictionary = data.friendships[id]
	entry.points = clampi(int(entry.points), 0, max_points(id))
	return entry
```

Ganti `advance()` dan `summary()`:

```gdscript
static func advance(data: PlayerData, day: int) -> void:
	for id: String in data.friendships:
		var entry: Dictionary = _entry(data, id)
		var start := maxi(int(entry.decay_day), int(entry.talk_day) + DECAY_GRACE_DAYS)
		if int(entry.points) < max_points(id):
			entry.points = maxi(0, int(entry.points) - maxi(0, day - start) * 2)
		entry.decay_day = maxi(int(entry.decay_day), day)

static func summary(data: PlayerData, id: String) -> String:
	var value := points(data, id)
	var hearts := int(float(value) / POINTS_PER_HEART)
	return "Persahabatan %d/%d hati · %d/%d" % [hearts, max_hearts(id), value, max_points(id)]
```

Di fungsi `talk()`, ganti baris pembatas poin menjadi:

```gdscript
	entry.points = mini(max_points(id), int(entry.points) + 20)
```

Ganti `_preference()` agar bisa membaca data mentah maupun hasil normalizer:

```gdscript
static func _preference(id: String, key: String) -> Variant:
	var definition: Dictionary = NPCDatabase.residents.get(id, {})
	if not definition.is_empty():
		if definition.has(key + "_items"):
			return definition[key + "_items"]
		var aliases := {"loved": "love", "liked": "like", "disliked": "dislike", "hated": "hate"}
		var tastes: Dictionary = definition.get("gift_tastes", {})
		return tastes.get(key, tastes.get(aliases.get(key, key), []))
	var legacy: NPCDefinition = NPCDatabase.get_definition(StringName(id))
	return legacy.get(key + "_items") if legacy != null else []
```

Ganti `_birthday()`:

```gdscript
static func _birthday(id: String) -> bool:
	var definition: Dictionary = NPCDatabase.residents.get(id, {})
	var birthday: Dictionary = definition.get("birthday", {})
	var season := str(definition.get("birthday_season", birthday.get("season", "")))
	var day := int(definition.get("birthday_day", birthday.get("day", 0)))
	var legacy: NPCDefinition = NPCDatabase.get_definition(StringName(id))
	if definition.is_empty() and legacy != null:
		season = legacy.birthday_season
		day = legacy.birthday_day
	if season == "autumn":
		season = "fall"
	return season == DayCycle.SEASONS[DayCycle.get_season()] and day == (DayCycle.current_day - 1) % DayCycle.DAYS_PER_SEASON + 1
```

Di `give()`, ganti pembatas poin:

```gdscript
	entry.points = clampi(int(entry.points) + delta, 0, max_points(id))
```

Di bagian akhir fungsi yang sama, setelah dictionary `responses`, ganti
`return` lama dengan:

```gdscript
	var definition: Dictionary = NPCDatabase.residents.get(id, {})
	var aliases := {"loved": "love", "liked": "like", "disliked": "dislike", "hated": "hate", "neutral": "neutral"}
	var dialogues: Dictionary = definition.get("gift_dialogue", {})
	var raw: Variant = dialogues.get(reaction, dialogues.get(aliases[reaction], []))
	var gift := NPCDialogueResolver.packet(raw, data)
	var message: String = responses[reaction]
	var expression := "happy" if delta > 0 else "annoyed"
	if not gift.lines.is_empty():
		message = gift.lines[0]
		expression = gift.expressions[0]
	return {"ok": true, "message": message, "taste": reaction, "points": delta, "expression": expression}
```

Di `valid_save()`, ganti kondisi terakhir:

```gdscript
		if entry.points > MAX_POINTS or entry.gifts > WEEKLY_GIFTS:
```

menjadi:

```gdscript
		if entry.gifts > WEEKLY_GIFTS:
```

Validasi angka maksimal 1.000.000 di loop sebelumnya tetap dipertahankan.
Ini mencegah save NPC dengan batas hati di atas 10 ditolak oleh batas global
lama. Pembatas sesuai konfigurasi diterapkan oleh `_entry()` saat runtime.

## 4. Muat cerita keluarga dan buat heart-event service (bagian 6)

Di `scripts/npc/npc_database.gd`, tambahkan variabel:

```gdscript
@export_file("*.json") var family_story_file := "res://data/npc/wira_family_story.json"
var family_story: Dictionary = {}
```

Tambahkan pemanggilan `_load_family_story()` pada awal `_ready()`, lalu
tambahkan fungsi:

```gdscript
func _load_family_story() -> void:
	family_story.clear()
	if family_story_file.is_empty():
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(family_story_file))
	if parsed is Dictionary:
		family_story = parsed
	else:
		push_error("Invalid family story JSON: " + family_story_file)
```

Buat `scripts/npc/npc_event_service.gd`:

```gdscript
class_name NPCEventService
extends RefCounted

static func _minutes(value: String) -> int:
	var parts := value.split(":")
	return int(parts[0]) * 60 + int(parts[1]) if parts.size() == 2 else 0

static func _merged(raw: Dictionary, npc_id: String) -> Dictionary:
	var event := raw.duplicate(true)
	var story: Dictionary = NPCDatabase.family_story
	var required: Array = event.get("requires_flags", []).duplicate()
	var flags: Array = event.get("sets_flags", []).duplicate()
	for reveal: Dictionary in story.get("reveals", []):
		if reveal.get("id") != event.get("id") or reveal.get("npc") != npc_id:
			continue
		event.hearts = maxi(int(event.get("hearts", 0)), int(reveal.get("hearts", 0)))
		for flag in reveal.get("requires_flags", []):
			if flag not in required:
				required.append(flag)
		for flag in reveal.get("sets_flags", []):
			if flag not in flags:
				flags.append(flag)
	event.requires_flags = required
	event.sets_flags = flags
	return event

static func find_event(data: PlayerData, npc_id: String, map_id: String, points_root: Node, player_position: Vector2, actor_position: Vector2) -> Dictionary:
	var definition: Dictionary = NPCDatabase.residents.get(npc_id, {})
	var hearts := int(float(NPCSocialService.points(data, npc_id)) / NPCSocialService.POINTS_PER_HEART)
	var now := DayCycle.hour * 60 + DayCycle.minute
	for raw: Dictionary in definition.get("heart_events", []):
		var event := _merged(raw, npc_id)
		var id := str(event.get("id", ""))
		if id.is_empty() or bool(data.completed_events.get(id, false)):
			continue
		if hearts < int(event.get("hearts", 0)) or not data.has_story_flags(event.requires_flags):
			continue
		if str(event.get("map", map_id)) != map_id:
			continue
		var weather := str(event.get("weather", "any"))
		if weather == "clear":
			weather = "sunny"
		elif weather == "rainy":
			weather = "rain"
		if weather != "any" and weather != GameState.weather.current:
			continue
		var window: Array = event.get("time_range", [])
		if window.size() == 2:
			var start := _minutes(str(window[0]))
			var end := _minutes(str(window[1]))
			var inside := (now >= start and now < end) if start <= end else (now >= start or now < end)
			if not inside:
				continue
		if event.has("point"):
			if points_root == null:
				continue
			var marker := points_root.get_node_or_null(NodePath(str(event.point))) as Node2D
			if marker == null:
				continue
			var radius := float(event.get("radius", 48.0))
			if player_position.distance_to(marker.global_position) > radius or actor_position.distance_to(marker.global_position) > radius:
				continue
		var packet := NPCDialogueResolver.packet(event.get("lines", []), data)
		if packet.lines.is_empty():
			continue
		return event
	return {}

static func complete(data: PlayerData, event: Dictionary) -> void:
	var id := str(event.get("id", ""))
	if id.is_empty() or bool(data.completed_events.get(id, false)):
		return
	data.completed_events[id] = true
	for flag in event.get("sets_flags", []):
		data.story_flags[str(flag)] = true
	var completion: Dictionary = NPCDatabase.family_story.get("completion", {})
	if not completion.is_empty() and data.has_story_flags(completion.get("requires_flags", [])):
		for flag in completion.get("sets_flags", []):
			data.story_flags[str(flag)] = true
```

Pada implementasi ini, event diperiksa ketika pemain memilih **Bicara** di
lokasi dan waktu yang sesuai. Bukan cutscene otomatis saat masuk map.

`reveals` pada cerita keluarga menambah syarat/flag pada `heart_events` yang
ID dan NPC-nya sama. Isi dialog tetap di `heart_events[].lines` pada JSON NPC.

`completion.event` bertipe mail belum dieksekusi oleh kode ini. Flag
`family_truth_known` sudah dihasilkan; pengiriman surat dua hari kemudian
memerlukan sistem antrean surat/mailbox tersendiri. Status dating/pernikahan
juga baru disiapkan untuk save, belum menambahkan tombol atau adegan menikah.

## 5. Bedakan dialog selesai dan dibatalkan

Di `scripts/ui/npc_dialog_ui.gd`, tambahkan:

```gdscript
var completed := false
var allow_gifts := true
var award_friendship := true
```

Di `_advance_dialog()`, ubah bagian akhir menjadi:

```gdscript
	if _current_line_idx >= lines.size():
		completed = true
		_close()
	else:
		_show_current_line()
```

Jangan set `completed = true` di `_close()`: Escape dan tombol silang harus
membatalkan event tanpa memberi flag penyelesaian.

Di `_ready()`, ganti blok mulai dari `if is_instance_valid(player) and
NPCSocialService.known(social_npc_id):` sampai `_update_social()` dengan:

```gdscript
	if is_instance_valid(player) and NPCSocialService.known(social_npc_id):
		if award_friendship:
			NPCSocialService.talk(player.data, social_npc_id)
		if allow_gifts:
			_gift_slot = player.data.hotbar_page * 8 + player.tool_controller.current_index
			_gift_button = Button.new()
			_gift_button.position = Vector2(160, 180)
			_gift_button.size = Vector2(535, 40)
			_gift_button.focus_mode = Control.FOCUS_NONE
			_gift_button.pressed.connect(_give_gift)
			$Design/Dialogue.add_child(_gift_button)
			_update_social()
```

Di `_give_gift()`, ganti pemilihan ekspresi setelah `if result.ok:` menjadi:

```gdscript
		set_expression(str(result.get("expression", "happy" if int(result.points) > 0 else "annoyed")))
```

## 6. Hubungkan resolver/event dengan actor dan menu (bagian 3 dan 5)

Di `scripts/npc/scheduled_npc.gd`, dalam `_ready()`, ganti:

```gdscript
		dialog_lines = PackedStringArray(definition.dialogue.default)
```

dengan:

```gdscript
		var initial := NPCDialogueResolver.packet(definition.get("dialogue", {}).get("default", []), null)
		dialog_lines = initial.lines
```

Pada `scripts/npc/npc_map_presenter.gd`, ganti field `dialog_lines` di
dictionary jadwal runtime menjadi:

```gdscript
			"dialog_lines": PackedStringArray()
```

Jangan lagi mengonversi objek dialog menjadi PackedStringArray di presenter.
Activity tetap diisi seperti sebelumnya; resolver dipanggil saat Bicara agar
nilai hati dan flag yang dipakai selalu terbaru.

Tambahkan fungsi berikut pada `scheduled_npc.gd`:

```gdscript
func _service_available() -> bool:
	var service := str(definition.get("service", ""))
	if service not in ["carpenter", "shipping"]:
		return false
	var rules: Dictionary = definition.get("service_rules", {})
	var activities: Array = rules.get("available_activities", [])
	if not activities.is_empty() and _current_activity not in activities:
		return false
	# Konvensi di sini: hari permainan pertama adalah Monday.
	var days := ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]
	var weekday: String = days[posmod(DayCycle.current_day - 1, 7)]
	for closed_day in rules.get("closed_days", []):
		if str(closed_day).to_lower() == weekday:
			return false
	return true

func _open_resident_dialog(player: Player) -> void:
	var world := get_parent().get_parent()
	var presenter := world.get_node_or_null("NPCMapPresenter")
	var map_id := str(presenter.map_id) if presenter != null else ""
	var points := world.get_node_or_null("NPCPoints")
	var event := NPCEventService.find_event(player.data, npc_id, map_id, points, player.global_position, global_position)
	var packet: Dictionary
	if event.is_empty():
		packet = NPCDialogueResolver.resolve(player.data, npc_id, _current_activity)
	else:
		packet = NPCDialogueResolver.packet(event.get("lines", []), player.data)
	_show_packet(packet, player, event)

func _show_packet(packet: Dictionary, player: Player, event: Dictionary = {}) -> void:
	if packet.lines.is_empty():
		return
	var ui := load("res://scenes/ui/npc_dialog_ui.tscn").instantiate() as NPCDialogUI
	_dialog_ui = ui
	ui.player = player
	ui.npc_name = npc_name
	ui.social_npc_id = npc_id
	ui.role_title = role_title
	ui.portrait_texture = portrait
	ui.portrait_expressions = portrait_expressions
	ui.lines = packet.lines
	ui.line_expressions = packet.expressions
	ui.allow_gifts = event.is_empty()
	ui.award_friendship = event.is_empty()
	ui.finished.connect(func():
		if ui.completed and not event.is_empty():
			NPCEventService.complete(player.data, event)
		_on_dialog_finished()
	)
	Coop.ui_parent(player).add_child(ui)
```

Di `interact()`, ganti pengisian layanan menu dengan:

```gdscript
	_service_menu.service = str(definition.get("service", "")) if _service_available() else ""
```

Ganti **seluruh** fungsi `_choose_service()` dengan:

```gdscript
func _choose_service(index: int, player: Player) -> void:
	_service_menu.get_parent().remove_child(_service_menu)
	_service_menu.queue_free()
	_service_menu = null
	if player == null:
		return
	if index == 0:
		_open_resident_dialog(player)
	elif index == 1 and _service_available():
		var service := str(definition.get("service", ""))
		if service == "carpenter":
			_service_menu = load("res://scenes/ui/carpenter_menu.tscn").instantiate()
			_service_menu.player = player
			_service_menu.vendor_name = npc_name
			_service_menu.vendor_portrait = portrait
			_service_menu.finished.connect(func(): _service_menu = null)
			Coop.ui_parent(player).add_child(_service_menu)
		elif service == "shipping":
			var packet := NPCDialogueResolver.packet([
				"Pengambilan visual berlangsung pukul 17.00–17.30.",
				"Hasil jualan tetap diproses saat kamu tidur."
			], player.data)
			_show_packet(packet, player)
```

Di `scripts/ui/resident_service_menu.gd`, setelah pengisian teks `%Service`,
tambahkan:

```gdscript
	%Service.visible = service in ["carpenter", "shipping"]
```

Hasilnya: NPC tanpa layanan hanya mempunyai Bicara dan Tutup. Layanan yang
sedang tutup juga tidak ditampilkan dan diperiksa kembali saat tombol dipilih.

## 7. Sambungkan save P1 dan validasinya (bagian 7)

Di `autoload/save_manager.gd`:

1. Naikkan `SAVE_VERSION` satu angka. Saat pemeriksaan nilainya 22, jadi 23.
2. Pada `_build_save_data()`, di dictionary `player`, tepat setelah field
   `friendships`, tambahkan:

```gdscript
			"npc_progress": GameState.p1().social_progress(),
```

3. Pada `_apply_save()`, setelah `GameState.p1().load_friendships(...)`, tambahkan:

```gdscript
	GameState.p1().load_social_progress(player_data.get("npc_progress", {}))
```

4. Pada `_valid_player()`, setelah validasi `friendships`, tambahkan:

```gdscript
	if not PlayerData.valid_social_progress(player.get("npc_progress", {})):
		return false
```

P2 dan pemain co-op lainnya memakai `PlayerData.to_dict()` / `load_dict()`
yang telah diperbarui pada langkah 1. Semua pemanggilan `get(..., {})`
disengaja agar save lama yang belum memiliki field baru tetap bisa dimuat.

Field `romances` kini dapat menyimpan status secara terpisah per pemain.
Menambahkan UI pengakuan cinta, validasi pasangan, perubahan jadwal pasangan,
atau upacara pernikahan adalah pekerjaan lanjutan; jangan langsung menganggap
field `romance` di JSON telah menjalankan seluruh mekanik tersebut.

## 8. Uji dengan urutan berikut

Gunakan slot pengujian terpisah, bukan satu-satunya save permainan Anda.

1. Jalankan game setelah seluruh langkah selesai. Perbaiki error parser dahulu.
2. Bicara dengan Ubay (dialog string lama) dan Zarathia (objek dialog baru).
3. Pastikan ekspresi mengikuti setiap halaman dialog.
4. Atur poin Zarathia menjadi 1000 di debugger pada entri friendship-nya:
   1000 / 250 = 4 hati. Lakukan setelah entri NPC sudah dibuat melalui obrolan.
5. Datang ke Hill dekat `wira_overlook` saat cerah pukul 16.30–18.00,
   dengan Zarathia juga berada di dekat marker tersebut. Pilih Bicara.
6. Tekan Esc: event belum masuk completed_events dan flag belum diberikan.
7. Ulangi lalu baca sampai halaman terakhir dan tekan Selesai:
   completed_events berisi `zarathia_family_1`, flag `story_zarathia_told` true.
8. Bicara lagi: event tidak berulang. Dialog berflag sudah memenuhi syarat.
9. Beri hadiah love/like/dislike/hate; periksa poin dan respons sesuai JSON.
10. Periksa NPC service null tidak mempunyai Info Pengiriman.
11. Periksa Wira hanya membuka layanan pada aktivitas dan hari yang diizinkan.
12. Simpan, keluar, muat ulang: poin, flag, dan completed_events harus tetap ada.
13. Muat save lama tanpa npc_progress: tetap dapat dimuat dengan progres kosong.
14. Dalam co-op, selesaikan event sebagai P1: progres P2 tidak otomatis berubah.

Tidak ada penambahan autoload untuk NPCDialogueResolver atau NPCEventService:
keduanya menggunakan `class_name` dan fungsi static.
