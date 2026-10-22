class_name TelevisionUI
extends CanvasLayer

## Layar siaran Televisi di rumah: Prakiraan Cuaca esok hari, Tips Pedesaan (Living off the Land),
## dan Siaran Dapur Nusantara (resep masakan).

const ServiceTheme = preload("res://scripts/ui/farm_service_theme.gd")

var player: Player
var player_data: PlayerData:
	get:
		if is_instance_valid(player) and player.data != null:
			return player.data
		return _explicit_data
	set(v):
		_explicit_data = v
var _explicit_data: PlayerData = null

var _panel: PanelContainer
var _title_label: Label
var _content_title: Label
var _content_body: RichTextLabel
var _channel_weather_btn: Button
var _channel_tips_btn: Button
var _channel_cooking_btn: Button
var _active_channel := 0 # 0=Weather, 1=Tips, 2=Cooking
var _closed := false

const TV_RECIPES := [
	"fried_egg",
	"baked_potato",
	"vegetablle_soup",
	"fruit_salad",
	"grilled_catfish",
	"mushroom_saute",
	"bread",
	"coleslaw",
	"corn_on_cob",
	"complete_breakfast",
	"apple_pie",
	"banana_bread",
	"berry_sorbet",
]

const LIVING_TIPS := [
	{
		"title": "🌾 Mesin Fermentasi Keg",
		"body": "Tahukah Anda? Mesin Keg dapat mengubah gandum menjadi Bir, madu bunga menjadi Minuman Mead, dan aneka buah panen menjadi Wine bernilai tinggi!\n\nProses fermentasi memakan waktu lebih lama dari Preserves Jar, namun hasil jualnya jauh lebih menguntungkan untuk membangun ekonomi pertanian Anda."
	},
	{
		"title": "🌻 Pengolah Minyak (Oil Maker)",
		"body": "Gunakan Oil Maker untuk memeras jagung atau bunga matahari menjadi Minyak Masak dapur.\n\nJika Anda memelihara babi di peternakan dan menemukan Truffle liar di tanah, olah Truffle tersebut di Oil Maker untuk menghasilkan Minyak Truffle berkualitas artisanal dengan harga selangit!"
	},
	{
		"title": "🐟 Pengasapan Ikan (Fish Smoker)",
		"body": "Nelayan cerdas tidak langsung menjual ikan mentah! Fish Smoker mengasapi ikan segar menggunakan arang/serpihan kayu.\n\nIkan asap mempertahankan mutu Bintang Perak maupun Emas aslinya, sekaligus menggandakan harga jualnya secara signifikan."
	},
	{
		"title": "🍎 Pohon Buah Abadi (Fruit Trees)",
		"body": "Pohon buah seperti Apel, Jeruk, Persik, dan Mangga bersifat permanen dan tidak akan layu saat pergantian musim!\n\nBegitu mencapai kedewasaan, mereka akan terus menghasilkan buah setiap hari di musim berbuahnya. Dengan perk Perpetual Orchard atau Rumah Kaca, pohon buah bahkan dapat berbuah sepanjang tahun!"
	},
	{
		"title": "⭐ Kualitas Panen & Forage Bintang Emas",
		"body": "Tingkat kemahiran Bertani (Farmer) dan Mengumpulkan (Forager) membuka peluang panen berkualitas Bintang Perak (+25% harga) dan Bintang Emas (+50% harga)!\n\nRawat tanaman setiap hari dan pilih perk profesi yang tepat untuk melipatgandakan penghasilan."
	},
	{
		"title": "⚡ Penangkal Petir & Cuaca Badai",
		"body": "Saat siaran ramalan cuaca mengumumkan Badai Petir esok hari, pasang Penangkal Petir (Lightning Rod) di ladang terbuka Anda!\n\nPenangkal petir akan menyerap sambaran kilat berbahaya dan mengubahnya menjadi Baterai (Battery Pack) berkualitas tinggi yang siap diambil keesokan paginya."
	},
	{
		"title": "🎁 Persahabatan & Hadiah Warga",
		"body": "Menyapa warga desa setiap hari meningkatkan keakraban sosial Anda. Berikan hadiah kesukaan mereka untuk mempercepat jalinan persahabatan!\n\nSaat persahabatan mencapai tingkat tinggi, warga akan membagikan resep masakan rahasia dan mengirimkan hadiah berharga lewat kotak surat rumah Anda."
	},
	{
		"title": "📈 Papan Tren Pasar & Rotasi Tanaman",
		"body": "Kunjungi Balai Desa secara berkala untuk memeriksa papan tren pasar desa!\n\nKomoditas yang sedang 'Booming' memiliki harga jual berlipat ganda, sementara komoditas yang sedang 'Surplus' mengalami penurunan harga. Menerapkan rotasi tanaman adalah kunci petani sukses."
	}
]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = ServiceTheme.LAYER
	_build_ui()
	if is_instance_valid(player):
		Coop.set_menu_open(player, true)
	_switch_channel(0)

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.size = Vector2(620, 380)
	var vp := get_viewport().get_visible_rect().size
	var zoom := minf(1.0, minf((vp.x - 20) / 620, (vp.y - 20) / 380))
	_panel.scale = Vector2.ONE * zoom
	_panel.position = ((vp - _panel.size * zoom) / 2).floor()
	_panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_panel.theme = ServiceTheme.make_theme()
	_panel.add_theme_stylebox_override("panel", ServiceTheme.frame())
	add_child(_panel)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 8)
	_panel.add_child(root_vbox)

	# ── Header ──
	var header := HBoxContainer.new()
	root_vbox.add_child(header)

	_title_label = Label.new()
	_title_label.text = "📺 Televisi Tabung Nusa Vale"
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title_label)

	var date_label := Label.new()
	date_label.text = "Hari %d (%s)" % [DayCycle.current_day, DayCycle.get_season_display_name()]
	date_label.add_theme_font_size_override("font_size", 16)
	date_label.modulate = Color(0.85, 0.9, 0.8)
	header.add_child(date_label)

	var close_btn := Button.new()
	close_btn.text = " [X] Tutup "
	close_btn.pressed.connect(_close)
	header.add_child(close_btn)

	# ── Body Split: Channel list (left) & Screen Broadcast (right) ──
	var body_hbox := HBoxContainer.new()
	body_hbox.add_theme_constant_override("separation", 12)
	body_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(body_hbox)

	var ch_vbox := VBoxContainer.new()
	ch_vbox.custom_minimum_size.x = 180
	ch_vbox.add_theme_constant_override("separation", 6)
	body_hbox.add_child(ch_vbox)

	var ch_heading := Label.new()
	ch_heading.text = "Saluran Siaran:"
	ch_heading.add_theme_font_size_override("font_size", 16)
	ch_vbox.add_child(ch_heading)

	_channel_weather_btn = Button.new()
	_channel_weather_btn.text = "1. Ramalan Cuaca"
	_channel_weather_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_channel_weather_btn.pressed.connect(func(): _switch_channel(0))
	ch_vbox.add_child(_channel_weather_btn)

	_channel_tips_btn = Button.new()
	_channel_tips_btn.text = "2. Tips Pedesaan"
	_channel_tips_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_channel_tips_btn.pressed.connect(func(): _switch_channel(1))
	ch_vbox.add_child(_channel_tips_btn)

	_channel_cooking_btn = Button.new()
	_channel_cooking_btn.text = "3. Dapur Nusantara"
	_channel_cooking_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_channel_cooking_btn.pressed.connect(func(): _switch_channel(2))
	ch_vbox.add_child(_channel_cooking_btn)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ch_vbox.add_child(spacer)

	var off_btn := Button.new()
	off_btn.text = "Matikan TV (Esc)"
	off_btn.pressed.connect(_close)
	ch_vbox.add_child(off_btn)

	# ── TV CRT Screen Area (Right) ──
	var screen_panel := PanelContainer.new()
	screen_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	screen_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	screen_panel.add_theme_stylebox_override("panel", ServiceTheme.dialogue())
	body_hbox.add_child(screen_panel)

	var screen_vbox := VBoxContainer.new()
	screen_vbox.add_theme_constant_override("separation", 6)
	screen_panel.add_child(screen_vbox)

	_content_title = Label.new()
	_content_title.text = "Siaran Televisi"
	_content_title.add_theme_font_size_override("font_size", 18)
	_content_title.modulate = Color(1.0, 0.95, 0.6)
	screen_vbox.add_child(_content_title)

	var screen_scroll := ScrollContainer.new()
	screen_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	screen_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	screen_vbox.add_child(screen_scroll)

	_content_body = RichTextLabel.new()
	_content_body.bbcode_enabled = true
	_content_body.fit_content = true
	_content_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	screen_scroll.add_child(_content_body)

