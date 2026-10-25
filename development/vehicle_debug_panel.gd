extends VBoxContainer
## Cheat kendaraan (GDD 10) di panel DebugManager (F1). Hanya dimuat saat play dari editor.
## Spawn = item kendaraan masuk tas pemain aktif; "Spawn & naiki" langsung menumpang.
## Kendaraan Kota Modern ikut diberikan walau area itu belum terbuka (toko tetap terkunci).

const VEHICLE_IDS := ["bicycle", "flying_broom", "electric_scooter", "pickup_truck"]

func _ready() -> void:
	var heading := Label.new()
	heading.text = "KENDARAAN"
	heading.add_theme_color_override("font_color", Color(1.0, 0.75, 0.3))
	heading.add_theme_font_size_override("font_size", 13)
	add_child(heading)
	for id in VEHICLE_IDS:
		var item := GameState._resolve_item(id)
		if item == null or item.vehicle == null:
			continue
		var row := HBoxContainer.new()
		add_child(row)
		_button(row, "Spawn %s" % item.display_name, spawn.bind(id, false))
		_button(row, "& naiki", spawn.bind(id, true))
	var all_row := HBoxContainer.new()
	add_child(all_row)
	_button(all_row, "Spawn semua kendaraan", spawn_all)
	_button(all_row, "Turun", dismount)

func _button(parent: Control, caption: String, action: Callable) -> void:
	var button := Button.new()
	button.text = caption
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(action)
	parent.add_child(button)

## Pemain aktif (co-op: pemain yang memegang GameState.current).
static func active_player(tree: SceneTree) -> Player:
	var fallback: Player
	for node in tree.get_nodes_in_group(Combat.PLAYER_GROUP):
		var player := node as Player
		if player == null:
			continue
		if player.data == GameState.current:
			return player
		if fallback == null:
			fallback = player
	return fallback

## Masukkan kendaraan ke tas (kalau belum punya). ride = langsung dinaiki.
func spawn(id: String, ride: bool) -> void:
	var item := GameState._resolve_item(id)
	var data := GameState.current
	if item == null or data == null:
		_notify("Kendaraan %s tidak ditemukan." % id)
		return
	if not data.has_item(id) and data.add_item(item, 1) > 0:
		_notify("Tas penuh, %s tidak muat." % item.display_name)
		return
	if not ride:
		_notify("%s masuk tas. Pegang di hotbar lalu tekan tombol Alat." % item.display_name)
		return
	var player := active_player(get_tree())
	if player == null:
		_notify("%s masuk tas, tapi pemain tidak ditemukan." % item.display_name)
		return
	if player.is_riding():
		player.dismount_vehicle()
	if player.mount_vehicle(item):
		_notify("Naik %s." % item.display_name)
	else:
		_notify("%s masuk tas, tapi tidak bisa dinaiki di sini (ruangan/sedang beraksi)." % item.display_name)

func spawn_all() -> void:
	var added := 0
	for id in VEHICLE_IDS:
		var item := GameState._resolve_item(id)
		if item != null and not GameState.current.has_item(id) and GameState.current.add_item(item, 1) == 0:
			added += 1
	_notify("%d kendaraan baru masuk tas." % added)

func dismount() -> void:
	var player := active_player(get_tree())
	if player != null and player.dismount_vehicle():
		_notify("Turun dari kendaraan.")

func _notify(message: String) -> void:
	print("[DEBUG] %s" % message)
	Notify.say("[DEBUG] " + message)
