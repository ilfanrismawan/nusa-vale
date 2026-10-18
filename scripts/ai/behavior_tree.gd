class_name BehaviorTree
extends RefCounted

## Behavior Tree modular (GDD 8.2-B1). Composite: Selector, Sequence, Parallel.
## Decorator: Inverter, Repeater, Cooldown, Limit. Leaf: Condition, Action, Wait.
## Pohon dibangun di kode (lihat EnemyBrain), lalu tick() dipanggil tiap frame fisika.
## Setiap node mengembalikan SUCCESS, FAILURE, atau RUNNING.

const SUCCESS := 0
const FAILURE := 1
const RUNNING := 2

var root: BTNode
var blackboard := Blackboard.new()

func _init(p_root: BTNode, actor: Object = null) -> void:
	root = p_root
	blackboard.actor = actor

func tick(delta: float) -> int:
	blackboard.delta = delta
	blackboard.time += delta
	return root.tick(blackboard)

func reset() -> void:
	root.reset()

## Nama node yang sedang RUNNING dari akar ke daun, mis. "combat/flank" (untuk debug dan tes).
func running_path() -> String:
	var names: PackedStringArray = []
	var node := root
	while node != null:
		if not node.name.is_empty():
			names.append(node.name)
		node = node.running_child()
	return "/".join(names)

#region Inti

## Data bersama untuk satu pohon: aktor, waktu, dan nilai bebas.
class Blackboard extends RefCounted:
	var actor: Object
	var delta := 0.0
	## Detik sejak pohon pertama di-tick (dipakai Cooldown).
	var time := 0.0
	var values: Dictionary = {}

class BTNode extends RefCounted:
	var name := ""
	var last_status := FAILURE

	func tick(bb: Blackboard) -> int:
		last_status = _tick(bb)
		return last_status

	func _tick(_bb: Blackboard) -> int:
		return FAILURE

	func reset() -> void:
		pass

	## Anak yang sedang RUNNING (untuk running_path).
	func running_child() -> BTNode:
		return null

	func named(p_name: String) -> BTNode:
		name = p_name
		return self

#endregion

#region Composite

class Composite extends BTNode:
	var children: Array[BTNode] = []
	var _running := -1

	func _init(p_children: Array = []) -> void:
		for child in p_children:
			children.append(child)

	func reset() -> void:
		_running = -1
		for child in children:
			child.reset()

	func running_child() -> BTNode:
		return children[_running] if _running >= 0 and _running < children.size() else null

	func _switch_running(index: int, status: int) -> void:
		if _running >= 0 and _running != index:
			children[_running].reset()
		_running = index if status == RUNNING else -1

## Prioritas: coba anak dari kiri; anak pertama yang tidak FAILURE menang. Reaktif: tiap tick
## mulai dari anak pertama, jadi cabang prioritas tinggi (mis. mundur) bisa menyela cabang lain.
class Selector extends Composite:
	func _tick(bb: Blackboard) -> int:
		for i in children.size():
			var status := children[i].tick(bb)
			if status != FAILURE:
				_switch_running(i, status)
				return status
		_switch_running(-1, FAILURE)
		return FAILURE

## Urutan: semua anak harus SUCCESS. Action yang sudah selesai tidak diulang sampai urutan
## selesai, tapi Condition selalu dicek ulang tiap tick (urutan batal begitu syaratnya gagal).
class Sequence extends Composite:
	var _index := 0

	func _tick(bb: Blackboard) -> int:
		for i in children.size():
			var child := children[i]
			if i < _index and not child is Condition:
				continue
			var status := child.tick(bb)
			if status == RUNNING:
				_index = i
				_switch_running(i, status)
				return RUNNING
			if status == FAILURE:
				reset()
				return FAILURE
		reset()
		return SUCCESS

	func reset() -> void:
		_index = 0
		super.reset()

