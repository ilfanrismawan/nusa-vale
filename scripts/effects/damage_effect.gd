class_name DamageEffect
extends ActionEffect

@export var target_group: StringName = &"choppable"
@export var damage: int = 1
@export var stamina_cost: int = 6

func apply(player: Player, cell: Vector2i) -> void:
	if GameState.stamina < stamina_cost:
		Notify.say("Terlalu lelah! Istirahatlah.")
		return
	var hit := false
	match target_group:
		&"mineable":
			hit = FarmManager.mine(player, cell, damage)
		&"choppable":
			hit = FarmManager.chop(player, cell, damage)
		_:
			hit = FarmManager.hit_world(player, cell, target_group, damage)
	if hit:
		GameState.spend_stamina(stamina_cost)
