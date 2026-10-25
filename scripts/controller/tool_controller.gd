class_name ToolController
extends Node

signal tool_changed(action: ActionData)

@onready var player: Player = get_parent()
@onready var state_machine: StateMachine = $"../StateMachine"
@onready var action_state: ActionState = $"../StateMachine/ActionState"
@onready var fishing_state: FishingState = $"../StateMachine/FishingState"

const HAND_HARVEST: ActionData = preload("res://resources/action_data/hand_harvest.tres")

## Dibuat di _ready (sebelum Player memanggil state_machine.initialize).
var combat_state: CombatState
var dodge_state: DodgeState
## Lompat + lompat ganda (GDD 4.3, seperti Grand Bazaar).
var jump_state: JumpState
## Menumpang sepeda/sapu terbang (GDD 10).
var ride_state: RideState
## Combo senjata: pukulan berikutnya, jenis senjata, dan batas waktu menyambung (msec).
var combo_step := 0
var _combo_weapon := -1
var _combo_until := 0

var current_index: int = 0
var furniture_preview: Node2D


var current_tool: ActionData:
	get:
		var item := current_item
		return item.action_data if item != null else null


var current_item: ItemData:
	get:
		var data := player.data
		var global_idx = data.hotbar_page * 8 + current_index
		if global_idx < 0 or global_idx >= data.bag_size:
			return null
		
		var slot = data.inventory[global_idx]
		if slot == null:
			return null
			
		return slot["item"]


func _ready() -> void:
	combat_state = CombatState.new()
	combat_state.name = "CombatState"
	combat_state.idle_state = state_machine.get_node("IdleState")
	state_machine.add_child(combat_state)
	dodge_state = DodgeState.new()
	dodge_state.name = "DodgeState"
	dodge_state.idle_state = combat_state.idle_state
	state_machine.add_child(dodge_state)
	jump_state = JumpState.new()
	jump_state.name = "JumpState"
	jump_state.idle_state = combat_state.idle_state
	state_machine.add_child(jump_state)
	ride_state = RideState.new()
	ride_state.name = "RideState"
	ride_state.idle_state = combat_state.idle_state
	state_machine.add_child(ride_state)
	furniture_preview = load("res://scripts/player/furniture_preview.gd").new()
	furniture_preview.player = player
	player.add_child.call_deferred(furniture_preview)
	action_state.action_performed.connect(_on_action_performed)
	GameState.inventory_changed.connect(func(): tool_changed.emit(current_tool))
	tool_changed.emit(current_tool)


