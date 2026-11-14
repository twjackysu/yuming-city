shader_type fog;
// 瘴氣有體積的那一團：體積霧裡的一個紫色橢球（FogVolume）。
// 原本用 FogMaterial：整團濃淡一樣，從旁邊看是一顆光滑均勻的氣球。改成：
// - 底濃上淡（貼著地面最濃，往上變成一縷一縷）
// - 輪廓用雜訊咬出不規則的邊（不是一顆正橢球）
// - 裡面的濃淡慢慢流動（順著風往一邊走、往上飄一點）
// 體積霧的格子很粗：雜訊只用大塊的（約 1～2 m 一團），更細的拍不出來。

uniform float density = 1.2;
uniform vec4 albedo : source_color = vec4(0.62, 0.3, 0.85, 1.0);
uniform vec4 emission : source_color = vec4(0.124, 0.06, 0.17, 1.0);
uniform float fade = 1.0;            // 1＝滿，0＝散掉（會散的霧）
uniform float ground_offset = 0.68;  // 地面在這團中心下方多少公尺（腳本照擺放的高度設）
uniform float flow_speed = 0.22;
uniform float edge_soft = 0.6;       // 從邊界往裡多少公尺淡到滿
uniform float edge_bite = 0.7;       // 雜訊把邊界往裡外推多少公尺（±一半）

float hash3(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}

float noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	vec3 u = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(hash3(i), hash3(i + vec3(1.0, 0.0, 0.0)), u.x), mix(hash3(i + vec3(0.0, 1.0, 0.0)), hash3(i + vec3(1.0, 1.0, 0.0)), u.x), u.y);
	float b = mix(mix(hash3(i + vec3(0.0, 0.0, 1.0)), hash3(i + vec3(1.0, 0.0, 1.0)), u.x), mix(hash3(i + vec3(0.0, 1.0, 1.0)), hash3(i + vec3(1.0, 1.0, 1.0)), u.x), u.y);
	return mix(a, b, u.z);
}

void fog() {
	vec3 p = WORLD_POSITION;
	vec3 drift = vec3(TIME * flow_speed, -TIME * flow_speed * 0.35, TIME * flow_speed * 0.6);
	float n = noise3(p * 0.85 + drift) * 0.65 + noise3(p * 1.9 - drift * 1.3) * 0.35;
	float wisps = smoothstep(0.28, 0.72, n);
	// 離地高度（公尺）：底濃上淡
	float hgt = max(WORLD_POSITION.y - OBJECT_POSITION.y + ground_offset, 0.0);
	float body = mix(1.55, 0.3, smoothstep(0.0, 1.3, hgt));
	// 邊界（SDF 裡面是負的）：加上雜訊，輪廓才不是一顆光滑的橢球；越高的地方咬得越兇（上面是一縷一縷的）
	float inside = clamp((-SDF + (n - 0.5) * edge_bite * (0.7 + 0.6 * smoothstep(0.2, 1.2, hgt))) / edge_soft, 0.0, 1.0);
	inside = inside * inside * (3.0 - 2.0 * inside);
	DENSITY = density * fade * body * mix(0.5, 1.5, wisps) * inside;
	ALBEDO = albedo.rgb * mix(vec3(0.78, 0.94, 0.82), vec3(1.0), wisps);
	EMISSION = emission.rgb * (0.6 + 0.8 * wisps);
}
