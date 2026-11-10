shader_type spatial;
// 守衛噴毒的那一道（新版，D-207）：從胸口的管子到地面的錐形面片，綠色、沿著噴的方向流動、輪廓邊緣淡掉。
// 不用粒子（一次性的 CPUParticles3D 在截圖／慢幀下拍不到，NEXT 有記）。
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 tint : source_color = vec4(0.5, 1.0, 0.38, 1.0);
uniform float fade = 1.0;
uniform float strength = 0.6;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), u.x), u.y);
}

void fragment() {
	// CylinderMesh 側面的 UV：u 繞一圈、v 0（上＝管口）～0.5（下＝地面）
	float along = clamp(UV.y * 2.0, 0.0, 1.0);
	float around = UV.x * 6.2832;
	// 繞一圈用 sin／cos 取樣，接縫不會斷
	vec2 ring = vec2(cos(around), sin(around)) * 2.2;
	float n = noise(ring + vec2(0.0, along * 5.0 - TIME * 7.0));
	float n2 = noise(ring * 2.3 + vec2(4.1, along * 11.0 - TIME * 11.0));
	float body = smoothstep(0.0, 0.1, along) * (1.0 - smoothstep(0.7, 1.0, along));
	// 掠射角（錐面的輪廓邊）淡掉：看起來是一團霧，不是一個硬邊的錐
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float soft = smoothstep(0.05, 0.6, facing);
	float a = body * (0.3 + 0.7 * n) * (0.45 + 0.55 * n2) * soft;
	ALBEDO = tint.rgb * (0.7 + 0.9 * n);
	ALPHA = clamp(a * fade * strength, 0.0, 1.0);
}
