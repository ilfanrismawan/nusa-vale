extends Node
## Probe performa: mengukur load, instantiate, _enter_tree/_ready per node, dan waktu frame
## setelah scene farm masuk. Hasil ditulis ke res://tests/farm_perf_probe.log.
## Tidak menyimpan game.

const SCENE := "res://scenes/world/farm.tscn"
const FRAMES := 120

var _log: PackedStringArray = []
var _ready_marks: Array = []  # [usec, path]
var _timeline: Array = []  # [usec, label] selama frame pertama
var _trace := false
var _last_us := 0
var _added_per_frame := 0

func _say(line: String) -> void:
	_log.append(line)
	print(line)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await get_tree().process_frame
	_say("== FARM PERF PROBE ==")
	_say("save day=%d season=%s" % [DayCycle.current_day, str(DayCycle.get_current_season())])

	var t := Time.get_ticks_usec()
	var packed := ResourceLoader.load(SCENE, "", ResourceLoader.CACHE_MODE_REUSE) as PackedScene
	_say("load PackedScene (cold, with deps): %.1f ms" % ((Time.get_ticks_usec() - t) / 1000.0))

	t = Time.get_ticks_usec()
	var world := packed.instantiate()
	_say("instantiate: %.1f ms" % ((Time.get_ticks_usec() - t) / 1000.0))

	get_tree().node_added.connect(_on_node_added)
	_last_us = Time.get_ticks_usec()
	t = _last_us
	add_child(world)
	var add_ms := (Time.get_ticks_usec() - t) / 1000.0
	_say("add_child (_enter_tree + _ready, synchronous): %.1f ms" % add_ms)
	_say("nodes in world after add: %d" % _count(world))

	# Selisih antar sinyal ready = biaya _ready node itu sendiri (anak sudah ready lebih dulu).
	var costs: Array = []
	var prev := t
	_ready_marks.sort_custom(func(a, b): return a[0] < b[0])
	for m in _ready_marks:
		costs.append([m[0] - prev, m[1]])
		prev = m[0]
	costs.sort_custom(func(a, b): return a[0] > b[0])
	_say("-- top _ready / enter gaps (ms) --")
	for i in mini(25, costs.size()):
		_say("%8.2f  %s" % [costs[i][0] / 1000.0, costs[i][1]])

	# Timeline frame pertama: kapan physics, render, dan node baru terjadi.
	get_tree().physics_frame.connect(func(): _mark("physics_frame"))
	get_tree().process_frame.connect(func(): _mark("process_frame"))
	RenderingServer.frame_pre_draw.connect(func(): _mark("render pre_draw"))
	RenderingServer.frame_post_draw.connect(func(): _mark("render post_draw"))
	_trace = true
	_timeline.append([Time.get_ticks_usec(), "start"])
	await get_tree().process_frame
	await get_tree().process_frame
	_trace = false
	_say("-- first-frame timeline: events after a gap > 15 ms --")
	for i in range(1, _timeline.size()):
		var gap: float = (_timeline[i][0] - _timeline[i - 1][0]) / 1000.0
		if gap > 15.0:
			_say("%9.1f ms gap, then: %s   (before: %s)" % [gap, _timeline[i][1], _timeline[i - 1][1]])
	_say("timeline events: %d, total %.1f ms" % [_timeline.size(), (_timeline[-1][0] - _timeline[0][0]) / 1000.0])
	# Waktu frame setelah masuk.
	var times: Array = []
	var added: Array = []
	var vp_rid := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp_rid, true)
	var sum_proc := 0.0
	var sum_phys := 0.0
	var sum_rcpu := 0.0
	var sum_rgpu := 0.0
	var last := Time.get_ticks_usec()
	for i in FRAMES:
		_added_per_frame = 0
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		times.append((now - last) / 1000.0)
		added.append(_added_per_frame)
		last = now
		sum_proc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		sum_phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		sum_rcpu += RenderingServer.viewport_get_measured_render_time_cpu(vp_rid) + RenderingServer.get_frame_setup_time_cpu()
		sum_rgpu += RenderingServer.viewport_get_measured_render_time_gpu(vp_rid)
	_say("avg per frame: _process %.1f ms, _physics_process %.1f ms, render cpu %.1f ms, render gpu %.1f ms" % [sum_proc / FRAMES, sum_phys / FRAMES, sum_rcpu / FRAMES, sum_rgpu / FRAMES])
	# Sama tetapi world disembunyikan: selisihnya = biaya gambar.
	world.visible = false
	await get_tree().process_frame
	var hidden_total := 0.0
	last = Time.get_ticks_usec()
	for i in 60:
		await get_tree().process_frame
		var now2 := Time.get_ticks_usec()
		hidden_total += (now2 - last) / 1000.0
		last = now2
	world.visible = true
	_say("world hidden: avg frame %.1f ms" % (hidden_total / 60.0))
	# Sembunyikan kelompok satu per satu untuk melihat siapa yang mahal digambar.
	var pines: Array = []
	var others: Array = []
	var tiles: Array = []
	_split_nodes(world, pines, others, tiles)
	_say("pine %d, other choppable %d, tilemap layers %d" % [pines.size(), others.size(), tiles.size()])
	var t_p: float = await _avg_hidden(pines)
	_say("hide pines: avg frame %.1f ms" % t_p)
	var t_o: float = await _avg_hidden(others)
	_say("hide other choppables: avg frame %.1f ms" % t_o)
	var t_t: float = await _avg_hidden(tiles)
	_say("hide tilemaps: avg frame %.1f ms" % t_t)
	var view := get_viewport().get_canvas_transform().affine_inverse() * Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	var off: Array = []
	for pine in pines:
		if not view.grow(64.0).has_point((pine as Node2D).global_position):
			off.append(pine)
	_say("view %s; pines on screen %d, off screen %d" % [view, pines.size() - off.size(), off.size()])
	var t_off: float = await _avg_hidden(off)
	_say("hide off-screen pines only: avg frame %.1f ms" % t_off)
	var masks: Array = []
	for pine in pines:
		for m in ["TrunkMask", "CanopyMask"]:
			var n := (pine as Node).get_node_or_null(m) as CanvasItem
			if n:
				masks.append(n)
	var saved := {}
	for m in masks:
		saved[m] = m.clip_children
		m.clip_children = CanvasItem.CLIP_CHILDREN_DISABLED
	await get_tree().process_frame
	var t_m: float = await _avg_hidden([])
	_say("pine masks clip off: avg frame %.1f ms" % t_m)
	for m in masks:
		m.clip_children = saved[m]
	_say("-- nodes processing per script (process/physics) --")
	var proc := {}
	_tally_processing(world, proc)
	var pkeys := proc.keys()
	pkeys.sort_custom(func(a, b): return proc[a] > proc[b])
	for k in pkeys.slice(0, 15):
		_say("%6d %s" % [proc[k], k])
	_say("-- AnimatedSprite2D by parent kind (playing) --")
	var anim := {}
	_tally_anim(world, anim)
	var akeys := anim.keys()
	akeys.sort_custom(func(a, b): return anim[a] > anim[b])
	for k in akeys.slice(0, 12):
		_say("%6d %s" % [anim[k], k])
	var total := 0.0
	var worst := 0.0
	var spikes := PackedStringArray()
	var over := 0
	for i in times.size():
		total += times[i]
		worst = maxf(worst, times[i])
		if times[i] > 100.0:
			spikes.append("f%d=%.0fms(+%d nodes)" % [i, times[i], added[i]])
		if times[i] > 33.0:
			over += 1
	_say("frames: avg %.1f ms, worst %.1f ms, fps(avg) %.0f" % [total / times.size(), worst, 1000.0 / (total / times.size())])
	_say("frames >33ms: %d of %d; spikes >100ms: %s" % [over, times.size(), ", ".join(spikes)])
	var first := PackedStringArray()
	for i in 20:
		first.append("%.0f" % times[i])
	_say("first 20 frames ms: " + " ".join(first))
	_say("nodes in world after %d frames: %d" % [FRAMES, _count(world)])
	_say("steady-state: draw calls %d, objects %d, physics2d active %d, collision pairs %d" % [
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		Performance.get_monitor(Performance.PHYSICS_2D_ACTIVE_OBJECTS),
		Performance.get_monitor(Performance.PHYSICS_2D_COLLISION_PAIRS)])
	_say("static mem %.1f MB, video mem %.1f MB" % [Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0])
	_say("-- node counts by class --")
	var counts := {}
	_tally(world, counts)
	var keys := counts.keys()
	keys.sort_custom(func(a, b): return counts[a] > counts[b])
	for k in keys.slice(0, 15):
		_say("%6d %s" % [counts[k], k])
	_say("== END ==")
	var f := FileAccess.open("res://tests/farm_perf_probe.log", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(_log))
		f.close()
	await get_tree().create_timer(3.0).timeout
	get_tree().quit()