func _unhandled_input(event: InputEvent) -> void:
	# Co-op: setiap pemain hanya bereaksi pada perangkatnya sendiri (PlayerInput).
	if player.is_input_locked():
		return
	var input := player.input
	if state_machine.current_state == combat_state:
		# Klik saat menyerang disimpan untuk pukulan combo berikutnya.
		if input.is_event(event, &"use_tool") and Combat.is_weapon(current_item):
			combat_state.combo_queued = true
			get_viewport().set_input_as_handled()
		return
	if state_machine.current_state in [action_state, fishing_state, dodge_state]:
		return
	if state_machine.current_state == ride_state:
		# Menumpang kendaraan: tombol Alat = turun; ganti slot hotbar tetap boleh.
		if input.is_event(event, &"use_tool"):
			player.bind_context()
			player.dismount_vehicle()
			get_viewport().set_input_as_handled()
			return
	if state_machine.current_state == jump_state:
		# Di udara hanya benih yang bisa dipakai: ditebar saat mendarat (Grand Bazaar).
		if input.is_event(event, &"use_tool") and EquipmentContext.is_seed(current_item):
			jump_state.queue_scatter(current_item)
			get_viewport().set_input_as_handled()
			return
		if input.is_event(event, &"use_tool"):
			return
	if input.is_event(event, &"use_tool"):
		player.bind_context()
		if player.has_meta("carried_animal") and is_instance_valid(player.get_meta("carried_animal")):
			player.release_carried_animal()
			get_viewport().set_input_as_handled()
			return
		if current_item == null:
			for animal in get_tree().get_nodes_in_group("ranch_animal"):
				if animal.visible and animal.get_world_2d() == player.get_world_2d() and (player.global_position + Player.FEET_OFFSET).distance_to(animal.global_position) < 22:
					animal.lift_with(player)
					get_viewport().set_input_as_handled()
					return
		if current_item != null and current_item.vehicle != null:
			player.mount_vehicle(current_item)
			get_viewport().set_input_as_handled()
			return
		if Combat.is_weapon(current_item):
			# Serangan keluar saat tombol dilepas: singkat = ringan, ditahan = berat (PlayerCombat).
			if not player.combat.is_exhausted():
				player.combat.begin_charge()
			get_viewport().set_input_as_handled()
			return
		if current_item != null and current_item.category == ItemData.Category.FOOD:
			Notify.say(CookingManager.eat(player, player.data.hotbar_page * 8 + current_index).message)
			get_viewport().set_input_as_handled()
			return
		# Buku riset Perpustakaan (GDD 13.1): dibaca untuk EXP role.
		if current_item != null and not current_item.skill_book_role.is_empty():
			SkillSystem.read_book(player.data, player.data.hotbar_page * 8 + current_index)
			get_viewport().set_input_as_handled()
			return
		for bin in get_tree().get_nodes_in_group("shipping_bin"):
			if bin.get_world_2d() == player.get_world_2d() and bin.deposit_selected(player):
				get_viewport().set_input_as_handled()
				return
		var near_structure := StructureManager.closest_structure(player)
		if not near_structure.is_empty() and StructureManager.is_processing_machine(str(near_structure.item)):
			if StructureManager.interact_machine(player, int(near_structure.uid)):
				get_viewport().set_input_as_handled()
				return
		if current_item != null and current_item.placeable:
			if current_item.seat_definition != null and not furniture_preview.can_place():
				get_viewport().set_input_as_handled()
				return
			if current_item.item_id in StructureManager.CONSTRUCTION:
				BuildingPlacement.begin(player, current_item.item_id, true)
				get_viewport().set_input_as_handled()
				return
			var facing: int = furniture_preview.facing if current_item.seat_definition != null else 1
			var result := StructureManager.place(player, player.data.hotbar_page * 8 + current_index, player.get_target_cell(), facing)
			if result.ok and current_item != null and current_item.seat_definition != null:
				furniture_preview.finish_placement()
			Notify.say(result["message"])
			get_viewport().set_input_as_handled()
		elif current_tool != null:
			use_action(current_tool)
		elif current_item != null:
			player.ui_inventory.drop_from_slot(player.data.hotbar_page * 8 + current_index, 1)
			get_viewport().set_input_as_handled()
		elif _can_hand_harvest():
			use_action(HAND_HARVEST)
			
		return

	if input.is_event(event, &"tool_next"):
		switch_tool(1)
		return
		
	elif input.is_event(event, &"tool_prev"):
		switch_tool(-1)
		return

	for i in range(8):
		if input.is_event(event, StringName("slot_%d" % (i + 1))):
			select_tool(i)
			return


func switch_tool(direction: int) -> void:
	var new_index: int = wrapi(current_index + direction, 0, 8)
	select_tool(new_index)


func select_tool(index: int, preview: bool = true) -> void:
	if index < 0 or index >= 8:
		return
	current_index = index
	if furniture_preview != null:
		furniture_preview.restart_placement()
	player._sync_carried_item()
	var item: ItemData = current_item
	tool_changed.emit(current_tool)
	if preview:
		player.show_tool_preview(item)
	if item != null:
		print("Slot aktif [%d]: %s" % [index, item.display_name])
	else:
		print("Slot aktif [%d]: kosong" % index)
	debug_current_tool()


## Serang dengan senjata di slot terpilih (klik kiri). Busur memakai satu anak panah
## terkuat di tas. Semua serangan memakai stamina tempur (PlayerCombat, GDD 8.2-A1).
## Serangan ringan otomatis menjadi riposte (musuh terhuyung di depan), roll attack
## (sesaat setelah roll), atau sprint attack (sesaat setelah berlari).
func attack(kind: CombatState.Kind = CombatState.Kind.LIGHT) -> bool:
	var weapon := current_item
	var style := Combat.style_for(weapon)
	if style == null or player.is_defeated:
		return false
	if state_machine.current_state in [action_state, fishing_state, combat_state, dodge_state, jump_state, ride_state]:
		return false
	var combat := player.combat
	if combat.is_exhausted():
		combat.spend(1.0)
		return false
	var riposte := _riposte_target(style)
	if riposte != null:
		kind = CombatState.Kind.RIPOSTE
	elif kind == CombatState.Kind.LIGHT and combat.rolled_recently():
		kind = CombatState.Kind.ROLL
	elif kind == CombatState.Kind.LIGHT and combat.ran_recently():
		kind = CombatState.Kind.SPRINT
	var data := player.data
	var arrow: ItemData
	if style.uses_ammo:
		var slot := Combat.best_arrow_slot(data)
		if slot < 0:
			Notify.say("Tidak ada anak panah!")
			return false
		arrow = data.inventory[slot]["item"]
		data.remove_item_at(slot, 1)
	var cost := style.heavy_stamina_cost if kind == CombatState.Kind.HEAVY else style.stamina_cost
	if not combat.spend(float(cost)):
		if arrow != null:
			data.add_item(arrow, 1)
		return false
	player._clear_pickup_visual()
	var step := 0
	if kind == CombatState.Kind.LIGHT and weapon.weapon_type == _combo_weapon and Time.get_ticks_msec() <= _combo_until:
		step = combo_step
	var aim := player.aim_vector()
	if riposte != null:
		aim = (riposte.global_position - (player.global_position + Player.FEET_OFFSET)).normalized()
	combat_state.start(weapon, style, aim, arrow, step, kind)
	combat_state.riposte_target = riposte
	combo_step = (step + 1) % style.combo_length() if kind == CombatState.Kind.LIGHT else 0
	_combo_weapon = weapon.weapon_type
	_combo_until = 0
	state_machine.change_state(combat_state)
	return true

