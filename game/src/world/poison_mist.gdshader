shader_type spatial;
// 毒霧（新版，D-202）：貼地的幾層圓盤，綠色、往外淡、慢慢流動；邊界一圈淡亮線讓人看得出在哪裡進出。
// 不受光（自己發一點光），景深接近牆／地面時淡掉（不會切出硬邊）。
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec3 mist_color : source_color = vec3(0.42, 0.78, 0.30);
uniform vec3 edge_color : source_color = vec3(0.70, 1.0, 0.55);
uniform float density = 0.42;
uniform float edge_width = 0.05;
uniform float edge_strength = 0.55;
uniform float layer = 0.0;     // 0＝貼地那層（最濃），越上層越淡
uniform float flow_speed = 0.06;
uniform float fade = 1.0;      // 1＝滿，0＝散掉（守衛噴的霧）
uniform sampler2D depth_tex : hint_depth_texture, filter_linear;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), u.x), u.y);
}
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) { v += a * noise(p); p *= 2.03; a *= 0.5; }
	return v;
}

void fragment() {
	vec2 c = UV * 2.0 - 1.0;          // 圓盤中心 0、邊緣 1
	float r = length(c);
	if (r > 1.0) { discard; }
	vec2 flow = vec2(TIME * flow_speed, -TIME * flow_speed * 0.7) * (1.0 + layer * 0.6);
	float n = fbm(c * 2.6 + flow + layer * 3.1);
	float body = smoothstep(1.0, 0.55, r) * (0.45 + 0.75 * n) * density * (1.0 - layer * 0.35);
	float edge = (1.0 - smoothstep(0.0, edge_width, abs(r - (1.0 - edge_width)))) * edge_strength * (1.0 - step(0.01, layer));  // 只有貼地那層畫邊界
	// 跟地面、牆的交界淡掉
	float scene_depth = texture(depth_tex, SCREEN_UV).r;
	vec4 ndc = vec4(SCREEN_UV * 2.0 - 1.0, scene_depth, 1.0);
	vec4 view = INV_PROJECTION_MATRIX * ndc;
	float soft = clamp(VERTEX.z - view.z / view.w, 0.0, 1.0);
	ALBEDO = mix(mist_color, edge_color, clamp(edge * 1.4, 0.0, 1.0));
	EMISSION = ALBEDO * 0.35;
	ALPHA = clamp((body + edge) * fade, 0.0, 0.85) * clamp(soft * 3.0, 0.0, 1.0);
}
