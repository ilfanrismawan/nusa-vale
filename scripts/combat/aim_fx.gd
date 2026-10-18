class_name AimFx
extends Node2D

## Rasa membidik busur dan tongkat sihir (klik kanan ditahan). Dibuat Player saat pertama
## membidik dengan senjata jarak jauh, sebagai anak Player (koordinat lokal pemain).
## - Tarikan 0..1 naik selama CombatRules.aim_draw_time: garis bidik bertitik makin terang,
##   lingkar bidik mengecil, tali berderit / tongkat berdengung dengan nada naik.
## - Penuh: kilatan + denting akor (jumlah nada dari WeaponTierFx.chime_notes), badan berkilau,
##   butir cahaya tier berputar di ujung senjata dan partikel tier keluar sesekali.
## - Tembakan memanggil release(): nilai tarikan dipakai CombatState (tembakan "charged") lalu ulang dari 0.
## Hanya rasa; tidak mengubah damage.

signal fully_drawn

## Jarak ujung senjata dari tengah badan, searah bidikan.
const MUZZLE := 9.0
const DOT_SPACING := 6.0

var draw_ratio := 0.0
var aiming := false
var style: WeaponStyle
var fx: WeaponTierFx
var direction := Vector2.RIGHT
var length := 64.0
var _full := false
var _time := 0.0
var _flash := 0.0
var _mote_timer := 0.0
var _loop: AudioStreamPlayer

func _ready() -> void:
	z_index = 9
	_loop = AudioStreamPlayer.new()
	_loop.bus = Juice.SFX_BUS
	add_child(_loop)

## Dipanggil Player tiap frame. can_draw = false selama animasi tembak (tarikan tidak naik).
func update(delta: float, p_aiming: bool, can_draw: bool, p_direction: Vector2, p_style: WeaponStyle, p_fx: WeaponTierFx, p_length: float) -> void:
	_time += delta
	_flash = maxf(0.0, _flash - delta * 4.0)
	if not p_aiming or p_style == null:
		if aiming:
			_stop()
		visible = _flash > 0.0
		queue_redraw()
		return
	if not aiming or p_style != style:
		_begin(p_style)
	aiming = true
	visible = true
	style = p_style
	fx = p_fx if p_fx != null else WeaponTierFx.for_tier(0)
	direction = p_direction.normalized() if p_direction.length() > 0.01 else direction
	length = maxf(16.0, p_length)
	if can_draw and not _full:
		draw_ratio = minf(1.0, draw_ratio + delta / maxf(0.05, Combat.RULES.aim_draw_time))
		if draw_ratio >= 1.0:
			_on_full()
	_update_sound()
	if _full:
		_mote_timer -= delta
		if _mote_timer <= 0.0:
			_mote_timer = lerpf(0.35, 0.1, clampf(fx.aim_motes / 12.0, 0.0, 1.0))
			CombatJuice.motif_burst(global_position + muzzle_point(), fx, 1 + roundi(fx.aim_motes / 4.0))
	queue_redraw()

func is_full() -> bool:
	return _full

## Tembakan keluar: kembalikan tarikan (0..1) lalu mulai menarik dari awal lagi.
func release() -> float:
	var value := draw_ratio
	draw_ratio = 0.0
	_full = false
	if value >= 1.0:
		_flash = 1.0
	return value

## Ujung busur/tongkat di koordinat lokal pemain.
func muzzle_point() -> Vector2:
	return Player.FEET_OFFSET * 0.5 + direction * MUZZLE

func is_magic() -> bool:
	return style != null and style.projectile_texture == null

func _begin(new_style: WeaponStyle) -> void:
	style = new_style
	draw_ratio = 0.0
	_full = false
	_loop.stream = SfxSynth.staff_hum() if new_style.projectile_texture == null else SfxSynth.bow_creak()
	_loop.volume_db = -30.0
	_loop.play()

func _stop() -> void:
	aiming = false
	draw_ratio = 0.0
	_full = false
	_loop.stop()

func _on_full() -> void:
	_full = true
	_flash = 1.0
	_mote_timer = 0.0
	fully_drawn.emit()
	# Akor denting: tier tinggi = lebih banyak nada, disusun cepat seperti arpeggio.
	var base := 5.0 if is_magic() else 0.0
	for i in fx.chime_notes.size():
		var note := float(fx.chime_notes[i]) + base
		if i == 0:
			Juice.sfx(SfxSynth.chime(), -12.0, 0.0, note)
		else:
			get_tree().create_timer(0.045 * i, false).timeout.connect(Juice.sfx.bind(SfxSynth.chime(), -15.0 - i, 0.0, note))
	Juice.sfx(Juice.impact_stream(fx.impact_layers[0] if not fx.impact_layers.is_empty() else "impactMetal_light_002"), -16.0, 0.0, fx.impact_semitones + 7.0)
	CombatJuice.flash(global_position + muzzle_point(), fx.glow if fx.glow.a > 0.0 else Color(1, 1, 1, 0.6), 5.0 * fx.muzzle_scale)
	CombatJuice.motif_burst(global_position + muzzle_point(), fx, 3 + fx.aim_motes)
	var player := get_parent() as Player
	if player != null and player.animation_controller != null:
		var sprite := player.animation_controller.sprite
		var glow := Color(1.0, 1.0, 1.0).lerp(fx.color, 0.4) * 1.6
		glow.a = 1.0
		sprite.modulate = glow
		sprite.create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.18)

