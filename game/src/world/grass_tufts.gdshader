shader_type spatial;
// 草叢（GrassTufts）：葉片根部暗、尖端亮，尖端跟著風慢慢搖。法線一律朝上：跟地面吃一樣的光，不會一片亮一片黑。
render_mode cull_disabled, shadows_disabled;

uniform vec3 root_color : source_color = vec3(0.07, 0.13, 0.14);
uniform vec3 tip_color : source_color = vec3(0.2, 0.42, 0.4);
uniform vec3 tip_color_alt : source_color = vec3(0.42, 0.26, 0.56);   // 少數幾叢發紫

varying float alt;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float sway = sin(TIME * 1.1 + world.x * 0.6 + world.z * 0.8) * 0.06 + sin(TIME * 2.3 + world.z * 1.7) * 0.02;
	VERTEX.x += sway * UV.y * UV.y;
	alt = INSTANCE_CUSTOM.r;
}

void fragment() {
	vec3 tip = mix(tip_color, tip_color_alt, step(0.86, alt));
	ALBEDO = mix(root_color, tip, UV.y * UV.y) * (0.8 + 0.4 * alt);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
}
