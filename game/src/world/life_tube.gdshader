shader_type spatial;
// 鐘院內室的細管（第 2 章段落 3，D-159）：從主椅的椅背接進牆上的鐘盤，管子裡一團團暖色的微光慢慢往鐘盤流——
// 被抽走的壽命。全章唯一的暖光：白晝城其他地方都是無方向的白光。
// UV.y＝從椅背量起的公尺數（往鐘盤變大）；UV2.x＝每條管子自己的相位（光團不會整排一起走）。
render_mode cull_back;

uniform vec3 tube_color : source_color = vec3(0.32, 0.2, 0.13);
uniform vec3 glow_color : source_color = vec3(1.0, 0.6, 0.28);
// 光團之間隔多遠（公尺）、往鐘盤流多快（公尺／秒）、光團多長（佔一段的比例）
uniform float spacing = 1.4;
uniform float flow_speed = 0.3;
uniform float pulse_len = 0.22;
uniform float glow_energy = 2.4;
// 管子本身一直有一點點微光（暗處也讀得出管子在哪）
uniform float base_glow = 0.08;

varying float along;
varying float phase;

void vertex() {
	along = UV.y;
	phase = UV2.x;
}

void fragment() {
	float p = fract((along - TIME * flow_speed) / spacing + phase);
	// 光團：前緣亮、後面拖一小段尾巴
	float head = smoothstep(0.0, 0.04, p);
	float tail = 1.0 - smoothstep(0.04, pulse_len, p);
	float pulse = head * tail;
	ALBEDO = tube_color;
	METALLIC = 0.55;
	ROUGHNESS = 0.38;
	EMISSION = glow_color * (base_glow + pulse) * glow_energy;
}
