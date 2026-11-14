shader_type canvas_item;

uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 0.92, 0.88, 1.0);

void fragment() {
	vec4 tex = texture(TEXTURE, UV) * COLOR;
	vec3 out_rgb = mix(tex.rgb, flash_color.rgb, flash_amount);
	COLOR = vec4(out_rgb, tex.a);
}
