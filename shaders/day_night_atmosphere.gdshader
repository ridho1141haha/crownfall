shader_type canvas_item;

uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 0.0);
uniform float vignette_strength : hint_range(0.0, 0.8) = 0.22;

void fragment() {
	vec2 centered = UV - vec2(0.5);
	float dist = length(centered) * 1.4142;
	float vig = smoothstep(0.45, 1.15, dist) * vignette_strength;
	vec3 col = mix(tint_color.rgb, vec3(0.03, 0.04, 0.08), vig);
	float alpha = clamp(tint_color.a + vig * 0.85, 0.0, 0.72);
	COLOR = vec4(col, alpha);
}
