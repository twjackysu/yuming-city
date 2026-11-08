shader_type spatial;
// 積雪（D-068）：街邊雪帶、屋頂、井沿、鐘樓尖頂。取代原本一整片平的淺色。
// 全部用世界座標（合併後的幾何不靠 UV）：
// - 大片的起伏（被風吹成的雪堆）：亮暗 ±、低處偏藍；法線跟著起伏微微傾斜，路燈斜照時看得出凹凸
// - 髒雪：靠近 y=0 的雪帶（街邊）有幾塊被踩過的灰色
// - 雪粒閃點：很小的格子裡偶爾一顆，只在特定角度亮（看的角度一變就換一顆），遠處淡掉避免閃爍

uniform vec3 snow_color : source_color = vec3(0.66, 0.71, 0.78);
uniform vec3 shadow_tint : source_color = vec3(0.5, 0.58, 0.72);
uniform vec3 dirt_color : source_color = vec3(0.34, 0.35, 0.38);
uniform float drift_scale = 0.55;
uniform float bump_strength = 0.35;
uniform float sparkle_density = 0.012;
uniform float sparkle_energy = 1.6;
// 雪堆的邊緣（D-119）：SnowMound 的 UV2.x 是圈數（0＝最高點、1＝外圈；其他雪沒有 UV2，合併時補 0＝不變薄），
// 外圈的雪薄，漸漸透出底下的暗色（屋瓦、石板），雪堆不再是一塊發亮的白板。
uniform vec3 under_color : source_color = vec3(0.13, 0.14, 0.17);
uniform float edge_start = 0.5;

varying vec3 world_pos;
varying vec3 world_normal;
varying float mound_k;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p *= 2.07;
		a *= 0.5;
	}
	return v;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	mound_k = UV2.x;
}

void fragment() {
	// 依法線選投影面：朝上（屋頂、雪帶頂面）用 xz，側面用 xy／zy
	vec3 an = abs(world_normal);
	vec2 p = an.y > 0.5 ? world_pos.xz : (an.x > an.z ? world_pos.zy : world_pos.xy);
	float h = fbm(p * drift_scale);
	float e = 0.06;
	float hx = fbm((p + vec2(e, 0.0)) * drift_scale);
	float hy = fbm((p + vec2(0.0, e)) * drift_scale);
	vec2 grad = vec2(hx - h, hy - h) / e;

	vec3 col = snow_color * mix(0.86, 1.08, h);
	// 低處（雪堆之間）偏藍、暗一點
	col = mix(col * shadow_tint * 1.3, col, 0.35 + 0.65 * smoothstep(0.25, 0.6, h));
	// 街邊雪帶（貼地）被踩髒的幾塊
	float ground = 1.0 - smoothstep(0.25, 0.6, world_pos.y);
	float dirt = smoothstep(0.62, 0.78, fbm(p * 1.7 + 31.0)) * ground * step(0.5, an.y);
	col = mix(col, dirt_color, dirt * 0.55);
	// 雪堆外圈變薄：邊界跟著雪的起伏（h）不規則，最外一點點幾乎是底下的顏色
	float thin = smoothstep(edge_start, 1.0, mound_k + (h - 0.47) * 0.35);
	col = mix(col, under_color, thin * 0.85);
	ALBEDO = col;

	// 法線：把世界空間的傾斜轉到 view space 疊上去（只在朝上的面）
	vec3 tilt = vec3(-grad.x, 0.0, -grad.y) * bump_strength * step(0.5, an.y);
	NORMAL = normalize(NORMAL + (VIEW_MATRIX * vec4(tilt, 0.0)).xyz);
	ROUGHNESS = mix(0.62, 0.85, dirt);
	SPECULAR = 0.45;

	// 雪粒閃點：4 公分的格子，每格一個隨機方向；跟視線的反射方向對上時才亮
	vec2 cell = floor(p * 25.0);
	float pick = hash(cell);
	float lit = step(1.0 - sparkle_density, pick);
	vec3 dir = normalize(vec3(hash(cell + 7.1) - 0.5, 1.0, hash(cell + 3.7) - 0.5));
	vec3 view_world = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	float glint = pow(max(dot(reflect(-view_world, dir), vec3(0.0, 1.0, 0.0)), 0.0), 6.0);
	vec2 local = fract(p * 25.0) - 0.5;
	float dot_shape = 1.0 - smoothstep(0.08, 0.22, length(local));
	float far = 1.0 - smoothstep(0.012, 0.03, max(fwidth(p.x), fwidth(p.y)));
	EMISSION = vec3(0.9, 0.95, 1.0) * lit * glint * dot_shape * far * sparkle_energy * (1.0 - dirt) * (1.0 - thin);
}
