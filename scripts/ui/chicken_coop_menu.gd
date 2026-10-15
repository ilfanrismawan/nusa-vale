extends "res://scripts/ui/structure_menu.gd"


func _ready() -> void:
	super._ready()
	_fit_panel.call_deferred()
	GameState.money_changed.connect(func(_money: int): _refresh())

func _fit_panel() -> void:
	await get_tree().process_frame
	_panel.size = Vector2(660, 440)
	var viewport_size := get_viewport().get_visible_rect().size
	_panel.scale = Vector2.ONE * minf(1.0, minf((viewport_size.x - 20) / 660, (viewport_size.y - 20) / 440))
	_panel.position = ((viewport_size - _panel.size * _panel.scale) / 2).floor()

func _refresh() -> void:
	var record := StructureManager.record_for(uid)
	if record.is_empty():
		_close()
		return
	var state := StructureManager.coop_state(record)
	_title.text = "%s · %d/%d · %s" % [GameState._resolve_item(record.item).display_name, state.chickens.size(), RanchHusbandry.capacity(state), ["Dasar", "Besar", "Deluxe"][int(state.tier)]]
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	var fed := 0
	var petted := 0
	for animal in state.chickens:
		fed += 1 if int(animal.fed_day) == DayCycle.current_day else 0
		petted += 1 if int(animal.pet_day) == DayCycle.current_day else 0
	_label(_content, "Hari %d · Kenyang %d/%d · Dielus %d/%d · Uang %d G" % [DayCycle.current_day, fed, state.chickens.size(), petted, state.chickens.size(), GameState.money])
	var feeding := ProgressBar.new()
	feeding.name = "FeedingProgress"
	feeding.max_value = maxi(1, state.chickens.size())
	feeding.value = fed
	feeding.show_percentage = false
	feeding.custom_minimum_size.y = 10
	_content.add_child(feeding)
	_build_care(state)
	if player.world_root().get_meta("structure_area", "") == "farm":
		var enter := _button("Masuk ke dalam kandang", _enter)
		enter.name = "EnterRanch"
		_content.add_child(enter)
	var actions := HBoxContainer.new()
	_content.add_child(actions)
	var hungry: int = state.chickens.size() - fed
	var feed_all := _button("Beri pakan semua (%d)" % hungry, _feed.bind(-1))
	feed_all.name = "FeedAll"
	feed_all.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	feed_all.disabled = hungry == 0 or _feed_count(str(record.item)) < hungry
	feed_all.tooltip_text = "Pakan diambil dari tas pemain ini."
	actions.add_child(feed_all)
	if record.item == "chicken_coop":
		var eggs := _button("Ambil telur (%d)" % RanchHusbandry.product_count(state), _eggs)
		eggs.name = "CollectEggs"
		eggs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		eggs.disabled = RanchHusbandry.product_count(state) == 0
		eggs.icon = GameState._resolve_item("chicken_egg").icon
		eggs.expand_icon = true
		eggs.add_theme_constant_override("icon_max_width", 16)
		actions.add_child(eggs)
	for animal in state.chickens:
		_build_animal(state, animal, str(record.item))
	if state.chickens.is_empty():
		_label(_content, "Kandang kosong. Beli hewan dari Rian di Toko Ternak, Kota.")
	_status.text = "Pagi: panen → pakan → elus/sikat → bersihkan. Alat & jerami tersedia di toko.\nHewan kurang sehat pulih setelah 1 hari makan dengan kandang bersih."

