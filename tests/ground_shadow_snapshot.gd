extends Node2D
## Regresi + snapshot bayangan musuh dan serangga: kaki tiap musuh/serangga darat harus tepat di
## titik pijak (bayangan), bayangan terbang ada di tanah. Gambar (bukan headless):
## NUSA_SHADOW_SCREENSHOT=1 menyimpan user://ground_shadow.png.
const GroundShadow := preload("res://scripts/effects/ground_shadow.gd")
const ENEMIES := ["slime_green", "frost_slime", "gold_slime", "cave_archer", "ember_guard", "myconid_red", "cave_mage"]
const BUGS := ["ant", "cricket", "caterpillar", "bee", "monarch", "firefly"]
const ZOOM := 4.0

var failures := 0


func check(value: bool, message: String) -> void:
	if value:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)


## Baris kaki di koordinat induk: top sprite + baris piksel terbawah frame acuan.
func _feet(sprite: Node2D, texture: Texture2D) -> float:
	var offset: Vector2 = sprite.get("offset")
	var top := sprite.position.y + offset.y - texture.get_height() * 0.5
	return top + GroundShadow.visible_bottom(texture)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().create_timer(0.6, true).timeout
	DayCycle.is_running = false
	var bg := ColorRect.new()
	bg.color = Color("6a5a4a")
	bg.position = Vector2(-40, -60)
	bg.size = Vector2(400, 140)
	add_child(bg)
	var world := Node2D.new()
	world.y_sort_enabled = true
	add_child(world)

	var x := 0.0
	for id in ENEMIES:
		var data: EnemyData = load("res://resources/enemies/%s.tres" % id)
		var enemy := Enemy.spawn(data, world, Vector2(x, 0))
		enemy.ai_enabled = false
		enemy.set_physics_process(false)
		var sprite: AnimatedSprite2D = enemy._sprite
		var tex := sprite.sprite_frames.get_frame_texture(&"idle_down" if sprite.sprite_frames.has_animation(&"idle_down") else sprite.animation, 0)
		check(is_equal_approx(_feet(sprite, tex), data.foot_sink), "%s: kaki menapak di titik pijak (y=%.1f)" % [id, _feet(sprite, tex)])
		check(enemy.get_node_or_null("GroundShadow") != null and enemy.get_child(0).name == "GroundShadow", "%s: bayangan dipasang di bawah sprite" % id)
		x += 34.0

	# Boss: kaki rata juga, bayangan lebih lebar dan mengecil saat lompat slam.
	var boss_data: BossData = load("res://resources/enemies/boss_slime_king.tres")
	var boss := Boss.spawn_boss(boss_data, world, Vector2(x + 40, 20))
	boss.set_physics_process(false)
	var boss_sprite: AnimatedSprite2D = boss._sprite
	var boss_tex := boss_sprite.sprite_frames.get_frame_texture(&"idle_down" if boss_sprite.sprite_frames.has_animation(&"idle_down") else boss_sprite.animation, 0)
	var boss_feet := boss_sprite.position.y + (boss_sprite.offset.y - boss_tex.get_height() * 0.5 + GroundShadow.visible_bottom(boss_tex)) * boss_sprite.scale.y
	check(is_equal_approx(boss_feet, boss_data.foot_sink), "boss (skala %.1f): kaki menapak di titik pijak (y=%.1f)" % [boss_sprite.scale.y, boss_feet])
	var boss_shadow: Node2D = boss.get_node("GroundShadow")
	check(is_equal_approx(boss_shadow.radius, boss_data.body_radius * 1.5), "boss: bayangan lebih lebar")
	check(boss.get_children().filter(func(c): return c.name.begins_with("GroundShadow")).size() == 1, "boss: hanya satu bayangan")

	x = 0.0
	for id in BUGS:
		var data: Resource = load("res://resources/bugs/%s.tres" % id)
		var bug: Node2D = load("res://scripts/world/bug_critter.gd").new()
		bug.setup(data)
		world.add_child(bug)
		bug.place(Vector2(x, 50))
		bug.set_physics_process(false)
		var shadow: Node2D = bug.get_node_or_null("GroundShadow")
		check(shadow != null and shadow.position == Vector2.ZERO, "%s: bayangan di tanah" % id)
		if not data.flying:
			var sprite: Sprite2D = bug._sprite
			check(is_equal_approx(_feet(sprite, sprite.texture), 1.0), "%s: serangga darat menapak" % id)
		else:
			check(shadow.lift > 0.0, "%s: bayangan terbang mengecil sesuai tinggi" % id)
		x += 30.0

	var cam := Camera2D.new()
	cam.zoom = Vector2.ONE * ZOOM
	cam.position = Vector2(130, 12)
	add_child(cam)
	cam.make_current()
	await get_tree().create_timer(0.6, true).timeout
	if OS.get_environment("NUSA_SHADOW_SCREENSHOT") == "1" and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var path := OS.get_user_data_dir().path_join("ground_shadow.png")
		get_viewport().get_texture().get_image().save_png(path)
		print("snapshot: " + path)
	print("ground_shadow_snapshot: %d failure(s)" % failures)
	get_tree().quit(1 if failures else 0)