## Musuh terhuyung terdekat di depan pemain, dalam jangkauan riposte (hanya senjata jarak dekat).
func _riposte_target(style: WeaponStyle) -> Node2D:
	if style.melee_radius <= 0.0:
		return null
	var feet := player.global_position + Player.FEET_OFFSET
	var best: Node2D
	var best_distance := Combat.RULES.riposte_range
	for node in get_tree().get_nodes_in_group(Combat.DAMAGEABLE_GROUP):
		if not node is Node2D or not node.has_method("is_staggered") or not node.is_staggered():
			continue
		var offset: Vector2 = (node as Node2D).global_position - feet
		if offset.length() <= best_distance and offset.normalized().dot(player.aim_vector()) > 0.2:
			best = node
			best_distance = offset.length()
	return best

## Weapon art (tombol F): skill khusus per tier senjata (WeaponStyle.arts, GDD 8.2-A6).
func weapon_art() -> bool:
	var weapon := current_item
	var style := Combat.style_for(weapon)
	if style == null or player.is_defeated:
		return false
	var state := state_machine.current_state
	if not (state is IdleState or state is MoveState):
		return false
	var art := style.art_for(int(weapon.equipment_tier))
	if art == null:
		return false
	var combat := player.combat
	if not combat.art_ready(art):
		CombatJuice.float_text(player, "%s %.0f dtk" % [art.display_name, ceilf(combat.art_cooldown_left(art))], Color(0.75, 0.75, 0.8))
		return false
	if combat.is_exhausted():
		combat.spend(1.0)
		return false
	var data := player.data
	var arrow: ItemData
	if style.uses_ammo:
		var slot := Combat.best_arrow_slot(data)
		if slot < 0:
			Notify.say("Tidak ada anak panah!")
			return false
		arrow = data.inventory[slot]["item"]
		data.remove_item_at(slot, 1)
	if not combat.spend(float(art.stamina_cost)):
		if arrow != null:
			data.add_item(arrow, 1)
		return false
	combat.start_art_cooldown(art)
	combat.charging = false
	player._clear_pickup_visual()
	combat_state.start(weapon, style, player.aim_vector(), arrow, 0, CombatState.Kind.ART, art)
	combo_step = 0
	state_machine.change_state(combat_state)
	return true

## Dipanggil CombatState saat animasi serangan selesai. chain = klik kiri ditekan selama serangan.
func on_attack_finished(chain: bool) -> void:
	var style := combat_state.style
	if style == null or combat_state.is_finisher() or style.combo_length() <= 1:
		combo_step = 0
		return
	_combo_until = Time.get_ticks_msec() + int(style.combo_window * 1000.0)
	if chain:
		attack.call_deferred()

