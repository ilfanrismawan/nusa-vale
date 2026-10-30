class_name TuyulTracks
extends Node2D

## Jejak kaki kecil Tuyul di dekat Shipping Bin (GDD 4.1, Progres Horor Tahap 4). Kosmetik:
## muncul pada malam pencurian dan pagi berikutnya sampai 12.00 (HorrorManager.tracks_visible).

const NODE_NAME := &"TuyulTracks"


## Pasang jejak di bin ini bila sedang terlihat; dipanggil saat bin dimuat dan saat pencurian.
static func attach(bin: Node2D) -> void:
	if not is_instance_valid(bin) or bin.has_node(NodePath(NODE_NAME)):
		return
	if GameState.horror == null or not GameState.horror.tracks_visible():
		return
	var tracks := TuyulTracks.new()
	tracks.name = NODE_NAME
	bin.add_child(tracks)


func _ready() -> void:
	z_index = -1


func _process(_delta: float) -> void:
	if GameState.horror == null or not GameState.horror.tracks_visible():
		queue_free()


func _draw() -> void:
	# Jejak telapak kecil berselang-seling menjauh dari bin ke kanan bawah.
	var c := Color(0.16, 0.1, 0.06, 0.55)
	for i in 7:
		var base := Vector2(10 + i * 9, 10 + i * 5)
		var side := 2.0 if i % 2 == 0 else -2.0
		var foot := base + Vector2(0, side)
		draw_rect(Rect2(foot, Vector2(3, 2)), c)
		draw_rect(Rect2(foot + Vector2(3, 0), Vector2(1, 1)), c)
		draw_rect(Rect2(foot + Vector2(3, 1.5), Vector2(1, 1)), c)
