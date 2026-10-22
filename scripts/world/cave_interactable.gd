extends Area2D

## Objek dinding gua: pintu keluar, lift, tangga naik (GDD 9).
## Dipakai di cave.tscn (lobi) dan dibuat dari kode untuk tangga/lift di lantai tambang.
## Pintu keluar dan tangga naik langsung meminta konfirmasi saat pemain melangkah masuk ke
## areanya (tombol interaksi tetap bisa); lift dibuka dengan tombol interaksi.

const CONFIRM := preload("res://scripts/ui/cave_confirm_dialog.gd")
## Setelah pemain ditaruh di titik tiba, sentuhan diabaikan selama ini (ms) supaya
## konfirmasi tidak muncul sendiri saat tiba tepat di depan tangga.
const ARRIVAL_GRACE_MS := 600

## "exit" = keluar ke Gunung, "lift" = menu lift, "up" = kembali ke lobi.
@export_enum("exit", "lift", "up") var action: String = "exit"

## Scene gua pemilik objek ini; dicari otomatis dari induknya bila kosong.
var cave: Node

func _ready() -> void:
	set_meta("player_interaction", true)
	set_meta("cave_action", action)
	# Ikut daftar pintu supaya bisa dipakai saat pemain berdiri menempel di depannya.
	# Tanpa ini interaksi hanya mencari titik 32 px di depan kaki, yang sudah masuk ke dinding.
	add_to_group("scene_door")
	if cave == null:
		var node := get_parent()
		while node != null and not node.has_method("use_object"):
			node = node.get_parent()
		cave = node
	if action != "lift":
		body_entered.connect(_on_body_entered)

func interact(player: Player = null) -> void:
	if player == null:
		player = RoomDoor.player()
	if cave == null or player == null or player.is_input_locked():
		return
	match action:
		"exit":
			CONFIRM.ask(player, "Keluar dari gua?", "Kembali ke Gunung lewat mulut gua.", "Keluar",
				func() -> void: cave.use_object(action, player))
		"up":
			CONFIRM.ask(player, "Naik ke lobi?", "Kembali ke lobi gua (Toko Combat, lift, pintu keluar).", "Naik",
				func() -> void: cave.use_object(action, player))
		_:
			cave.use_object(action, player)

## Sentuh pintu keluar / tangga naik: tanya langsung. Solo: game dijeda; co-op: hanya pemain
## ini yang terkunci (Coop.set_menu_open). Keluar lalu masuk lagi untuk ditanya ulang.
func _on_body_entered(body: Node2D) -> void:
	if not body is Player or cave == null:
		return
	if cave.get("_changing") or Time.get_ticks_msec() - int(cave.get("arrived_msec")) < ARRIVAL_GRACE_MS:
		return
	if (body as Player).velocity.is_zero_approx():
		return
	interact.call_deferred(body as Player)
