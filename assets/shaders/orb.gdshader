shader_type canvas_item;
render_mode blend_mix;

uniform float time = 0.0;
uniform float activity = 0.0;

void fragment() {
	vec2 p = (UV - vec2(0.5)) * 2.0;
	float distance_from_center = length(p);
	float sphere_radius = 0.72;
	float edge = 1.0 - smoothstep(sphere_radius - 0.008, sphere_radius + 0.008, distance_from_center);
	float halo_distance = max(distance_from_center - sphere_radius, 0.0);
	float halo = exp(-halo_distance * 9.0) * (1.0 - smoothstep(sphere_radius, 1.0, distance_from_center));

	vec2 surface = p / sphere_radius;
	float surface_distance = dot(surface, surface);
	vec3 normal = normalize(vec3(surface.x, -surface.y, sqrt(max(1.0 - surface_distance, 0.0))));
	vec3 light_direction = normalize(vec3(-0.48, 0.58, 0.68));
	float diffuse = max(dot(normal, light_direction), 0.0);
	float specular = pow(max(dot(reflect(-light_direction, normal), vec3(0.0, 0.0, 1.0)), 0.0), 24.0);

	vec3 deep_blue = vec3(0.055, 0.065, 0.18);
	vec3 bright_blue = vec3(0.25, 0.38, 0.78);
	vec3 color = mix(deep_blue, bright_blue, 0.22 + diffuse * 0.68);
	float highlight = exp(-dot(p - vec2(-0.32, -0.34), p - vec2(-0.32, -0.34)) * 30.0);
	float secondary_glow = exp(-dot(p - vec2(0.36, 0.38), p - vec2(0.36, 0.38)) * 13.0);
	color += vec3(0.48, 0.66, 0.94) * highlight * 0.42;
	color += vec3(0.18, 0.13, 0.52) * secondary_glow * 0.35;
	color += vec3(0.42, 0.58, 1.0) * specular * 0.52;
	float rim = pow(1.0 - normal.z, 3.0);
	color += vec3(0.22, 0.36, 0.82) * rim * 0.36;

	float breathe = 0.97 + 0.03 * sin(time * 2.0);
	float alpha = max(edge, halo * (0.25 + activity * 0.18));
	color *= breathe + activity * 0.06;
	COLOR = vec4(color, alpha);
}
