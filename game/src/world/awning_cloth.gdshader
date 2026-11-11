shader_type spatial;
render_mode cull_disabled;
// 布棚、三角旗（地下市場）：直條紋＋織紋＋髒污，兩面都畫。
// 會透光：燈在布底下時，從上面看布是亮的（BACKLIGHT）——從高台往下看整條街的棚子靠這個有顏色。
// UV：x 沿著布的長邊（條紋一條一條排過去），y 從靠牆那一邊（0）到臨街的垂邊（1）。

uniform vec3 cloth_color : source_color = vec3(0.45, 0.12, 0.1);
uniform vec3 stripe_color : source_color = vec3(0.62, 0.54, 0.4);
uniform float stripe_count = 7.0;
uniform float stripe_share : hint_range(0.0, 1.0) = 0.34;
uniform float translucency : hint_range(0.0, 1.0) = 0.6;
uniform float grime : hint_range(0.0, 1.0) = 0.55;

varying vec3 wpos;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float s = fract(UV.x * stripe_count);
	float band = smoothstep(0.0, 0.04, s) * (1.0 - smoothstep(stripe_share, stripe_share + 0.04, s));
	vec3 col = mix(cloth_color, stripe_color, band);
	// 織紋：很細的經緯線，近看才看得到
	float weave = 0.93 + 0.07 * sin(wpos.x * 260.0 + wpos.y * 90.0) * sin(wpos.z * 260.0);
	// 髒污與褪色：大塊的深淺＋垂邊那一側比較髒
	float blotch = vnoise(wpos.xz * 1.9 + wpos.y * 0.7);
	float fine = vnoise(wpos.xz * 9.0);
	col *= mix(1.0, mix(0.62, 1.08, blotch), grime) * weave;
	col *= mix(1.0, 0.72, smoothstep(0.7, 1.0, UV.y) * grime);
	col = mix(col, col * vec3(0.8, 0.76, 0.7), fine * 0.25 * grime);
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	ALBEDO = col;
	ROUGHNESS = 0.94;
	SPECULAR = 0.12;
	BACKLIGHT = col * translucency;
}
