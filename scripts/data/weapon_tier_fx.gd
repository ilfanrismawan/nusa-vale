class_name WeaponTierFx
extends Resource

## Identitas visual dan suara satu tier bahan senjata (Kayu..Obsidian), dipakai pedang, busur,
## dan tongkat sihir. Makin tinggi tier, makin banyak partikel, jejak makin panjang, dan
## lapisan suara makin tebal, supaya senjata hasil upgrade terasa lebih megah.
## Grup "Efek status" adalah satu-satunya bagian gameplay (GDD 8.2, v3.3): tier tinggi
## membakar, mendinginkan, menyerap HP, atau memulihkan stamina tempur saat pukulan masuk.
## Angka serangan tetap di ItemData dan WeaponStyle.
## File: resources/combat/tier_fx/<tier>.tres, dimuat WeaponTierFx.for_tier().

const DIR := "res://resources/combat/tier_fx/"
const TIER_FILES := ["wood", "copper", "iron", "gold", "platinum", "crimson", "frost", "shadow", "fairy", "obsidian"]

## Bentuk partikel khas tier.
## SPARKS = percikan jatuh, GLITTER = kilau berkelip, EMBERS = bara naik, FROST = serpih es,
## SHADOW = asap gelap naik pelan, FAIRY = debu peri melayang, DARK_FIRE = api gelap + bara.
enum Motif { DUST, SPARKS, GLITTER, EMBERS, FROST, SHADOW, FAIRY, DARK_FIRE }
## Efek gameplay saat pukulan masuk (Combat.apply_tier_status).
## BURN = terbakar (damage berkala), CHILL = dingin (gerak dan ancang-ancang melambat),
## LIFESTEAL = pemain pulih HP, STAMINA = pemain pulih stamina tempur,
## DARK_FIRE = terbakar kuat + DEF musuh turun selama terbakar.
enum Status { NONE, BURN, CHILL, LIFESTEAL, STAMINA, DARK_FIRE }

@export var display_name: String = "Kayu"
@export var motif: Motif = Motif.DUST

@export_group("Warna")
@export var color: Color = Color(0.9, 0.8, 0.6)
@export var color_alt: Color = Color(1, 1, 1)
## Warna cahaya lembut (halo proyektil, pinggir tebasan, bola bidik).
@export var glow: Color = Color(1, 0.9, 0.7, 0.0)

@export_group("Jejak dan proyektil")
## Panjang ekor proyektil (jumlah titik).
@export_range(4, 24) var trail_points: int = 6
@export_range(0.5, 3.0, 0.05) var trail_width_scale: float = 1.0
## Partikel per detik yang ditinggalkan proyektil saat terbang. 0 = tidak ada.
@export_range(0, 80) var flight_particles: int = 0
## Jari-jari halo cahaya di sekitar proyektil (0 = tanpa halo).
@export_range(0.0, 12.0, 0.5) var halo_radius: float = 0.0

@export_group("Tebasan")
## Ketebalan busur tebasan pedang dikali angka ini.
@export_range(0.5, 3.0, 0.05) var slash_width_scale: float = 1.0
## Busur kedua yang lebih lebar dan pudar di belakang tebasan (tier tinggi).
@export var slash_echo: bool = false
## Partikel yang tercecer sepanjang busur tebasan.
@export_range(0, 24) var slash_particles: int = 0

@export_group("Benturan")
@export_range(0, 48) var hit_particles: int = 6
## Cincin kejut saat kena (0 = tidak ada).
@export_range(0.0, 32.0) var hit_ring: float = 0.0
## Tambahan guncangan kamera (piksel) dan hitstop (ms) di atas angka damage.
@export_range(0.0, 3.0, 0.1) var shake_bonus: float = 0.0
@export_range(0, 60) var hitstop_bonus_ms: int = 0
## Lapisan suara benturan dari assets/audio/sfx/kenney_impact (tanpa .ogg), dimainkan bersamaan.
@export var impact_layers: PackedStringArray = PackedStringArray(["impactWood_medium_000"])
@export_range(-24.0, 6.0, 0.5) var impact_volume_db: float = -8.0
@export_range(-12.0, 12.0, 0.5) var impact_semitones: float = 0.0

