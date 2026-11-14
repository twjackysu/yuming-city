shader_type spatial;
// 腐敗之森的地面：一大片平面，顏色照世界座標用雜訊混——暗土、苔、發紫的腐葉，路與空地是比較亮的土，
// 邊緣是不規則的（不是一條直線），近處灑一些落葉。全部用算的，沒有貼圖。
// moss 跟 tools/blender/tripo_prop.py 的 MOSS 同一個顏色：樹的模型自帶的土丘改塗成它，才會跟地面接起來。

uniform vec3 soil : source_color = vec3(0.15, 0.12, 0.18);
uniform vec3 moss : source_color = vec3(0.12, 0.22, 0.18);
uniform vec3 rot : source_color = vec3(0.25, 0.15, 0.31);
uniform vec3 dirt : source_color = vec3(0.37, 0.3, 0.3);
uniform float path_half_width = 2.6;
uniform float path_z_from = -15.0;   // 路沿著 x＝0，從這裡（空地）往 +z 一直到出生點後面
uniform vec2 glade_center = vec2(0.0, -15.0);
uniform float glade_radius = 8.0;
// 樹腳下長苔：關卡把每棵樹的位置畫成一張小圖（R＝離樹多近），這裡照它把地面換成苔
uniform sampler2D moss_mask : hint_default_black, filter_linear, repeat_disable;
uniform float ground_size = 140.0;

varying vec3 world_pos;

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

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	float patches = fbm(p * 0.16);
	float grain = fbm(p * 1.3 + 31.0);
	float near_tree = texture(moss_mask, p / ground_size + 0.5).r;
	float mossy = max(smoothstep(0.36, 0.48, patches), smoothstep(0.3, 0.55, near_tree + (patches - 0.45) * 0.8));
	vec3 col = mix(soil, moss, mossy);
	col = mix(col, rot, smoothstep(0.58, 0.7, fbm(p * 0.1 + 43.0)) * 0.7 * (1.0 - near_tree));
	// 路與空地：邊緣跟著雜訊走
	float wobble = (fbm(p * 0.3 + 7.0) - 0.5) * 3.0;
	float on_path = (1.0 - smoothstep(-0.5, 0.7, abs(p.x + wobble * 0.5) - path_half_width - wobble * 0.4)) * smoothstep(path_z_from - 2.0, path_z_from + 2.0, p.y);
	float on_glade = 1.0 - smoothstep(-1.2, 0.8, length(p - glade_center) - glade_radius - wobble);
	float bare = max(on_path, on_glade);
	col = mix(col, dirt, bare * (0.75 + 0.25 * grain));
	col *= 0.78 + 0.44 * grain;
	// 落葉：每格一片，位置、大小、顏色照格子的亂數；路上少一點；遠處不畫（會閃）
	float near = 1.0 - smoothstep(14.0, 26.0, length(VERTEX));
	vec2 cell = floor(p * 2.4);
	vec2 in_cell = fract(p * 2.4) - 0.5;
	float pick = hash(cell + 3.7);
	vec2 offset = (vec2(hash(cell + 9.1), hash(cell + 21.3)) - 0.5) * 0.6;
	float turn = pick * 6.283;
	vec2 q = mat2(vec2(cos(turn), -sin(turn)), vec2(sin(turn), cos(turn))) * (in_cell - offset);
	float leaf = 1.0 - smoothstep(0.6, 1.0, length(q * vec2(5.0, 11.0)));
	leaf *= step(mix(0.62, 0.86, bare), pick) * near;
	vec3 leaf_col = mix(vec3(0.42, 0.27, 0.12), vec3(0.36, 0.17, 0.42), step(0.5, hash(cell + 55.5)));
	col = mix(col, leaf_col, leaf * 0.85);
	ALBEDO = col;
	ROUGHNESS = 1.0;
	SPECULAR = 0.1;
}
