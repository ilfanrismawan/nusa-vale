class_name EnemyBrain
extends RefCounted

## Pohon perilaku musuh biasa (GDD 8.2-B). Dibangun sekali per musuh oleh Enemy._ready.
## Prioritas dari atas ke bawah (Selector reaktif):
##   retreat     HP rendah: mundur ke belakang kawan dan memanggil bantuan (sekali saja).
##   combat      punya target: serang bila memegang token, kadang feint; tanpa token = mengepung.
##   investigate mendengar suara / melihat siluet: berjalan waspada ke sumbernya lalu menoleh.
##   return      kehilangan target terlalu jauh: pulang ke titik asal.
##   patrol      diam dan patroli acak di sekitar titik asal.
## Aksi dan syarat ada di Enemy (fungsi bt_*), supaya pohon hanya mengatur urutan keputusan.

const BT := preload("res://scripts/ai/behavior_tree.gd")

static func build(enemy: Enemy) -> BehaviorTree:
	var data := enemy.data
	var retreat := BT.Sequence.new([
		BT.Condition.new(enemy.bt_should_retreat),
		BT.Limit.new(BT.Action.new(enemy.bt_retreat, enemy.bt_stop_retreat), 1),
	]).named("retreat")

	var feint := BT.Sequence.new([
		BT.Cooldown.new(BT.Condition.new(enemy.bt_roll_feint), maxf(1.0, data.feint_cooldown)),
		BT.Action.new(enemy.bt_feint),
	]).named("feint")
	var strike := BT.Sequence.new([
		BT.Condition.new(enemy.bt_in_attack_range),
		BT.Condition.new(enemy.bt_take_ticket),
		BT.Selector.new([feint, BT.Action.new(enemy.bt_attack).named("attack")]),
	]).named("strike")
	var approach := BT.Sequence.new([
		BT.Condition.new(enemy.bt_take_ticket),
		BT.Action.new(enemy.bt_chase),
	]).named("chase")
	var combat := BT.Sequence.new([
		BT.Condition.new(enemy.bt_has_target),
		BT.Selector.new([strike, approach, BT.Action.new(enemy.bt_flank).named("flank")]),
	]).named("combat")

	var investigate := BT.Sequence.new([
		BT.Condition.new(enemy.bt_is_suspicious),
		BT.Action.new(enemy.bt_investigate),
	]).named("investigate")
	var go_home := BT.Sequence.new([
		BT.Condition.new(enemy.bt_should_return),
		BT.Action.new(enemy.bt_return_home),
	]).named("return")
	var patrol := BT.Action.new(enemy.bt_patrol).named("patrol")

	return BehaviorTree.new(BT.Selector.new([retreat, combat, investigate, go_home, patrol]).named("root"), enemy)
