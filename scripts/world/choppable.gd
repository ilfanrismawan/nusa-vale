class_name Choppable
extends StaticBody2D

const ItemPickupScript = preload("res://scripts/world/item_pickup.gd")

@export var health: int = 3
@export var drop_item_id: String = "wood"
@export var drop_count: int = 3
@export var object_group: StringName = &"choppable"
## Jika false, progresnya dikelola spawner sendiri, bukan daftar cleanup permanen.
@export var persistent: bool = true
## ID data untuk objek farm; objek scene lama tetap memakai path node.
@export var persistence_id: String = ""

enum ResourceSize { SMALL, NORMAL, LARGE }
@export_group("Tool requirement")
## Small = Wood, Normal = Copper, Large = Iron. Minimum tier may raise this for rare ore.
@export var resource_size: ResourceSize = ResourceSize.SMALL
@export var minimum_tool_tier: ToolData.ToolTier = ToolData.ToolTier.WOOD

func required_tool_tier() -> int:
	return maxi(int(resource_size), int(minimum_tool_tier))

func accepts_tool(tool: ToolData) -> bool:
	var kind := ToolData.ToolType.PICKAXE if object_group == &"mineable" else ToolData.ToolType.AXE
	return tool != null and tool.tool_type == kind and int(tool.tier) >= required_tool_tier()

func requirement_text() -> String:
	var kind := "Beliung" if object_group == &"mineable" else "Kapak"
	var tiers := ["Kayu", "Tembaga", "Besi", "Emas", "Platinum", "Crimson", "Frost", "Shadow", "Fairy", "Obsidian"]
	return "Butuh %s %s atau lebih tinggi." % [kind, tiers[required_tool_tier()]]

@export var animated_sprite_path: NodePath = ^"AnimatedSprite2D"
@onready var animated_sprite: AnimatedSprite2D = get_node(animated_sprite_path)

var is_chopping: bool = false
var is_destroyed: bool = false
var _canopy: AnimatedSprite2D
## Satu shader untuk semua pohon (dulu tiap pohon meng-compile shader sendiri saat load).
static var _split_shader: Shader
static var _trunk_material: ShaderMaterial
static var _canopy_material: ShaderMaterial
## Kanopi hanya disalin dari batang saat ada yang berubah (frame, pukulan, tumbang), bukan
## tiap frame: ratusan pohon yang menyalin 9 properti per frame membuat farm jalan ~20 fps.
var _sync_until_ms := 0
const TREE_SPLIT_SHADER := "shader_type canvas_item; uniform bool canopy = false; uniform float split_y = -12.0; varying float local_y; void vertex() { local_y = VERTEX.y; } void fragment() { if ((canopy && local_y >= split_y) || (!canopy && local_y < split_y)) { discard; } }"

func _setup_tree_layers() -> void:
	# Rocks share this script; only trees use the canopy/trunk split.
	if object_group != &"choppable":
		return
	if _split_shader == null:
		_split_shader = Shader.new()
		_split_shader.code = TREE_SPLIT_SHADER
		_trunk_material = ShaderMaterial.new()
		_trunk_material.shader = _split_shader
		_canopy_material = ShaderMaterial.new()
		_canopy_material.shader = _split_shader
		_canopy_material.set_shader_parameter("canopy", true)
	# Material dipakai bersama supaya pohon-pohon bisa digambar dalam satu batch.
	animated_sprite.material = _trunk_material
	animated_sprite.z_as_relative = true
	animated_sprite.z_index = 0
	_canopy = AnimatedSprite2D.new()
	_canopy.name = "Canopy"
	_canopy.sprite_frames = animated_sprite.sprite_frames
	_canopy.material = _canopy_material
	_canopy.z_as_relative = true
	_canopy.z_index = 0
	add_child(_canopy)
	_sync_tree_layers()

func _process(_delta: float) -> void:
	_sync_tree_layers()
	if not is_chopping and Time.get_ticks_msec() > _sync_until_ms:
		set_process(false)


## Salin kanopi tiap frame selama `seconds` ke depan (goyangan, animasi tebang/tumbang).
func _keep_synced(seconds: float) -> void:
	if _canopy == null:
		return
	_sync_until_ms = maxi(_sync_until_ms, Time.get_ticks_msec() + int(seconds * 1000.0))
	set_process(true)

func _sync_tree_layers() -> void:
	if _canopy == null:
		return
	_canopy.transform = animated_sprite.transform
	_canopy.offset = animated_sprite.offset
	_canopy.centered = animated_sprite.centered
	_canopy.flip_h = animated_sprite.flip_h
	_canopy.flip_v = animated_sprite.flip_v
	_canopy.modulate = animated_sprite.modulate
	_canopy.visible = animated_sprite.visible
	_canopy.animation = animated_sprite.animation
	_canopy.set_frame_and_progress(animated_sprite.frame, animated_sprite.frame_progress)


func _ready() -> void:
	if persistent and _removed_ids().has(_persistence_key()):
		queue_free()
		return
	add_to_group(object_group)
	_setup_tree_layers()
	set_process(false)
	if _canopy != null and animated_sprite != null:
		animated_sprite.frame_changed.connect(_sync_tree_layers)
		animated_sprite.animation_changed.connect(_sync_tree_layers)
		animated_sprite.visibility_changed.connect(_sync_tree_layers)
	DayCycle.season_changed.connect(_apply_season)
	_apply_season(DayCycle.get_season())
	_play(&"idle")
	# Tapper yang terpasang di pohon ini (GDD 7). Deferred: spawner baru mengatur posisi setelah add_child.
	if object_group == &"choppable":
		GameState.gathering.on_tree_ready.call_deferred(self)


