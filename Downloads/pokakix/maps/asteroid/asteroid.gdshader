shader_type canvas_item;
uniform sampler2D mask_tex;

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);
    float mask_value = texture(mask_tex, UV).r;
    
    // МЫ ИСПОЛЬЗУЕМ СТРОГОЕ УСЛОВИЕ
    // Удаляем только если маска явно белая (значение > 0.9)
    // Черный фон (0.0) и серые артефакты (до 0.8) игнорируются
    if (mask_value > 0.5) {
        discard;
    }
    
    COLOR = tex_color;
}