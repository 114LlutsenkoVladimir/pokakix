shader_type canvas_item;

uniform sampler2D mask_texture : filter_nearest, repeat_disable;

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);
    vec4 mask_color = texture(mask_texture, UV);

    // Если красный канал маски больше 0.5 — пиксель полностью видим (1.0), иначе прозрачен (0.0)
    float cutoff_mask = step(0.5, mask_color.r);

    tex_color.a *= cutoff_mask;
    COLOR = tex_color;
}