## Semua anak di-tick bersamaan. SUCCESS bila minimal `success_needed` anak sukses,
## FAILURE bila itu sudah mustahil.
class Parallel extends Composite:
	var success_needed := 1

	func _init(p_children: Array = [], p_success_needed: int = 1) -> void:
		super._init(p_children)
		success_needed = p_success_needed

	func _tick(bb: Blackboard) -> int:
		var successes := 0
		var failures := 0
		for i in children.size():
			match children[i].tick(bb):
				SUCCESS:
					successes += 1
				FAILURE:
					failures += 1
				RUNNING:
					_running = i
		if successes >= success_needed:
			reset()
			return SUCCESS
		if failures > children.size() - success_needed:
			reset()
			return FAILURE
		return RUNNING

#endregion

#region Decorator

class Decorator extends BTNode:
	var child: BTNode

	func _init(p_child: BTNode) -> void:
		child = p_child

	func reset() -> void:
		child.reset()

	func running_child() -> BTNode:
		return child if child.last_status == RUNNING else null

class Inverter extends Decorator:
	func _tick(bb: Blackboard) -> int:
		match child.tick(bb):
			SUCCESS:
				return FAILURE
			FAILURE:
				return SUCCESS
		return RUNNING

## Ulangi anak sampai sukses `times` kali (-1 = selamanya). Gagal sekali = FAILURE.
class Repeater extends Decorator:
	var times := -1
	var _done := 0

	func _init(p_child: BTNode, p_times: int = -1) -> void:
		super._init(p_child)
		times = p_times

	func _tick(bb: Blackboard) -> int:
		var status := child.tick(bb)
		if status == FAILURE:
			_done = 0
			return FAILURE
		if status == SUCCESS:
			_done += 1
			child.reset()
			if times > 0 and _done >= times:
				_done = 0
				return SUCCESS
		return RUNNING

	func reset() -> void:
		_done = 0
		super.reset()

## Setelah anak selesai (SUCCESS atau FAILURE), anak tidak dijalankan lagi selama `seconds`
## (selama itu Cooldown mengembalikan FAILURE).
class Cooldown extends Decorator:
	var seconds := 1.0
	var _ready_at := -INF

	func _init(p_child: BTNode, p_seconds: float) -> void:
		super._init(p_child)
		seconds = p_seconds

	func _tick(bb: Blackboard) -> int:
		if bb.time < _ready_at:
			return FAILURE
		var status := child.tick(bb)
		if status != RUNNING:
			_ready_at = bb.time + seconds
		return status

	func remaining(bb: Blackboard) -> float:
		return maxf(0.0, _ready_at - bb.time)

## Anak hanya boleh selesai `max_runs` kali; sesudahnya FAILURE (mis. mundur sekali saja).
class Limit extends Decorator:
	var max_runs := 1
	var runs := 0

	func _init(p_child: BTNode, p_max_runs: int = 1) -> void:
		super._init(p_child)
		max_runs = p_max_runs

	func _tick(bb: Blackboard) -> int:
		if runs >= max_runs:
			return FAILURE
		var status := child.tick(bb)
		if status != RUNNING:
			runs += 1
		return status

#endregion

#region Leaf

## Syarat: Callable(bb) -> bool.
class Condition extends BTNode:
	var check: Callable

	func _init(p_check: Callable) -> void:
		check = p_check

	func _tick(bb: Blackboard) -> int:
		return SUCCESS if check.call(bb) else FAILURE

## Aksi: Callable(bb) -> SUCCESS/FAILURE/RUNNING. `on_reset` dipanggil saat aksi disela.
class Action extends BTNode:
	var run: Callable
	var on_reset: Callable

	func _init(p_run: Callable, p_on_reset: Callable = Callable()) -> void:
		run = p_run
		on_reset = p_on_reset

	func _tick(bb: Blackboard) -> int:
		return int(run.call(bb))

	func reset() -> void:
		if last_status == RUNNING and on_reset.is_valid():
			on_reset.call()
		last_status = FAILURE

## Tunggu beberapa detik (RUNNING), lalu SUCCESS.
class Wait extends BTNode:
	var seconds := 1.0
	var _left := -1.0

	func _init(p_seconds: float) -> void:
		seconds = p_seconds

	func _tick(bb: Blackboard) -> int:
		if _left < 0.0:
			_left = seconds
		_left -= bb.delta
		if _left <= 0.0:
			_left = -1.0
			return SUCCESS
		return RUNNING

	func reset() -> void:
		_left = -1.0

#endregion
