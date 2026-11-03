extends CraftingRecipe

## Resep Menara Penyihir (kuali & meja jimat). Bahan dikonsumsi lewat CraftingSystem setelah
## mini game berhasil; gagal = bahan utuh, stamina terpakai (lihat witch_station.gd).
## Urutan kunci `ingredients` = urutan bahan dimasukkan ke kuali.

## "brew" = Racik di Kuali, "rune" = Gambar Rune.
@export_enum("brew", "rune") var minigame := "brew"
## Racik: arah aduk (true = searah jarum jam) dan jumlah putaran.
@export var stir_clockwise := true
@export_range(1, 6) var stir_turns := 2
## Racik: warna ramuan matang (target saat mengangkat kuali).
@export var brew_color := Color(0.5, 0.9, 0.6)
## Rune: bentuk di RuneTraceGame.RUNES.
@export var rune := "charm"
## 1 = mudah .. 3 = sulit (zona angkat lebih sempit / waktu rune lebih singkat).
@export_range(1, 3) var difficulty := 1
## Teks singkat di daftar resep.
@export var note := ""
