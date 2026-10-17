class_name FoodEffectData
extends Resource

enum Stacking { REFRESH, REPLACE, STACK }

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export_range(0.1, 3600.0, 0.1) var duration_seconds := 60.0
@export_range(0.1, 3.0, 0.01) var movement_multiplier := 1.0
@export_range(0.1, 3.0, 0.01) var stamina_cost_multiplier := 1.0
@export_range(-100, 100) var stamina_per_tick := 0
@export_range(0.1, 120.0, 0.1) var tick_interval := 5.0
@export var stacking: Stacking = Stacking.REFRESH
@export_range(1, 20) var max_stacks := 1
## HP per tick (regenerasi). Dipakai PlayerData.advance_food_effects.
@export_range(-100, 100) var hp_per_tick := 0

func is_valid_effect() -> bool:
	return not id.is_empty() and is_finite(duration_seconds) and duration_seconds > 0.0 and is_finite(movement_multiplier) and movement_multiplier > 0.0 and is_finite(stamina_cost_multiplier) and stamina_cost_multiplier > 0.0 and is_finite(tick_interval) and tick_interval > 0.0 and max_stacks > 0

func summary() -> String:
	var parts: PackedStringArray = []
	if not is_equal_approx(movement_multiplier, 1.0):
		parts.append("gerak %+.0f%%" % ((movement_multiplier - 1.0) * 100.0))
	if not is_equal_approx(stamina_cost_multiplier, 1.0):
		parts.append("biaya stamina %+.0f%%" % ((stamina_cost_multiplier - 1.0) * 100.0))
	if stamina_per_tick != 0:
		parts.append("%+d stamina / %s dtk" % [stamina_per_tick, str(tick_interval)])
	if hp_per_tick != 0:
		parts.append("%+d HP / %s dtk" % [hp_per_tick, str(tick_interval)])
	return "%s: %s · %s dtk" % [display_name, ", ".join(parts), str(duration_seconds)]
