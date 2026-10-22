# Wira dan Ubay

Wira tinggal di rumah carpenter Hill (pintu ganda, interaksi di depan rumah).
Ubay tinggal di rumah abu-abu Town dekat warung, dengan pos paket di sebelahnya.
Keduanya mempunyai interior, tempat tidur, meja, dan area kerja.

Jadwal, kecepatan, nama, dan tampilan bisa diatur lewat resource
`resources/npc_data/characters/wira_resident.tres` dan `ubay_resident.tres`.
Data dialog/sosial tetap ada di JSON. Lihat `docs/npc-inspector-guide.md`.
Sarapan dan tidur memakai map interior `wira_home`
dan `ubay_home`. Jadwal kerja tetap mengikuti Hill, Town, dan Farm.

`NPCDatabase` membaca profil dan JSON saat game dimulai. `NPCMapPresenter` pada setiap
map mencocokkan waktu dan cuaca dengan jadwal, lalu membuat/menghapus actor
sesuai map aktif. Actor masuk dari pintu rumah atau batas map lalu mengikuti
waypoint menuju aktivitas. Saat pindah map, actor berjalan ke pintu/batas map
sebelum dihapus. Perubahan titik di map juga mengikuti rute jalan. Presenter juga
memperbarui jadwal ketika cuaca berubah. Kedua pemain co-op dapat berada di
map berbeda; actor mengikuti jadwal yang sama pada setiap map.

Marker dapat dipindahkan langsung melalui `NPCPoints` di editor. `NPCActors`
menampung actor runtime. Scene WiraNPC dan UbayNPC tetap tersedia untuk preview;
jangan tambahkan actor statis lagi pada map yang memakai presenter.

`NPCPaths` memakai scene di `scenes/npc/routes/`. Edit titik Curve pada Path2D
bernama Wira atau Ubay langsung dari map (Editable Children aktif).
Setiap NPC mempunyai kurva sendiri, disaring lewat Npc Id. Destination Maps
pada Marker2D hanya mengatur pintu masuk/keluar map. Rute terpendek dihitung
di kurva milik NPC terkait, termasuk jalan memutari rumah, jembatan, serta tangga.
Gerakan berhenti saat diajak bicara dan dilanjutkan setelah UI ditutup.
NPC yang terhalang tidak memakai fallback teleport.

`tests/npc_paths_regression.tscn` menguji gerak nyata terhadap collision map,
rute antaraktivitas, pintu masuk/keluar, dan penghapusan setelah mencapai keluar.

Wira menyediakan Bicara dan menu Bangun / Upgrade yang sudah ada. Menu tersebut
memakai sistem konstruksi proyek saat ini; perubahan ini tidak menambahkan
katalog furnitur atau sistem romance baru. Metadata romanceable Ubay disimpan
di JSON untuk sistem sosial berikutnya.

Kunjungan Ubay ke shipping bin berlangsung 17.00–17.30, termasuk saat hujan.
Penjualan tetap diproses oleh ShippingManager saat tidur. Presenter dan actor
tidak pernah memanggil settle, sehingga kunjungan tidak bisa menjual barang
dua kali. Info Pengiriman menjelaskan aturan ini kepada pemain.

Jalankan `res://tests/residents_regression.tscn` untuk memeriksa marker,
animasi, perpindahan map (termasuk 17.00/17.30 dan tengah malam), cuaca,
dialog, layanan, dan bahwa kunjungan NPC tidak mengubah antrean penjualan.
