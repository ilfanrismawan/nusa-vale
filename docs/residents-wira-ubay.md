# Wira dan Ubay

Wira tinggal di rumah carpenter Hill (pintu ganda, interaksi di depan rumah).
Ubay tinggal di rumah abu-abu Town dekat warung, dengan pos paket di sebelahnya.
Keduanya mempunyai interior, tempat tidur, meja, dan area kerja.

Data dialog, identitas, kecepatan, layanan, dan jadwal ada di `data/npc/wira.json`
dan `data/npc/ubay.json`. Sarapan dan tidur memakai map interior `wira_home`
dan `ubay_home`. Jadwal kerja tetap mengikuti Hill, Town, dan Farm.

`NPCDatabase` membaca JSON saat game dimulai. `NPCMapPresenter` pada setiap
map mencocokkan waktu dan cuaca dengan jadwal, lalu membuat/menghapus actor
sesuai map aktif. Actor baru langsung berada di marker saat map dimuat;
perubahan titik dalam map menggunakan gerakan VillageNPC. Presenter juga
memperbarui jadwal ketika cuaca berubah. Kedua pemain co-op dapat berada di
map berbeda; actor mengikuti jadwal yang sama pada setiap map.

Marker dapat dipindahkan langsung melalui `NPCPoints` di editor. `NPCActors`
menampung actor runtime. Scene WiraNPC dan UbayNPC tetap tersedia untuk preview;
jangan tambahkan actor statis lagi pada map yang memakai presenter.

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