## Tebar benih ke petak cangkul kosong 3x3 di sekitar tempat mendarat (lompat + benih).
## Mengembalikan jumlah benih yang tertanam.
func scatter_seeds(item: ItemData) -> int:
	if not EquipmentContext.is_seed(item) or player.base_layer_ground == null:
		return 0
	var effect := item.action_data.effect as SeedEffect
	if effect.crop == null:
		return 0
	player.bind_context()
	if not FarmManager.is_crop_in_season(effect.crop):
		Notify.say("%s tidak bisa ditanam di %s" % [effect.crop.display_name, DayCycle.get_season_display_name()])
		return 0
	var center := player.get_player_cell()
	var planted := 0
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if not GameState.has_item(effect.seed_item_id, 1):
				break
			var cell: Vector2i = center + Vector2i(dx, dy)
			if FarmManager.plant(cell, effect.crop):
				GameState.remove_item(effect.seed_item_id, 1)
				SkillSystem.gain(player.data, &"farmer", SkillSystem.RULES.plant_exp)
				Juice.play(&"plant", Juice.cell_center(player, cell))
				planted += 1
	if planted > 0:
		Notify.say("%d benih %s ditebar." % [planted, effect.crop.display_name])
	elif not GameState.has_item(effect.seed_item_id, 1):
		Notify.say("Bibit habis! Beli di toko")
	else:
		Notify.say("Tidak ada tanah cangkul kosong di sekitar tempat mendarat.")
	return planted

func use_action(action: ActionData) -> void:
	if action == null:
		return
	if state_machine.current_state in [action_state, fishing_state, combat_state, jump_state, ride_state]:
		return
	if action.effect is FishingEffect:
		_start_fishing(action)
		return
	if player.base_layer_ground == null:
		Notify.say("Tidak bisa pakai alat di sini")
		return
	
	# Refill uses the same timed watering gesture; water changes at the hit frame.
	var stamina_cost: int = _get_stamina_cost(action)
	
	if action.effect:
		if action.tool_data != null:
			stamina_cost = _get_stamina_cost(action)
		else:
			stamina_cost = _get_stamina_cost(action)
			
		if player.data.stamina < stamina_cost:
			player.data.stamina_exhausted.emit()
			Notify.say("Terlalu lelah! Istirahatlah.")
			return
			
	action_state.start(action, player.get_target_cell())
	player._clear_pickup_visual()
	state_machine.change_state(action_state)

func _start_fishing(action: ActionData) -> void:
	# Stamina dicek di sini, tetapi baru dipotong saat kail jatuh di air (FishingState).
	var stamina_cost: int = _get_stamina_cost(action)
	if player.data.stamina < stamina_cost:
		player.data.stamina_exhausted.emit()
		Notify.say("Terlalu lelah! Istirahatlah.")
		return
	fishing_state.start(action.tool_data as RodData, stamina_cost)
	player._clear_pickup_visual()
	state_machine.change_state(fishing_state)
	
func _get_stamina_cost(action: ActionData) -> int:
	if action == null:
		return 0
	if action.effect is WaterEffect:
		return maxi(action.tool_data.stamina_cost if action.tool_data != null else action.effect.stamina_cost, 1)
	if action.tool_data != null:
		return maxi(action.tool_data.stamina_cost, 0)
		
	if action.effect != null:
		return maxi(action.effect.stamina_cost, 0)
		
	return 0
	
func _can_hand_harvest() -> bool:
	if player.base_layer_ground == null:
		return false
	return FarmManager.can_harvest(player.get_target_cell())


func _on_action_performed(action: ActionData, cell: Vector2i) -> void:
	if action == null:
		return
	if action.effect == null:
		return
	# Efek dipanggil dari sinyal animasi; pastikan GameState/FarmManager menunjuk pemain ini.
	player.bind_context()
	action.effect.apply(player, cell)
	
# DEBUGGING
func debug_current_tool() -> void:
	if not OS.has_feature("editor"):
		return
	print("")
	print("========== TOOL DEBUG ==========")

	var item: ItemData = current_item

	if item == null:
		print("Item: NULL")
		print("================================")
		return

	print("Item ID       : ", item.item_id)
	print("Display Name  : ", item.display_name)
	print("Is Tool       : ", item.is_tool())

	if item.action_data == null:
		print("ActionData    : NULL")
		print("================================")
		return

	var action: ActionData = item.action_data

	print("ActionData    : OK")
	print("Action Name   : ", action.display_name)
	print("Animation     : ", action.animation_name)
	print("Input Action  : ", action.input_action)

	if action.effect == null:
		print("Effect        : NULL")
	else:
		print("Effect        : ", action.effect.get_class())

	if action.tool_data == null:
		print("ToolData      : NULL")
		print("================================")
		return

	var tool: ToolData = action.tool_data

	print("ToolData      : OK")
	print("Tool ID       : ", tool.tool_id)
	print("Tool Type     : ", tool.tool_type)
	print("Tier          : ", tool.tier)
	print("Damage        : ", tool.damage)
	print("Stamina Cost  : ", tool.stamina_cost)
	print("Action Speed  : ", tool.action_speed)
	print("Area Size     : ", tool.area_size)

	print("================================")
	print("")
