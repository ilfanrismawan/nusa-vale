shader_type canvas_item;

// Goyangan pelan tanaman/bunga: pangkal diam, puncak bergeser per piksel penuh (tetap tajam).
// Sprite harus berpijak di y = 0 lokal (offset ke atas), seperti dekorasi builder.
uniform float amount = 1.5;
uniform float speed = 1.4;
// Tinggi (piksel) tempat goyangan mencapai penuh.
uniform float sway_height = 24.0;

void vertex() {
	float origin_x = MODEL_MATRIX[3].x;
	float weight = clamp(-VERTEX.y / sway_height, 0.0, 1.0);
	VERTEX.x += round(sin(TIME * speed + origin_x * 0.07) * amount * weight);
}