func _build_animal(state: Dictionary, animal: Dictionary, home: String) -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", ServiceTheme.dialogue())
	_content.add_child(card)
	var layout := VBoxContainer.new()
	card.add_child(layout)
	var row := HBoxContainer.new()
	layout.add_child(row)
	var picture := Control.new()
	picture.custom_minimum_size = Vector2(48, 48)
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(picture)
	var sprite := AnimatedSprite2D.new()
	var kind := RanchHusbandry.species(animal)
	sprite.sprite_frames = RanchVisual.frames(kind, str(animal.variant))
	sprite.position = Vector2(24, 24)
	sprite.scale = Vector2(2, 2) if kind in ["chicken", "duck"] else Vector2(1.5, 1.5)
	picture.add_child(sprite)
	sprite.play()
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	_label(text, "%s · %s" % [animal.name, RanchHusbandry.SPECIES[kind].name])
	var today := int(animal.fed_day) == DayCycle.current_day
	_label(text, "%s · Hati %d/5 (%d/100)" % ["Kenyang" if today else "Belum makan", int(animal.affection) / 20, int(animal.affection)]).add_theme_font_size_override("font_size", 14)
	var feed := _button("Pakan", _feed.bind(int(animal.id)))
	feed.disabled = today or _feed_count(home) < 1
	feed.tooltip_text = "Sudah makan hari ini" if today else "Perlu 1 pakan di tas: jerami untuk semua hewan, pakan ayam untuk unggas."
	row.add_child(feed)
	var pet := _button("Dielus" if int(animal.pet_day) == DayCycle.current_day else "Elus", _pet.bind(int(animal.id)))
	pet.disabled = int(animal.pet_day) == DayCycle.current_day
	row.add_child(pet)
	_label(layout, RanchHusbandry.condition(state, animal, DayCycle.current_day)).add_theme_font_size_override("font_size", 14)
	var info: Dictionary = RanchHusbandry.SPECIES[kind]
	if not str(info.tool).is_empty():
		var extras := HBoxContainer.new()
		layout.add_child(extras)
		var brush := _button("Disikat" if int(animal.brush_day) == DayCycle.current_day else "Sikat", _care.bind("brush", int(animal.id)))
		brush.disabled = int(animal.brush_day) == DayCycle.current_day or not player.data.has_item("animal_brush", 1)
		brush.tooltip_text = "Bawa Sikat Ternak dari toko. Bonus kasih sayang sekali sehari."
		extras.add_child(brush)
		var harvest := _button("Cukur wol" if info.tool == "shears" else "Perah susu", _care.bind("harvest", int(animal.id)))
		harvest.disabled = str(animal.ready).is_empty() or not player.data.has_item(info.tool, 1)
		harvest.tooltip_text = "Bawa %s di tas. Hasil siap setelah %d hari terawat." % [GameState._resolve_item(info.tool).display_name, int(info.interval)]
		extras.add_child(harvest)
		var ready := "Siap: " + GameState._resolve_item(animal.ready).display_name if not str(animal.ready).is_empty() else "Produksi %d/%d hari terawat" % [int(animal.progress), int(info.interval)]
		_label(extras, ready).add_theme_font_size_override("font_size", 14)

func _build_care(state: Dictionary) -> void:
	var count: int = state.chickens.size()
	var label := _label(_content, "Kotor %d/3 · Cadangan %d/240 jerami (%s) · Pakan di tas %d" % [int(state.dirt), int(state.hay), "%d hari" % (int(state.hay) / count) if count > 0 else "belum ada hewan", _feed_count(StructureManager.record_for(uid).item)])
	label.add_theme_font_size_override("font_size", 16)
	var care := HBoxContainer.new()
	_content.add_child(care)
	var clean := _button("Bersihkan (%d)" % int(state.dirt), _care.bind("clean", 0))
	clean.name = "CleanRanch"
	clean.icon = preload("res://assets/ranch/dirt.svg")
	clean.expand_icon = true
	clean.add_theme_constant_override("icon_max_width", 16)
	clean.disabled = int(state.dirt) == 0
	care.add_child(clean)
	care.add_child(_button("Tutup pintu" if state.door else "Buka: merumput", _care.bind("door", 0)))
	var stored := _button("Pakan cadangan", _care.bind("stored", 0))
	stored.disabled = int(state.hay) == 0
	care.add_child(stored)
	var stock := HBoxContainer.new()
	_content.add_child(stock)
	stock.add_child(_button("Simpan 10 jerami", _care.bind("store", 0)))
	stock.add_child(_button("Ambil 10 jerami", _care.bind("take", 0)))
	if int(state.tier) < 2:
		var first := int(state.tier) == 0
		var upgrade := _button("Upgrade %d G + %d kayu + %d batu" % [4000 if first else 8000, 150 if first else 250, 100 if first else 150], _care.bind("upgrade", 0))
		upgrade.name = "UpgradeRanch"
		stock.add_child(upgrade)
	else:
		_label(_content, "Auto-feeder: cadangan kandang lalu silo setiap pagi.")

func _feed_count(home: String) -> int:
	return player.data.get_item_count("hay") + (player.data.get_item_count("animal_feed") if home == "chicken_coop" else 0)

func _enter() -> void:
	var actor := player
	var building_uid := uid
	_close()
	StructureManager.enter_ranch.call_deferred(actor, building_uid)

func _feed(id: int) -> void:
	var result := StructureManager.feed_chickens(player.data, uid, id)
	_refresh()
	_status.text = result.message

func _pet(id: int) -> void:
	var result := StructureManager.pet_chicken(uid, id)
	_refresh()
	_status.text = result.message

func _eggs() -> void:
	var result := StructureManager.collect_eggs(player.data, uid)
	_refresh()
	_status.text = result.message

func _care(action: String, animal_id: int) -> void:
	var result: Dictionary
	match action:
		"clean": result = StructureManager.clean_ranch(player.data, uid)
		"brush": result = StructureManager.brush_animal(player.data, uid, animal_id)
		"harvest": result = StructureManager.harvest_animal(player.data, uid, animal_id)
		"door": result = StructureManager.toggle_ranch_door(uid)
		"stored": result = StructureManager.feed_stored(uid)
		"store": result = StructureManager.store_hay(player.data, uid)
		"take": result = StructureManager.take_hay(player.data, uid)
		"upgrade": result = StructureManager.upgrade_ranch(player.data, uid)
	_refresh()
	_status.text = result.message