@export_group("Bidik dan tembakan")
## Butir cahaya yang berputar di ujung busur/tongkat saat membidik.
@export_range(0, 12) var aim_motes: int = 0
## Nada denting saat bidikan penuh (semitone dari nada dasar). Lebih banyak = akor lebih megah.
@export var chime_notes: PackedInt32Array = PackedInt32Array([0])
## Kilatan moncong saat menembak/menebas dikali angka ini.
@export_range(0.5, 3.0, 0.05) var muzzle_scale: float = 1.0
## Tier tertinggi: dentuman bass saat tembakan/benturan berat.
@export var bass_boom: bool = false

@export_group("Efek status")
@export var status: Status = Status.NONE
## Peluang efek per pukulan yang masuk (LIFESTEAL/STAMINA biasanya 1 = selalu).
@export_range(0.0, 1.0, 0.05) var status_chance: float = 0.0
@export_range(0.0, 10.0, 0.1) var status_duration: float = 0.0
## Terbakar: damage per tick = ATK pukulan x angka ini (minimal 1), tiap burn_interval detik.
@export_range(0.0, 1.0, 0.01) var burn_tick_ratio: float = 0.1
@export_range(0.1, 2.0, 0.05) var burn_interval: float = 0.5
## Dingin: kecepatan gerak musuh dikali angka ini.
@export_range(0.1, 1.0, 0.05) var slow_scale: float = 1.0
## Serap HP: HP pemain pulih = ATK pukulan x angka ini (minimal 1).
@export_range(0.0, 1.0, 0.01) var lifesteal_ratio: float = 0.0
## Stamina tempur yang pulih tiap pukulan masuk.
@export_range(0, 50) var stamina_gain: int = 0
## DEF musuh dikali angka ini selama efek aktif (Api Gelap).
@export_range(0.0, 1.0, 0.05) var defense_scale: float = 1.0

static var _cache: Dictionary = {}

## Efek untuk tier (ToolData.ToolTier). Tier di luar batas memakai yang terdekat.
static func for_tier(tier: int) -> WeaponTierFx:
	tier = clampi(tier, 0, TIER_FILES.size() - 1)
	if _cache.has(tier):
		return _cache[tier]
	var path: String = DIR + TIER_FILES[tier] + ".tres"
	var fx: WeaponTierFx = load(path) as WeaponTierFx if ResourceLoader.exists(path) else null
	if fx == null:
		push_warning("WeaponTierFx: %s tidak ditemukan; memakai efek dasar." % path)
		fx = WeaponTierFx.new()
	_cache[tier] = fx
	return fx

## Efek senjata yang dipegang (ItemData.equipment_tier). null = efek dasar Kayu.
static func for_item(item: ItemData) -> WeaponTierFx:
	return for_tier(int(item.equipment_tier) if item != null else 0)

## Satu angka 0..1 untuk eskalasi berkelanjutan (Kayu = 0, Obsidian = 1).
static func tier_ratio(tier: int) -> float:
	return clampf(float(tier) / float(TIER_FILES.size() - 1), 0.0, 1.0)

## Arah gravitasi partikel motif: positif jatuh, negatif naik.
func particle_gravity() -> float:
	match motif:
		Motif.SPARKS:
			return 180.0
		Motif.GLITTER:
			return 30.0
		Motif.EMBERS, Motif.DARK_FIRE:
			return -70.0
		Motif.FROST:
			return 90.0
		Motif.SHADOW:
			return -35.0
		Motif.FAIRY:
			return -15.0
	return 120.0

func particle_speed() -> float:
	match motif:
		Motif.SPARKS:
			return 95.0
		Motif.SHADOW, Motif.FAIRY:
			return 30.0
		Motif.DARK_FIRE:
			return 80.0
	return 60.0

func particle_size() -> int:
	match motif:
		Motif.SHADOW, Motif.DARK_FIRE:
			return 3
		Motif.DUST, Motif.SPARKS:
			return 1
	return 2

func particle_lifetime() -> float:
	match motif:
		Motif.SHADOW, Motif.FAIRY:
			return 0.7
		Motif.EMBERS, Motif.DARK_FIRE, Motif.GLITTER:
			return 0.55
	return 0.35

func has_status() -> bool:
	return status != Status.NONE

## Nama efek untuk teks di atas musuh/pemain dan GDD.
func status_name() -> String:
	match status:
		Status.BURN:
			return "Terbakar"
		Status.CHILL:
			return "Dingin"
		Status.LIFESTEAL:
			return "Serap Jiwa"
		Status.STAMINA:
			return "Berkah Peri"
		Status.DARK_FIRE:
			return "Api Gelap"
	return ""
