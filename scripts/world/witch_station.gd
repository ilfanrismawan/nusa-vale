extends StaticBody2D

## Stasiun sihir di Menara Penyihir (GDD "Menara Penyihir"):
##   cauldron = Kuali ramuan lanjutan, mini game Racik di Kuali.
##   charm    = Meja Jimat penolak makhluk malam, mini game Gambar Rune.
##   enchant  = Altar Enchant: pesona senjata yang dipegang, mini game Urutan Mantra.
## Gagal = bahan/biaya utuh, stamina terpakai FAIL_STAMINA (boleh coba lagi kapan saja).
## Hanya untuk karakter yang sudah lulus Dasar Sihir Tongkat (pintu menara juga menyegel).
## Player._find_interactable memanggil interact(player) karena meta "player_interaction".

const Enchanting = preload("res://scripts/system/enchanting.gd")
const RecipeMenu = preload("res://scripts/ui/magic/witch_recipe_menu.gd")
const BrewGame = preload("res://scripts/ui/magic/cauldron_brew_game.gd")
const RuneGame = preload("res://scripts/ui/magic/rune_trace_game.gd")
const SequenceGame = preload("res://scripts/ui/magic/spell_sequence_game.gd")
const SIGN_FONT := preload("res://assets/fonts/m5x7.ttf")
const FAIL_STAMINA := 10
const ATTEMPT_STAMINA := 4

## "cauldron", "charm", atau "enchant".
@export_enum("cauldron", "charm", "enchant") var station := "cauldron"
@export_multiline var message := ""
## Papan nama kecil di atas stasiun (kosong = tanpa papan).
@export var sign_text := ""
@export var sign_offset := Vector2(0, -34)
@export var cauldron_catalog: CraftingCatalog = preload("res://resources/witch/cauldron_catalog.tres")
@export var charm_catalog: CraftingCatalog = preload("res://resources/witch/charm_catalog.tres")

var _busy: Node


func _ready() -> void:
	set_meta("player_interaction", true)
	if not sign_text.is_empty():
		_add_sign()


func _add_sign() -> void:
	var label := Label.new()
	label.name = "Sign"
	label.text = sign_text
	label.add_theme_font_override("font", SIGN_FONT)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color("efe3ff"))
	label.add_theme_color_override("font_outline_color", Color("2a1840"))
	label.add_theme_constant_override("outline_size", 4)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.z_index = 20
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	label.size = label.get_minimum_size()
	label.position = sign_offset - Vector2(label.size.x * 0.5, label.size.y)


func interact(player: Player = null) -> void:
	if player == null:
		player = RoomDoor.player()
	if player == null or player.is_input_locked() or is_instance_valid(_busy):
		return
	if not Abilities.has(player.data, Abilities.MAGIC):
		Notify.say("Hanya penyihir yang lulus %s yang boleh memakai ini." % Abilities.title(Abilities.MAGIC))
		return
	match station:
		"cauldron":
			_open_recipes(player, cauldron_catalog, "Kuali Nyai Kenanga", "Masukkan bahan berurutan, aduk ke arah yang benar, angkat saat warnanya matang.")
		"charm":
			_open_recipes(player, charm_catalog, "Meja Jimat", "Telusuri rune pada kertas jimat dengan ujung tongkat sebelum tintanya kering.")
		"enchant":
			_enchant(player)


# ── Kuali & meja jimat ──────────────────────────────────────────────

func _open_recipes(player: Player, catalog: CraftingCatalog, title: String, subtitle: String) -> void:
	if catalog == null or catalog.recipes.is_empty():
		Notify.say(message)
		return
	var menu := RecipeMenu.new()
	menu.player = player
	menu.catalog = catalog
	menu.title = title
	menu.subtitle = subtitle
	menu.chosen.connect(_on_recipe_chosen.bind(player))
	_busy = menu
	Coop.ui_parent(player).add_child(menu)


func _on_recipe_chosen(recipe: CraftingRecipe, player: Player) -> void:
	if not is_instance_valid(player):
		return
	var check := CraftingSystem.preview(player.data, recipe)
	if not check["ok"]:
		Notify.say(check["message"])
		return
	if not _pay_attempt(player):
		return
	var game: Node
	if str(recipe.get("minigame")) == "rune":
		game = RuneGame.new()
		game.rune = str(recipe.get("rune"))
		game.time_limit = 16.0 - 2.0 * int(recipe.get("difficulty"))
		game.title = "Gambar Rune: %s" % check["output"].display_name
	else:
		game = BrewGame.new()
		game.recipe = recipe
		game.title = "Racik di Kuali: %s" % check["output"].display_name
	game.player = player
	game.finished.connect(_on_craft_finished.bind(player, recipe, game))
	_busy = game
	Coop.ui_parent(player).add_child(game)


