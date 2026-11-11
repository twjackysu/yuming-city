shader_type spatial;
// 下砸留在地上的砸痕（D-218）：中間一塊砸碎的暗色、往外幾道裂縫、外圈一圈被震開的霜粉。
// 貼地的一片方形面片（UV 0～1），吃場景的光（不是自發光：暗處不會亮起來）；fade 1 → 0 淡掉。
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform float fade : hint_range(0.0, 1.0) = 1.0;
// 每一次砸的形狀不一樣（裂縫的角度、長短、邊緣的缺口）
uniform float seed = 0.0;
uniform vec3 stone : source_color = vec3(0.03, 0.035, 0.045);
uniform vec3 frost : source_color = vec3(0.66, 0.71, 0.8);
// 裂縫有幾道
uniform float cracks = 9.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	// 中間砸碎的那一塊：邊緣不規則（沿角度的雜訊，用 cos／sin 取樣才不會在 ±PI 接縫斷掉）
	vec2 ring = vec2(cos(a), sin(a));
	float wob = (noise(ring * 1.7 + seed) - 0.5) * 0.26 + (noise(ring * 5.0 - seed) - 0.5) * 0.1;
	float core_r = 0.36 + wob;
	float core = 1.0 - smoothstep(core_r - 0.1, core_r + 0.02, r);
	// 裡面不是一片平的黑：碎塊之間深淺不一
	float rubble = noise(p * 9.0 + seed * 3.0);
	// 往外的裂縫：每個角度格一道，長短不一、微微彎
	float ang = a / TAU * cracks + hash(vec2(seed, 1.7));
	float id = floor(ang);
	float f = fract(ang) - 0.5;
	float len = 0.5 + 0.45 * hash(vec2(id, seed));
	float bend = (noise(vec2(r * 6.0, id * 3.7 + seed)) - 0.5) * 0.55;
	float d = abs(f + bend) * (TAU / cracks) * r;
	float w = mix(0.05, 0.008, clamp(r / len, 0.0, 1.0));
	float crack = (1.0 - smoothstep(w * 0.4, w, d)) * (1.0 - smoothstep(len - 0.12, len, r));
	// 外圈的霜粉：一圈斷斷續續的淺色
	float rim_in = smoothstep(core_r - 0.03, core_r + 0.06, r);
	float rim_out = 1.0 - smoothstep(core_r + 0.1, core_r + 0.42, r);
	float rim = rim_in * rim_out * smoothstep(0.25, 0.75, noise(p * 6.5 - seed));
	float dark = max(core, crack);
	vec3 inner = stone * mix(0.55, 1.7, rubble);
	ALBEDO = mix(frost, inner, clamp(dark * 1.4, 0.0, 1.0));
	ROUGHNESS = mix(0.95, 0.5, dark);
	SPECULAR = 0.3;
	// 方形面片的四個角不能露出來
	float edge = 1.0 - smoothstep(0.86, 1.0, r);
	ALPHA = clamp(max(max(core * 0.92, crack * 0.9), rim * 0.5), 0.0, 1.0) * edge * fade;
}