func _mark(label: String) -> void:
	if _trace:
		_timeline.append([Time.get_ticks_usec(), label])

func _on_node_added(node: Node) -> void:
	_added_per_frame += 1
	if _trace:
		_timeline.append([Time.get_ticks_usec(), "add " + _short(node)])
	if not node.is_node_ready():
		node.ready.connect(func(): _ready_marks.append([Time.get_ticks_usec(), _short(node)]), CONNECT_ONE_SHOT)

func _short(node: Node) -> String:
	var p := str(node.get_path())
	var at := p.find("/Farm/")
	var s := p.substr(at) if at >= 0 else p
	if node.get_script() != null:
		s += " [" + str(node.get_script().resource_path.get_file()) + "]"
	return s

func _count(n: Node) -> int:
	var c := 1
	for ch in n.get_children():
		c += _count(ch)
	return c

func _tally(n: Node, counts: Dictionary) -> void:
	counts[n.get_class()] = counts.get(n.get_class(), 0) + 1
	for ch in n.get_children():
		_tally(ch, counts)

func _tally_processing(n: Node, counts: Dictionary) -> void:
	var sc: Script = n.get_script()
	if sc != null and (n.is_processing() or n.is_physics_processing()):
		var k := sc.resource_path.get_file()
		counts[k] = counts.get(k, 0) + 1
	for ch in n.get_children():
		_tally_processing(ch, counts)

func _tally_anim(n: Node, counts: Dictionary) -> void:
	if n is AnimatedSprite2D:
		var par := n.get_parent()
		var k := par.name.rstrip("0123456789_") + "/" + n.name.rstrip("0123456789_@") + (" playing" if (n as AnimatedSprite2D).is_playing() else " still")
		counts[k] = counts.get(k, 0) + 1
	for ch in n.get_children():
		_tally_anim(ch, counts)

func _split_nodes(n: Node, pines: Array, others: Array, tiles: Array) -> void:
	for ch in n.get_children():
		var sc: Script = ch.get_script()
		if sc != null and sc.resource_path.ends_with("pine_tree.gd"):
			pines.append(ch)
			continue
		if ch is Choppable:
			others.append(ch)
			continue
		if ch is TileMapLayer:
			tiles.append(ch)
		_split_nodes(ch, pines, others, tiles)

func _avg_hidden(nodes: Array) -> float:
	for n in nodes:
		n.visible = false
	await get_tree().process_frame
	var total := 0.0
	var last := Time.get_ticks_usec()
	for i in 60:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		total += (now - last) / 1000.0
		last = now
	for n in nodes:
		n.visible = true
	return total / 60.0
