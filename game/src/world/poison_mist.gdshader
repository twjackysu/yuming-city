shader_type spatial;
// 毒霧（新版）：貼地的幾層圓盤，綠色、往外淡、慢慢流動。
// 邊界：原本是一圈正圓的亮線（看起來像地上畫的圈，跟噴毒前兆的圈分不出來）；
// 改成用雜訊往裡外咬的不規則邊，邊上一道淡淡的、跟著雜訊走的亮緣——還是看得出在哪裡進出，但是一團霧的邊，不是一條線。
// 面片比毒霧的範圍大一圈（overscan），咬出去的地方不會被面片切出硬邊。
// 不受光（自己發一點光），景深接近牆／地面時淡掉（不會切出硬邊）。
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec3 mist_color : source_color = vec3(0.42, 0.78, 0.30);
uniform vec3 edge_color : source_color = vec3(0.70, 1.0, 0.55);
uniform float density = 0.42;
uniform float edge_strength = 0.3;
uniform float edge_bite = 0.2;   // 雜訊把邊界往裡外推多少（佔半徑的比例，±一半）
uniform float overscan = 1.0;    // 面片邊長 ÷ 毒霧直徑
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
	vec2 c = (UV * 2.0 - 1.0) * overscan;   // 圓盤中心 0、毒霧的邊界 1
	float r = length(c);
	if (r > overscan) { discard; }
	vec2 flow = vec2(TIME * flow_speed, -TIME * flow_speed * 0.7) * (1.0 + layer * 0.6);
	float n = fbm(c * 2.6 + flow + layer * 3.1);
	// 邊界用另一組比較大塊的雜訊往裡外咬（每層錯開一點）
	float bite = (fbm(c * 1.7 - flow * 0.8 + 11.3 + layer * 1.7) - 0.5) * edge_bite * 2.0;
	float rr = r - bite;
	float body = smoothstep(1.0, 0.55, rr) * (0.45 + 0.75 * n) * density * (1.0 - layer * 0.35);
	// 貼地那層：邊界上一道跟著雜訊走的淡亮緣
	float edge = (1.0 - smoothstep(0.95, 1.03, rr)) * smoothstep(0.82, 0.95, rr) * edge_strength * (0.5 + 0.8 * n) * (1.0 - step(0.01, layer));
	// 跟地面、牆的交界淡掉
	float scene_depth = texture(depth_tex, SCREEN_UV).r;
	vec4 ndc = vec4(SCREEN_UV * 2.0 - 1.0, scene_depth, 1.0);
	vec4 view = INV_PROJECTION_MATRIX * ndc;
	float soft = clamp(VERTEX.z - view.z / view.w, 0.0, 1.0);
	ALBEDO = mix(mist_color, edge_color, clamp(edge * 1.6, 0.0, 1.0));
	EMISSION = ALBEDO * 0.35;
	// 面片的邊（r 接近 overscan）一定淡到 0
	float mesh_edge = 1.0 - smoothstep(overscan - 0.04, overscan, r);
	ALPHA = clamp((body + edge) * fade, 0.0, 0.85) * clamp(soft * 3.0, 0.0, 1.0) * mesh_edge;
}