func _update_sound() -> void:
	if not _loop.playing:
		_loop.play()
	if is_magic():
		_loop.pitch_scale = lerpf(0.7, 1.15, draw_ratio) + (0.03 * sin(_time * 12.0) if _full else 0.0)
		_loop.volume_db = lerpf(-28.0, -15.0, draw_ratio)
	else:
		# Tali makin tegang saat ditarik; setelah penuh hanya derit pelan saat ditahan.
		_loop.pitch_scale = lerpf(0.75, 1.35, draw_ratio)
		_loop.volume_db = -26.0 if _full else lerpf(-24.0, -13.0, draw_ratio)

func _draw() -> void:
	if style == null:
		return
	var color := Color.WHITE.lerp(fx.color, 0.3 + 0.7 * draw_ratio) if fx != null else Color.WHITE
	var origin := Player.FEET_OFFSET * 0.5
	if aiming:
		_draw_guide(origin, color)
		_draw_reticle(origin + direction * length, color)
		_draw_muzzle(color)
	if _flash > 0.0:
		var at := muzzle_point()
		draw_arc(at, 4.0 + 10.0 * (1.0 - _flash), 0.0, TAU, 20, Color(color, _flash), 1.0)

## Garis bidik bertitik yang mengalir ke depan; makin terang saat tarikan penuh.
func _draw_guide(origin: Vector2, color: Color) -> void:
	var offset := fmod(_time * (40.0 if _full else 18.0), DOT_SPACING)
	var distance := 10.0 + offset
	var alpha := 0.18 + 0.5 * draw_ratio
	while distance < length - 4.0:
		var fade := 1.0 - distance / length * 0.6
		var p := (origin + direction * distance).round()
		var dot := 2.0 if _full else 1.0
		draw_rect(Rect2(p - Vector2.ONE * dot * 0.5, Vector2.ONE * dot), Color(color, alpha * fade))
		distance += DOT_SPACING

## Lingkar bidik: empat garis kecil yang merapat saat tarikan naik, berdenyut saat penuh.
func _draw_reticle(at: Vector2, color: Color) -> void:
	var tighten := ease(draw_ratio, 0.6)
	var radius := lerpf(10.0, 3.5, tighten)
	if _full:
		radius += sin(_time * 14.0) * 0.6
	var spin := _time * (2.5 if _full else 0.8)
	for i in 4:
		var dir := Vector2.from_angle(spin + PI * 0.5 * i)
		draw_line((at + dir * radius).round(), (at + dir * (radius + 3.0)).round(), Color(color, 0.55 + 0.4 * draw_ratio), 1.0)
	if _full:
		draw_arc(at, radius + 1.0, 0.0, TAU, 16, Color(color, 0.7), 1.0)
		draw_rect(Rect2(at.round() - Vector2(0.5, 0.5), Vector2.ONE), Color.WHITE)

## Busur: kilau di ujung anak panah. Tongkat: bola energi yang membesar dengan butir berputar.
func _draw_muzzle(color: Color) -> void:
	var at := muzzle_point()
	var motes := maxi(2, fx.aim_motes) if fx != null else 2
	if fx != null and fx.halo_radius > 0.0 and draw_ratio > 0.2:
		draw_circle(at, fx.halo_radius * draw_ratio + 1.0, Color(fx.glow, fx.glow.a * 0.5 * draw_ratio))
	if is_magic():
		var r := 1.0 + 2.5 * draw_ratio + (0.4 * sin(_time * 20.0) if _full else 0.0)
		draw_circle(at, r + 1.5, Color(color, 0.3))
		draw_circle(at, r, color)
		draw_circle(at - Vector2(0.5, 0.5), maxf(0.5, r * 0.4), Color.WHITE)
	else:
		var s := 1.0 + 3.0 * draw_ratio
		var c := Color(color.lightened(0.3), 0.4 + 0.6 * draw_ratio)
		draw_line(at - Vector2(s, 0), at + Vector2(s, 0), c, 1.0)
		draw_line(at - Vector2(0, s), at + Vector2(0, s), c, 1.0)
	# Butir cahaya mengorbit lalu menyempit ke ujung senjata saat ditarik.
	var orbit := lerpf(9.0, 4.0, draw_ratio)
	for i in motes:
		var angle := _time * (3.0 + draw_ratio * 5.0) + TAU * i / motes
		var p := (at + Vector2.from_angle(angle) * orbit * Vector2(1.0, 0.6)).round()
		var mote := fx.color_alt if fx != null and i % 2 == 1 else color
		draw_rect(Rect2(p, Vector2.ONE), Color(mote, 0.25 + 0.65 * draw_ratio))