func _on_craft_finished(success: bool, player: Player, recipe: CraftingRecipe, game: Node) -> void:
	if not is_instance_valid(player):
		return
	if success:
		var result := CraftingSystem.craft(player.data, recipe)
		Notify.say(result["message"])
		if result["ok"]:
			SkillSystem.gain(player.data, &"combat", 15)
		return
	if game.get("cancelled"):
		return
	_fail_cost(player, "Ramuan/jimat gagal. Bahan tidak terpakai.")


# ── Altar enchant ───────────────────────────────────────────────────

func _enchant(player: Player) -> void:
	var weapon := player.tool_controller.current_item
	if not Enchanting.can_enchant(weapon):
		Notify.say("Altar Enchant: pegang pedang, busur, atau tongkat sihir di hotbar, lalu sentuh altar untuk memilih pesona.")
		return
	# Daftar pesona memakai menu resep: "hasil" = senjata yang dipegang, judul = nama pesona.
	var catalog := CraftingCatalog.new()
	var titles: PackedStringArray = []
	var current := Enchanting.of(player.data, weapon)
	for enchant in Enchanting.all():
		var recipe := CraftingRecipe.new()
		recipe.recipe_id = str(enchant.get("id"))
		recipe.output_item_id = weapon.item_id
		recipe.ingredients = enchant.get("ingredients")
		recipe.set_meta("note", "%s Biaya %d G." % [enchant.get("description"), int(enchant.get("fee"))])
		catalog.recipes.append(recipe)
		titles.append("Pesona %s%s" % [enchant.get("display_name"), " (terpasang)" if current == enchant else ""])
	var menu := RecipeMenu.new()
	menu.player = player
	menu.catalog = catalog
	menu.row_titles = titles
	menu.title = "Altar Enchant: %s" % weapon.display_name
	menu.subtitle = "Pesona baru menggantikan efek status tier senjata ini. Rapal Urutan Mantra untuk memasangnya."
	menu.chosen.connect(func(recipe: CraftingRecipe) -> void:
		if is_instance_valid(player):
			_start_enchant(player, weapon, Enchanting.load_enchant(recipe.recipe_id)))
	_busy = menu
	Coop.ui_parent(player).add_child(menu)


func _start_enchant(player: Player, weapon: ItemData, enchant: Resource) -> void:
	var data := player.data
	for id in enchant.get("ingredients"):
		if data.get_item_count(String(id)) < int(enchant.get("ingredients")[id]):
			var item := GameState._resolve_item(String(id))
			Notify.say("Bahan kurang: %s." % (item.display_name if item != null else id))
			return
	if GameState.money < int(enchant.get("fee")):
		Notify.say("Uangmu belum cukup untuk pesona ini (%d G)." % int(enchant.get("fee")))
		return
	if not _pay_attempt(player):
		return
	var game := SequenceGame.new()
	game.player = player
	game.length = int(enchant.get("sequence_length"))
	game.title = "Urutan Mantra: Pesona %s" % enchant.get("display_name")
	game.finished.connect(_on_enchant_finished.bind(player, weapon, enchant, game))
	_busy = game
	Coop.ui_parent(player).add_child(game)


func _on_enchant_finished(success: bool, player: Player, weapon: ItemData, enchant: Resource, game: Node) -> void:
	if not is_instance_valid(player):
		return
	if not success:
		if not game.get("cancelled"):
			_fail_cost(player, "Mantra pesona buyar. Bahan dan biaya tidak terpakai.")
		return
	var data := player.data
	if not GameState.spend_money(int(enchant.get("fee"))):
		Notify.say("Uangmu belum cukup untuk pesona ini.")
		return
	for id in enchant.get("ingredients"):
		data.remove_item(String(id), int(enchant.get("ingredients")[id]))
	Enchanting.set_enchant(data, weapon.item_id, str(enchant.get("id")))
	SkillSystem.gain(data, &"combat", 25)
	Notify.say("%s kini berpesona %s! %s" % [weapon.display_name, enchant.get("display_name"), enchant.get("description")])


# ── Biaya percobaan ─────────────────────────────────────────────────

## Tiap percobaan memakan sedikit stamina; gagal memakan FAIL_STAMINA lagi.
func _pay_attempt(player: Player) -> bool:
	if player.data.stamina < ATTEMPT_STAMINA + FAIL_STAMINA:
		Notify.say("Kamu terlalu lelah untuk merapal sihir (butuh %d stamina)." % (ATTEMPT_STAMINA + FAIL_STAMINA))
		return false
	player.data.stamina -= ATTEMPT_STAMINA
	return true


func _fail_cost(player: Player, text: String) -> void:
	player.data.stamina -= FAIL_STAMINA
	Notify.say("%s -%d stamina." % [text, FAIL_STAMINA])
