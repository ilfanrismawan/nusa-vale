extends Node2D
## Penanda status hewan di atas kepala (GDD 4.10.4 "Cek pagi"): gelembung makan, elus, sikat, dan hasil siap.
## Dipakai ternak (ranch_animal.gd), kuda di dunia (horse_actor.gd), dan peliharaan (pet_actor.gd).
## - Belum dirawat: gelembung terang dan memantul, selalu terlihat.
## - Sudah dirawat: gelembung abu-abu bercentang, hanya terlihat saat pemain berdiri dekat,
##   supaya ladang tidak ramai. Gelembung hasil muncul selama hasil belum diambil.
## Isi diambil dari `provider` (Callable -> Array of {"kind", "done", "icon"?}) secara berkala, sehingga
## perubahan dari menu kandang, pemain co-op lain, atau pergantian hari langsung terlihat.
signal near_changed(near: bool)

## load() (bukan preload) supaya script tetap jalan walau PNG belum diimpor editor.
const SHEET_PATH := "res://assets/ranch/animal_status.png"
static var _sheet: Texture2D
const CELL := 12
## Kolom di sheet animal_status.png; baris 0 = belum, baris 1 = sudah.
const COLUMNS := {"feed": 0, "pet": 1, "brush": 2, "product": 3}
const SPACING := 13.0
const NEAR_DISTANCE := 40.0
const POLL_INTERVAL := 0.25
const BOB_AMPLITUDE := 1.5
const BOB_SPEED := 5.0
const ITEM_ICON_SIZE := 8.0

## Debug/snapshot: anggap pemain selalu dekat (tests/animal_status_snapshot.tscn).
static var debug_force_near := false
var provider: Callable
var near := false
var _signature := ""
var _bubbles: Array[Node2D] = []
var _bob: Array[bool] = []
var _poll := 0.0
var _time := 0.0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Di atas objek lain sekitar hewan (pagar, rumput) supaya tetap terbaca.
	z_index = 4
	_time = randf() * TAU
	update_now()

func _process(delta: float) -> void:
	_time += delta
	_poll -= delta
	if _poll <= 0.0:
		_poll = POLL_INTERVAL
		update_now()
	for i in _bubbles.size():
		if _bob[i]:
			_bubbles[i].position.y = -absf(sin(_time * BOB_SPEED + i * 0.7)) * BOB_AMPLITUDE

## Hitung ulang jarak pemain dan isi gelembung sekarang (dipanggil juga setelah aksi rawat).
func update_now() -> void:
	if not is_inside_tree():
		return
	var was_near := near
	near = _player_near()
	if near != was_near:
		near_changed.emit(near)
	var needs: Array = provider.call() if provider.is_valid() else []
	var shown: Array = []
	for need in needs:
		if not need.get("done", false) or near:
			shown.append(need)
	var signature := ""
	for need in shown:
		signature += "%s:%s:%s|" % [need.kind, need.get("done", false), need.get("icon", null)]
	if signature == _signature:
		return
	_signature = signature
	_rebuild(shown)

func _rebuild(shown: Array) -> void:
	if _sheet == null:
		if ResourceLoader.exists(SHEET_PATH):
			_sheet = load(SHEET_PATH) as Texture2D
		else:
			# PNG baru yang belum diimpor editor: baca langsung dari file.
			var image := Image.load_from_file(ProjectSettings.globalize_path(SHEET_PATH))
			if image != null and not image.is_empty():
				_sheet = ImageTexture.create_from_image(image)
	for bubble in _bubbles:
		bubble.queue_free()
	_bubbles.clear()
	_bob.clear()
	for i in shown.size():
		var need: Dictionary = shown[i]
		var done: bool = need.get("done", false)
		var holder := Node2D.new()
		holder.position.x = (i - (shown.size() - 1) * 0.5) * SPACING
		var bubble := Sprite2D.new()
		var region := AtlasTexture.new()
		region.atlas = _sheet
		region.region = Rect2(int(COLUMNS.get(need.kind, 3)) * CELL, CELL if done else 0, CELL, CELL)
		bubble.texture = region
		holder.add_child(bubble)
		var icon: Texture2D = need.get("icon", null)
		if icon != null:
			var item := Sprite2D.new()
			item.texture = icon
			item.position.y = -0.5
			item.scale = Vector2.ONE * (ITEM_ICON_SIZE / maxf(1.0, float(maxi(icon.get_width(), icon.get_height()))))
			if done:
				item.modulate = Color(1, 1, 1, 0.5)
			holder.add_child(item)
		add_child(holder)
		_bubbles.append(holder)
		_bob.append(not done)
		# Gelembung baru muncul dengan pantulan kecil.
		holder.scale = Vector2(0.6, 0.6)
		holder.create_tween().tween_property(holder, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _player_near() -> bool:
	if debug_force_near:
		return true
	var body := get_parent() as Node2D
	if body == null:
		return false
	for node in get_tree().get_nodes_in_group(Combat.PLAYER_GROUP):
		if node is Player and node.get_world_2d() == body.get_world_2d() \
				and body.global_position.distance_to(node.global_position + Player.FEET_OFFSET) <= NEAR_DISTANCE:
			return true
	return false
