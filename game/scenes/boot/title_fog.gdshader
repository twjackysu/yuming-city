shader_type canvas_item;
// 標題背景：冷色夜霧、遠方鐘樓暖光、暗角。全部程序生成，不依賴貼圖。

uniform vec3 sky_top : source_color = vec3(0.02, 0.03, 0.06);
uniform vec3 sky_bottom : source_color = vec3(0.09, 0.12, 0.18);
uniform vec3 glow_color : source_color = vec3(0.95, 0.72, 0.42);
uniform vec2 glow_pos = vec2(0.72, 0.42);
uniform float fog_speed = 0.015;

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
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = UV;
	float aspect = 1.0 / max(SCREEN_PIXEL_SIZE.x / SCREEN_PIXEL_SIZE.y, 0.0001);
	vec3 col = mix(sky_top, sky_bottom, smoothstep(0.0, 1.0, uv.y));

	// 暖光：鐘樓的燈
	vec2 d = (uv - glow_pos) * vec2(aspect, 1.0);
	float glow = exp(-dot(d, d) * 18.0);
	col += glow_color * glow * 0.55;

	// 兩層霧，下方較濃
	float t = TIME * fog_speed;
	float f1 = fbm(vec2(uv.x * 3.0 * aspect + t * 6.0, uv.y * 4.0 - t));
	float f2 = fbm(vec2(uv.x * 6.0 * aspect - t * 9.0, uv.y * 7.0 + t * 2.0));
	float fog = (f1 * 0.65 + f2 * 0.35) * smoothstep(0.15, 1.0, uv.y);
	col = mix(col, vec3(0.42, 0.48, 0.56), fog * 0.38);

	// 暗角
	vec2 v = uv - 0.5;
	col *= 1.0 - dot(v, v) * 1.25;

	// 微弱顆粒，避免色帶
	col += (hash(uv * 1024.0 + TIME) - 0.5) * 0.012;
	COLOR = vec4(col, 1.0);
}
