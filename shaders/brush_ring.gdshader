shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;

// Кольцо-курсор кисти. Рисуется на плоскости, которую мы ориентируем
// по нормали к поверхности в скрипте main.gd.
uniform vec4 ring_color : source_color = vec4(0.95, 0.56, 0.22, 0.92);

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float aa = max(fwidth(r), 0.001);
	float ring = 1.0 - smoothstep(0.035, 0.035 + aa * 2.0, abs(r - 0.92));
	float fill = max(1.0 - smoothstep(0.0, 0.92, r), 0.0) * 0.07;
	ALBEDO = ring_color.rgb;
	ALPHA = clamp(ring + fill, 0.0, 1.0) * ring_color.a;
}
