extends Area2D

@export var returning := false
const FOREST_RETURN := Vector2(520, 680)
const DEEP_SPAWN := Vector2(800, 160)

func _ready() -> void:
	add_to_group("scene_door")
	if not has_node("CollisionShape2D"):
		var shape := CollisionShape2D.new()
		shape.name = "CollisionShape2D"
		var rectangle := RectangleShape2D.new()
		rectangle.size = Vector2(96, 48)
		shape.shape = rectangle
		add_child(shape)
	if not has_node("Label"):
		var label := Label.new()
		label.name = "Label"
		label.position = Vector2(-115, -50)
		label.text = "↑ Kembali ke Forest [E]" if returning else "↓ Deep Forest [E]\nUnlock permanen: 3.000G + 150 Kayu + 75 Batu"
		label.add_theme_font_size_override("font_size", 10)
		add_child(label)
	body_entered.connect(_on_body_entered)
	_refresh_label()

func _refresh_label() -> void:
	var label := get_node_or_null("Label") as Label
	if label != null:
		label.text = "↑ Kembali ke Forest" if returning else ("↓ Deep Forest" if UnlockManager.is_unlocked("deep_forest") else "↓ Deep Forest\n[E] Unlock permanen: 3.000G + 150 Kayu + 75 Batu")

func _on_body_entered(body: Node2D) -> void:
	if not body is Player or body.is_input_locked() or Transition.on_transition:
		return
	if not returning and not UnlockManager.is_unlocked("deep_forest"):
		Notify.say("Deep Forest: 3.000G, 150 Kayu, 75 Batu. Tekan E untuk membuka permanen. Jamur langka, truffle, dan bijih menanti.")
		return
	_travel(body)

func interact(actor: Player = null) -> void:
	var player := actor if actor != null else RoomDoor.player()
	if player == null or player.is_input_locked() or Transition.on_transition:
		return
	player.bind_context()
	if not returning and not UnlockManager.is_unlocked("deep_forest"):
		if not UnlockManager.purchase_deep_forest():
			Notify.say("Butuh akses Forest, 3.000G (%d), 150 Kayu (%d), 75 Batu (%d)." % [GameState.money, GameState.get_item_count("wood"), GameState.get_item_count("stone")])
			return
		Notify.say("Deep Forest terbuka permanen! Tidak ada biaya masuk berikutnya.")
		_refresh_label()
	_travel(player)

func _travel(player: Player) -> void:
	var path := "res://scenes/world/Forest.tscn" if returning else "res://scenes/world/DeepForest.tscn"
	RoomDoor.travel(player, path, FOREST_RETURN if returning else DEEP_SPAWN)
