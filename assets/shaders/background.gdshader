shader_type canvas_item;

void fragment() {
	vec2 uv = UV;
	vec2 top_delta = (uv - vec2(0.5, 0.28)) / vec2(0.52, 0.42);
	vec2 bottom_delta = (uv - vec2(0.5, 0.88)) / vec2(0.38, 0.30);
	float top_glow = 1.0 - smoothstep(0.0, 0.76, length(top_delta));
	float bottom_glow = 1.0 - smoothstep(0.0, 0.80, length(bottom_delta));
	vec3 color = vec3(0.0314, 0.0510, 0.1059);
	color += vec3(0.204, 0.325, 0.569) * top_glow * 0.29;
	color += vec3(0.141, 0.224, 0.396) * bottom_glow * 0.15;
	COLOR = vec4(color, 1.0);
}
