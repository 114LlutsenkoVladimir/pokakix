shader_type canvas_item;

uniform sampler2D mask_tex;
uniform float cut = 0.99; // чем выше, тем жестче

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	float m = texture(mask_tex, UV).r;

	// бинарная маска (жёсткий контур взрыва)
	m = (m >= cut) ? 1.0 : 0.0;

	base.a *= m;
	COLOR = base;
}
