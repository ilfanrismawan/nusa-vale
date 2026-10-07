extends StaticBody2D

## Objek yang menampilkan pesan saat pemain menekan tombol interaksi
## (papan tulis, rak buku, loker, dll). Dipanggil oleh Player._find_interactable().

@export_multiline var message: String = ""

func interact() -> void:
	if not message.is_empty():
		Notify.say(message)
