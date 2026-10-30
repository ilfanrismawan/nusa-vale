extends Area2D

var _dialog: NPCDialogUI

func _ready() -> void:
	set_meta("player_interaction", true)
	collision_layer = 1
	collision_mask = 2
	var shape := CollisionShape2D.new()
	var bounds := RectangleShape2D.new()
	bounds.size = Vector2(20, 24)
	shape.shape = bounds
	add_child(shape)
	var sprite := Sprite2D.new()
	sprite.texture = preload("res://resources/icons/icon_mailbox_decor.tres")
	sprite.position = Vector2(0, -6)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	

func interact(player: Player = null) -> void:
	if player == null or is_instance_valid(_dialog):
		return
	NPCHousehold.advance(player.data, DayCycle.current_day)
	for id: String in player.data.story_mail:
		var letter: Dictionary = player.data.story_mail[id]
		if bool(letter.read) or int(letter.arrival_day) > DayCycle.current_day:
			continue
		var ui := preload("res://scenes/ui/npc_dialog_ui.tscn").instantiate() as NPCDialogUI
		_dialog = ui
		ui.player = player
		ui.npc_name = "Kotak Surat"
		ui.lines = PackedStringArray([str(letter.subject), str(letter.body)])
		ui.allow_gifts = false
		ui.award_friendship = false
		ui.finished.connect(func():
			if ui.completed:
				Notify.say(NPCHousehold.claim_letter(player.data, id).message)
		)
		Coop.ui_parent(player).add_child(ui)
		return
	Notify.say("Belum ada surat baru untukmu.")
