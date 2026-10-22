extends Node

func _ready() -> void:
	if OS.get_environment("NUSA_SAVE_AUDIT") != "1":
		get_tree().quit(2)
		return
	DayCycle.is_running = false
	var hints: ActionHints = $Hints
	hints.set_process(false)
	var prompts: Array[Dictionary] = [
		{"key": "E", "label": "Interaksi"},
		{"key": "Spasi", "label": "Lompat"},
		{"key": "Klik kiri", "label": "Alat"},
		{"key": "Shift", "label": "Lari"},
	]
	hints._rebuild(prompts)
	hints.show()
	Notify.say("Resep baru dipelajari: Pancakes!")
	Notify.say("Barang berhasil disimpan ke peti bersama.")
	Notify.say("Bahan bangunan belum lengkap. Siapkan kayu dan batu terlebih dahulu.")
	for frame in 12:
		await get_tree().process_frame
	hints.layout_for_viewport()
	RenderingServer.force_draw()
	get_viewport().get_texture().get_image().save_png("res://scratch/hud-feedback-preview.png")
	print("HUD FEEDBACK PREVIEW COMPLETE")
	get_tree().quit()
