class_name AttackTickets
extends RefCounted

## Token serang (GDD 8.2-B4): hanya Perception.RULES.max_attackers musuh yang boleh menyerang
## satu pemain bersamaan. Musuh lain mengepung sambil menunggu giliran. Token dilepas setelah
## serangan selesai, saat musuh terhuyung, mundur, kehilangan target, atau mati.

## instance id pemain -> Array[Enemy] pemegang token.
static var _holders: Dictionary = {}

static func request(enemy: Enemy, target: Node) -> bool:
	if enemy == null or target == null:
		return false
	var list := _list(target)
	if list.has(enemy):
		return true
	if list.size() >= Perception.RULES.max_attackers:
		return false
	list.append(enemy)
	return true

static func holds(enemy: Enemy, target: Node) -> bool:
	return target != null and _list(target).has(enemy)

static func release(enemy: Enemy) -> void:
	for key in _holders.keys():
		var list: Array = _holders[key]
		list.erase(enemy)
		if list.is_empty():
			_holders.erase(key)

static func holders(target: Node) -> Array:
	return _list(target).duplicate() if target != null else []

static func clear() -> void:
	_holders.clear()

## Daftar pemegang token untuk target ini, tanpa musuh yang sudah mati atau dihapus.
static func _list(target: Node) -> Array:
	var key := target.get_instance_id()
	var list: Array = _holders.get(key, [])
	for enemy in list.duplicate():
		if not is_instance_valid(enemy) or (enemy as Enemy).is_dead() or not (enemy as Enemy).is_inside_tree():
			list.erase(enemy)
	_holders[key] = list
	return list