func _switch_channel(channel: int) -> void:
	_active_channel = channel
	_channel_weather_btn.modulate = Color(1.2, 1.2, 1.0) if channel == 0 else Color.WHITE
	_channel_tips_btn.modulate = Color(1.2, 1.2, 1.0) if channel == 1 else Color.WHITE
	_channel_cooking_btn.modulate = Color(1.2, 1.2, 1.0) if channel == 2 else Color.WHITE

	match channel:
		0:
			_render_weather()
		1:
			_render_tips()
		2:
			_render_cooking()

func _render_weather() -> void:
	var tomorrow := DayCycle.current_day + 1
	var weather_type := "sunny"
	if GameState.weather != null:
		weather_type = GameState.weather.weather_for(tomorrow)

	_content_title.text = "📡 BMKG Nusa Vale — Prakiraan Esok Hari"
	var text := ""

	match weather_type:
		"storm":
			text = "[color=#ffcc44][b]⚡ PERINGATAN BADAI PETIR ESLEK HARI! ⚡[/b][/color]\n\n"
			text += "Pusat ramalan cuaca mendeteksi pusaran awan konvektif bertegangan tinggi di atas lembah. Besok diprediksi akan terjadi [b]Badai Petir[/b] dahsyat!\n\n"
			text += "• [color=#aaffaa]Hujan lebat[/color] akan menyiram semua tanaman di ladang terbuka secara otomatis.\n"
			text += "• Sambaran petir dapat merusak pohon atau tanaman yang tidak terlindungi.\n"
			text += "• Pasang [b]Penangkal Petir (Lightning Rod)[/b] di ladang untuk menyerap sambaran kilat menjadi [b]Battery Pack[/b] keesokan paginya!\n"
			text += "• Amankan hewan ternak agar tetap berada di dalam kandang."
		"rain":
			text = "[color=#66ccff][b]🌧️ PRAKIRAAN CUACA: HUJAN LEBAT[/b][/color]\n\n"
			text += "Awan mendung sejuk akan menyelimuti seluruh kawasan Nusa Vale sepanjang hari esok. Hujan lebat diprediksi mengguyur perbukitan dan lembah!\n\n"
			text += "• Seluruh tanaman di ladang terbuka akan [b]tersiram otomatis[/b] oleh air hujan.\n"
			text += "• Hemat energi Anda dari menyiram tanaman untuk memancing ikan langka air tawar atau menambang mineral berharga di gua tambang!"
		_:
			text = "[color=#ffe066][b]☀️ PRAKIRAAN CUACA: CERAH BERAWAN[/b][/color]\n\n"
			text += "Hari esok diprediksi sangat cerah dengan hembusan angin sepoi-sepoi yang menyenangkan. Matahari bersinar cerah dari pagi hingga petang!\n\n"
			text += "• Sinar matahari sangat melimpah untuk memacu fotosintesis tanaman Anda.\n"
			text += "• Jangan lupa menyiram tanaman di ladang dan sapalah para tetangga ramah di desa."

	_content_body.text = text

