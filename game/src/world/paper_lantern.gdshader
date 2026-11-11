shader_type spatial;
// 掛在繩上的紙燈籠（地下市場；一個 MultiMesh，每顆的顏色放在 instance color）。
// 中間最亮、往上下兩端暗下去，上下各一圈深色的木圈，橫向幾道竹篾的暗線；邊緣比正面暗一點（看得出是圓的，不是一顆發光的球）。

uniform float energy = 3.4;
uniform float half_height = 0.19;

varying float local_y;

void vertex() {
	local_y = VERTEX.y;
}

void fragment() {
	float v = clamp(abs(local_y) / half_height, 0.0, 1.0);
	float cap = smoothstep(0.8, 0.9, v);
	float ribs = 0.86 + 0.14 * cos(local_y / half_height * 3.14159 * 9.0);
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float core = mix(0.5, 1.0, pow(facing, 0.8)) * (1.0 - 0.4 * v * v);
	vec3 paper = COLOR.rgb;
	ALBEDO = mix(paper * 0.3, vec3(0.03, 0.025, 0.02), cap);
	ROUGHNESS = 0.9;
	EMISSION = paper * energy * core * ribs * (1.0 - cap);
}
