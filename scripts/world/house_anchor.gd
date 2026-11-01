@tool
class_name HouseAnchor
extends Marker2D

## Titik di scene eksterior rumah: node farm `target_path` dipindah ke sini saat tingkat ini aktif
## (mis. ShippingBin agar tidak tertutup rumah yang lebih lebar). Geser marker ini di editor.

## Path node relatif terhadap root farm, mis. ShippingBin atau NPCPoints/shipping_pickup.
@export var target_path: NodePath
