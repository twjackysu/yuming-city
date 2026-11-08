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
uniform vec3 under_color : source_color = vec3(0.1, 0.105, 0.125);  // D-127：再暗一點，接近屋瓦與濕石板
uniform float edge_start = 0.5;
// 雪面不是光滑的白枕頭（D-126）：
// - 風吹的紋：順著風向的細波（波長約 22 cm，一邊緩一邊陡），一片一片的、有的地方平；只動法線與一點亮暗
// - 街邊雪帶（UV2.y＝往牆那側多遠，-1＝靠街、+1＝靠牆；其他雪＝0）：靠牆的角落照不到天光、暗一點偏藍，
//   靠街那側才有腳印凹痕（踩實、偏灰）與髒雪
uniform vec2 wind_dir = vec2(0.8, 0.6);
uniform float ripple_freq = 4.5;
uniform float ripple_strength = 0.45;
uniform float wall_shade = 0.55;
uniform float footprint_density = 0.4;
// 鋪在屋瓦上的薄雪（D-127；SnowMound on_tiles：UV2.y＝10＋沿斜面的公尺數）：
// 每排屋瓦的下緣把雪撐出一道橫紋（暗線），雪薄的地方一塊塊露出屋瓦
uniform float tile_row = 0.26;

varying vec3 world_pos;
varying vec3 world_normal;
varying float mound_k;
varying float lean;

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
	lean = UV2.y;
}