## Pemain terakhir yang memukul: penerima EXP dan bonus perk (GDD 13).
var last_hitter: PlayerData

func take_hit(damage: int, tool_tier: int = ToolData.ToolTier.WOOD) -> void:
	if tool_tier < required_tool_tier():
		return
	if is_destroyed or is_chopping:
		return
	last_hitter = GameState.current
	health -= damage
	is_chopping = true
	_play(&"chopping")
	Juice.play(_feedback_key(), _impact_point())
	_wobble()
	var anim_time := _chop_duration()
	_keep_synced(anim_time + 0.25)
	get_tree().create_timer(anim_time).timeout.connect(_on_chop_timeout)


func _on_animated_sprite_2d_animation_finished() -> void:
	if animated_sprite.animation != &"chopping":
		return
	_finish_chop()


func _on_chop_timeout() -> void:
	if is_chopping:
		_finish_chop()


func _finish_chop() -> void:
	if is_destroyed or not is_chopping:
		return
	is_chopping = false
	if health <= 0:
		_destroy_tree()
	else:
		_play(&"idle")


func _destroy_tree() -> void:
	if is_destroyed:
		return
	is_destroyed = true
	Juice.play(StringName(String(_feedback_key()) + "_break"), _impact_point())
	_spawn_wood_drop()
	SkillSystem.on_resource_broken(last_hitter, object_group, drop_item_id)
	if object_group == &"choppable":
		GameState.gathering.on_tree_destroyed(self)
	if persistent:
		var path_id := _persistence_key()
		var removed := _removed_ids()
		if not removed.has(path_id):
			removed.append(path_id)
	collision_layer = 0
	collision_mask = 0
	_keep_synced(0.5)
	_play(&"stump")
	await get_tree().create_timer(0.35).timeout
	queue_free()


func _spawn_wood_drop() -> void:
	var parent := get_parent()
	if parent == null:
		parent = get_tree().current_scene
	var origin := global_position + Vector2(0, -8)
	# Perk Forager (kayu ekstra) dan Miner (bijih/batubara/permata ganda).
	var total := drop_count + SkillSystem.extra_drops(last_hitter, object_group, drop_item_id, drop_count)
	for i in total:
		var offset := Vector2(randf_range(-12.0, 12.0), randf_range(-6.0, 6.0))
		ItemPickupScript.spawn(parent, origin + offset, drop_item_id, 1)
	# Pohon besar kadang menjatuhkan bijinya untuk ditanam di farm (GDD 7).
	if object_group == &"choppable":
		var seed_id: String = GameState.gathering.roll_seed_drop(self)
		if not seed_id.is_empty():
			ItemPickupScript.spawn(parent, origin + Vector2(randf_range(-8.0, 8.0), 4.0), seed_id, 1)


func _play(anim: StringName) -> void:
	if animated_sprite == null or animated_sprite.sprite_frames == null:
		return
	if not animated_sprite.sprite_frames.has_animation(anim):
		push_warning("Tree: animasi '%s' tidak ada" % anim)
		return
	animated_sprite.stop()
	animated_sprite.animation = anim
	animated_sprite.set_frame_and_progress(0, 0.0)
	# Objek diam dengan satu frame tidak perlu ticker animasi idle.
	if animated_sprite.sprite_frames.get_frame_count(anim) > 1:
		animated_sprite.play(anim)


## chop / mine / cut, sesuai jenis objek. Paket ada di resources/feedback/.
func _feedback_key() -> StringName:
	match object_group:
		&"choppable":
			return &"chop"
		&"mineable":
			return &"mine"
	return &"cut"


func _impact_point() -> Vector2:
	var shape := get_node_or_null("CollisionShape2D") as Node2D
	if shape:
		return shape.global_position
	return global_position


## Goyangan kecil 1 piksel saat kena pukulan.
func _wobble() -> void:
	if animated_sprite == null:
		return
	var base := animated_sprite.position
	var tw := create_tween()
	tw.tween_property(animated_sprite, "position", base + Vector2(1, 0), 0.04)
	tw.tween_property(animated_sprite, "position", base + Vector2(-1, 0), 0.06)
	tw.tween_property(animated_sprite, "position", base, 0.04)


func _removed_ids() -> Array[String]:
	if object_group == &"mineable":
		return GameState.mined_rocks
	return GameState.chopped_trees

func _persistence_key() -> String:
	return persistence_id if not persistence_id.is_empty() else str(get_path())


func _chop_duration() -> float:
	if animated_sprite == null or animated_sprite.sprite_frames == null:
		return 0.6
	var frames := animated_sprite.sprite_frames.get_frame_count(&"chopping")
	var fps := animated_sprite.sprite_frames.get_animation_speed(&"chopping")
	if fps <= 0.0:
		return 0.6
	return (float(frames) / fps) + 0.05


## Ganti sheet animasi sesuai musim (set di resources/seasons/, mis. tree_maple.tres).
## SpriteFrames dipakai bersama semua pohon sejenis, jadi cukup menukar atlas-nya.
func _apply_season(season: int) -> void:
	if animated_sprite == null or animated_sprite.sprite_frames == null:
		return
	var frames := animated_sprite.sprite_frames
	for anim in frames.get_animation_names():
		for i in frames.get_frame_count(anim):
			var atlas_tex := frames.get_frame_texture(anim, i) as AtlasTexture
			if atlas_tex == null:
				continue
			var tex_set := SeasonalTextureSet.find_for(atlas_tex.atlas)
			if tex_set:
				atlas_tex.atlas = tex_set.get_for(season)
