shader_type spatial;
// 照不到環境光的通道（白晝城的後門：牆後往上的樓梯，第 57 輪，D-175）。
// 白晝城的光是無方向的環境光（到處一樣亮），所以門洞裡的樓梯本來會跟廣場一樣亮。
// 這裡用 AO 把「環境光」照通道深度壓掉（AO_LIGHT_AFFECT = 0：油燈的直接光照常照得到），
// 從門洞往裡 dark_length 公尺幾乎全黑——諾恩拿著油燈走近時才看得到台階。
// 表面是粗石：兩層方塊雜訊讓石塊深淺不一，縫是暗線（物件座標，公尺）。

render_mode diffuse_burley, specular_schlick_ggx;

uniform vec3 albedo_color : source_color = vec3(0.32, 0.31, 0.29);
uniform float roughness_val : hint_range(0.0, 1.0) = 0.92;
// 門洞的位置（世界座標）與往通道裡的方向
uniform vec3 dark_origin = vec3(0.0, 0.0, 0.0);
uniform vec3 dark_dir = vec3(0.0, 0.0, 1.0);
uniform float dark_length = 2.4;
// 最深處還留多少環境光（0＝全黑）
uniform float min_ambient : hint_range(0.0, 1.0) = 0.03;
// 往裡變暗的曲線（>1：門口附近亮得久一點、再很快變黑）
uniform float falloff_power = 1.6;
// 石塊大小（公尺）與縫的深淺
uniform vec2 block_size = vec2(0.42, 0.26);
uniform float seam_dark : hint_range(0.0, 1.0) = 0.55;

varying vec3 world_pos;
varying vec3 obj_pos;
varying vec3 obj_normal;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	obj_pos = VERTEX;
	obj_normal = NORMAL;
}

void fragment() {
	// 面內座標：依法線挑兩個軸
	vec3 an = abs(obj_normal);
	vec2 uv = an.x > 0.5 ? obj_pos.zy : (an.y > 0.5 ? obj_pos.xz : obj_pos.xy);
	vec2 g = uv / block_size;
	// 一排錯開半塊
	g.x += 0.5 * mod(floor(g.y), 2.0);
	vec2 cell = floor(g);
	vec2 f = fract(g);
	float edge = min(min(f.x, 1.0 - f.x) * block_size.x, min(f.y, 1.0 - f.y) * block_size.y);
	float seam = 1.0 - smoothstep(0.004, 0.018, edge);
	float tone = 0.82 + 0.3 * hash12(cell + 17.0);
	vec3 col = albedo_color * tone * (1.0 - seam * seam_dark);
	ALBEDO = col;
	ROUGHNESS = roughness_val;
	float d = dot(world_pos - dark_origin, normalize(dark_dir));
	float k = pow(1.0 - smoothstep(0.0, dark_length, d), falloff_power);
	AO = mix(min_ambient, 1.0, k);
	AO_LIGHT_AFFECT = 0.0;
}
