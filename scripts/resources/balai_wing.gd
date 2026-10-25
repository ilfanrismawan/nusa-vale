class_name BalaiWing
extends Resource

## Satu sayap Balai Nadi (GDD 4.9). Sayap lengkap bila semua paket ber-wing_id sama selesai.
## Bonus permanen dibaca SkillSystem.stat/household lewat BalaiNadiManager.wing_stat().
@export var wing_id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
## Kunci stat (lihat SkillSystem) -> nilai yang ditambahkan selama sayap lengkap.
@export var effects: Dictionary[StringName, float] = {}
## Teks bonus untuk UI dan Notify, Bahasa Indonesia.
@export var bonus_text: String = ""
@export var reward_tokens: int = 2
@export var completion_flag: String = ""
@export_multiline var completion_message: String = "Sayap ini kembali hidup."
