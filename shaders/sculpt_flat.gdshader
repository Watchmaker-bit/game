shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Белая «глина» с плоскими нормалями: каждая грань освещается отдельно,
// поэтому сетка и работа кистей по вершинам видны как в Blender.
uniform vec4 albedo : source_color = vec4(0.48, 0.48, 0.49, 1.0);
uniform float roughness : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	// NORMAL в Godot — в пространстве вида и смотрит на камеру (+Z).
	vec3 face_normal = normalize(cross(dFdy(VERTEX), dFdx(VERTEX)));
	if (!FRONT_FACING) {
		face_normal = -face_normal;
	}
	NORMAL = face_normal;
	ALBEDO = albedo.rgb;
	ROUGHNESS = roughness;
	SPECULAR = 0.0;
}
