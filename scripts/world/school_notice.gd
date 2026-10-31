extends StaticBody2D

## Objek yang menampilkan pesan saat pemain menekan tombol interaksi
## (papan tulis, rak buku, loker, dll). Dipanggil oleh Player._find_interactable().

## "{hours}" di pesan diganti jam buka `service` (ServiceHours), mis. papan jam warung.
@export_multiline var message: String = ""
@export var service := ""

func interact() -> void:
	if not message.is_empty():
		Notify.say(message.replace("{hours}", ServiceHours.hours_text(service)))