func _render_tips() -> void:
	_content_title.text = "🌾 Hidup Bersama Alam (Living off the Land)"
	var idx := posmod(DayCycle.current_day - 1, LIVING_TIPS.size())
	var tip: Dictionary = LIVING_TIPS[idx]
	var text := "[b]%s[/b]\n\n%s" % [tip.get("title", ""), tip.get("body", "")]
	_content_body.text = text

func _render_cooking() -> void:
	_content_title.text = "🍳 Dapur Nusantara — Ragam Rasa Lembah"
	var idx := posmod(DayCycle.current_day - 1, TV_RECIPES.size())
	var recipe_id: String = TV_RECIPES[idx]
	var recipe := CookingManager.get_recipe(recipe_id)

	var text := "Halo sahabat kuliner Nusa Vale! Selamat datang di siaran [b]Dapur Nusantara[/b]!\n\n"
	if recipe == null:
		text += "Hari ini kami menayangkan jeda iklan resep kuliner. Kunjungi Warung atau Dapur Wira untuk koleksi buku resep lainnya!"
		_content_body.text = text
		return

	var display := recipe.display_name
	var ing_lines: Array[String] = []
	for ing in recipe.ingredients.keys():
		var count: int = int(recipe.ingredients[ing])
		var item := GameState._resolve_item(str(ing))
		var ing_name: String = item.display_name if item != null else str(ing)
		ing_lines.append("%dx %s" % [count, ing_name])

	text += "Hari ini Chef menyajikan resep lezat: [b][color=#ffff88]%s[/color][/b]!\n\n" % display
	text += "[b]Bahan-bahan yang dibutuhkan:[/b]\n"
	text += "• " + "\n• ".join(ing_lines) + "\n\n"

	var pdata := player_data
	if pdata != null:
		if not pdata.learned_recipes.has(recipe_id):
			pdata.learned_recipes.append(recipe_id)
			pdata._changed()
			text += "[color=#88ff88][b]✨ Resep Baru Dipelajari![/b][/color]\nResep [b]%s[/b] telah dicatat ke Buku Resep Anda di dapur rumah!" % display
			Notify.say("Mempelajari resep %s dari TV!" % display)
		else:
			text += "[color=#cccccc]*(Anda sudah menguasai resep %s di Buku Resep.)*[/color]" % display

	_content_body.text = text

func _unhandled_input(event: InputEvent) -> void:
	if _closed:
		return
	if is_instance_valid(player) and not Coop.accepts_event(player, event):
		return
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()
	elif event.is_action_pressed(&"hotbar_1"):
		get_viewport().set_input_as_handled()
		_switch_channel(0)
	elif event.is_action_pressed(&"hotbar_2"):
		get_viewport().set_input_as_handled()
		_switch_channel(1)
	elif event.is_action_pressed(&"hotbar_3"):
		get_viewport().set_input_as_handled()
		_switch_channel(2)

func _close() -> void:
	if _closed:
		return
	_closed = true
	if is_instance_valid(player):
		Coop.set_menu_open(player, false)
	queue_free()