void fragment() {
	// 依法線選投影面：朝上（屋頂、雪帶頂面）用 xz，側面用 xy／zy
	vec3 an = abs(world_normal);
	vec2 p = an.y > 0.5 ? world_pos.xz : (an.x > an.z ? world_pos.zy : world_pos.xy);
	// UV2.y：街邊雪帶是 -1～1（lean），屋瓦上的雪是 10 起跳（沿斜面的公尺數），其他雪是 0
	float on_tiles = step(5.0, lean);
	float bank_lean = lean * (1.0 - on_tiles);
	float slope_m = lean - 10.0;
	float h = fbm(p * drift_scale);
	float e = 0.06;
	float hx = fbm((p + vec2(e, 0.0)) * drift_scale);
	float hy = fbm((p + vec2(0.0, e)) * drift_scale);
	vec2 grad = vec2(hx - h, hy - h) / e;

	// 風吹的紋（D-126）：順著風向的細波，相位被大尺度雜訊扭曲（不是一條條直線），一片一片出現
	float up = smoothstep(0.45, 0.75, an.y);
	vec2 wd = normalize(wind_dir);
	float u = dot(p, wd) * ripple_freq + fbm(p * 0.7 + 17.0) * 3.0 + dot(p, vec2(-wd.y, wd.x)) * 0.35;
	float ph = TAU * u;
	float arg = ph + 0.55 * sin(ph);  // 一邊緩一邊陡
	float patch = smoothstep(0.38, 0.62, fbm(p * 0.45 + 5.0));
	// 遠處（一個像素蓋過四分之一個波）淡掉，避免閃爍
	float ripple_lod = 1.0 - smoothstep(0.12, 0.3, fwidth(u));
	// 同一道紋的強弱也不一樣（不像木紋那樣整齊）
	float ripple_amp = patch * ripple_lod * up * (0.45 + 0.55 * noise(p * 2.3 + 3.0));
	// 波面的斜率（往風向）：d/du sin(arg)；乘上 ripple_strength 才是法線傾斜的量
	vec2 ripple_grad = wd * cos(arg) * (1.0 + 0.55 * cos(ph)) * ripple_amp;

	// 腳印（D-126）：靠街那側（lean < 0）50 cm 的格子裡偶爾一個橢圓凹痕，方向大致順著格子雜湊
	float street = 1.0 - smoothstep(-0.55, -0.15, bank_lean);
	vec2 fcell = floor(p * 2.0);
	vec2 fl = fract(p * 2.0) - 0.5 - (vec2(hash(fcell + 2.3), hash(fcell + 8.9)) - 0.5) * 0.35;
	float fa = hash(fcell + 4.1) * 3.1416;
	vec2 fax = vec2(cos(fa), sin(fa));
	vec2 fq = vec2(dot(fl, fax) / 0.13, dot(fl, vec2(-fax.y, fax.x)) / 0.055);
	float fr = length(fq);
	float has_print = step(1.0 - footprint_density, hash(fcell + 13.7)) * street * up;
	float print_lod = 1.0 - smoothstep(0.02, 0.05, max(fwidth(p.x), fwidth(p.y)));
	float dent = (1.0 - smoothstep(0.75, 1.05, fr)) * has_print;
	// 凹痕的內壁：高度往外升高，梯度朝外（fr 對 p 的梯度方向）
	vec2 dent_dir = fax * (fq.x / 0.13) + vec2(-fax.y, fax.x) * (fq.y / 0.055);
	float rim = smoothstep(0.55, 0.95, fr) * (1.0 - smoothstep(0.95, 1.15, fr)) * has_print * print_lod;
	vec2 dent_grad = normalize(dent_dir + vec2(1e-5)) * rim * 0.9;

	vec3 col = snow_color * mix(0.86, 1.08, h);
	// 低處（雪堆之間）偏藍、暗一點
	col = mix(col * shadow_tint * 1.3, col, 0.35 + 0.65 * smoothstep(0.25, 0.6, h));
	// 風紋的迎風面亮一點、背風面暗一點（很淡，主要靠法線）
	col *= 1.0 + 0.09 * sin(arg) * ripple_amp;
	// 街邊雪帶（貼地，或台地上靠街那側）被踩髒的幾塊
	float ground = max(1.0 - smoothstep(0.25, 0.6, world_pos.y), street);
	float dirt = smoothstep(0.62, 0.78, fbm(p * 1.7 + 31.0)) * ground * step(0.5, an.y);
	// 腳印裡踩實的雪：偏灰、暗一點
	dirt = max(dirt, dent * print_lod * 0.55);
	col = mix(col, dirt_color, dirt * 0.55);
	col *= 1.0 - 0.3 * dent * print_lod;
	// 靠牆的角落照不到天光：暗、偏藍
	float wall_k = smoothstep(0.1, 0.6, bank_lean);
	col = mix(col, col * shadow_tint * 0.75, wall_k * wall_shade);
	// 雪堆外圈變薄：邊界跟著雪的起伏（h）不規則，最外一點點幾乎是底下的顏色
	float thin = smoothstep(edge_start, 1.0, mound_k + (h - 0.47) * 0.35);
	// 屋瓦上的薄雪：雪薄的地方（外圈、雜訊低處）一塊塊露出屋瓦；每排屋瓦下緣一道暗線（遠處淡掉）
	// D-131：露出的地方一排一排對齊屋瓦（每排自己的雜訊位移，邊界是屋瓦的橫線），不再是一團團像髒污的斑
	float row_i = floor(slope_m / tile_row);
	float bare_n = fbm(p * 1.1 + vec2(row_i * 1.37, row_i * 0.61) + 9.0);
	float bare = 1.0 - smoothstep(0.37, 0.41, bare_n + 0.19 - mound_k * 0.3);
	thin = max(thin, bare * on_tiles);
	float rr = fract(slope_m / tile_row);
	float row_lod = 1.0 - smoothstep(0.15, 0.4, fwidth(slope_m / tile_row));
	float lip_line = (smoothstep(0.72, 0.9, rr) - smoothstep(0.93, 1.0, rr)) * on_tiles * row_lod;
	col = mix(col, col * shadow_tint * 0.8, lip_line * 0.6);
	col = mix(col, under_color, thin * 0.85);
	// 露出的屋瓦也看得到每排下緣的暗線（像屋瓦，不像一塊平的暗色）
	col *= 1.0 - 0.45 * lip_line * bare;
	ALBEDO = col;

	// 法線：把世界空間的傾斜轉到 view space 疊上去（只在朝上的面）
	vec2 g = grad * bump_strength * step(0.5, an.y) + ripple_grad * ripple_strength + dent_grad;
	vec3 tilt = vec3(-g.x, 0.0, -g.y);
	NORMAL = normalize(NORMAL + (VIEW_MATRIX * vec4(tilt, 0.0)).xyz);
	ROUGHNESS = mix(0.62, 0.85, dirt);
	// 靠牆的角落也少反射天光（不然月光下還是一條亮藍的邊）
	SPECULAR = mix(0.45, 0.12, wall_k);

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
	EMISSION = vec3(0.9, 0.95, 1.0) * lit * glint * dot_shape * far * sparkle_energy * (1.0 - dirt) * (1.0 - thin) * (1.0 - wall_k * 0.7);
}
