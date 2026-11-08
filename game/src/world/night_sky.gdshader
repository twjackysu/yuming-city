shader_type sky;
// 霜橋鎮的冬夜天空（D-117）：取代原本一整片平的深藍背景。
// - 一層被月光照亮的雲：靠近月亮的雲亮、邊緣有銀邊；背月那一側只剩淡淡的層次
// - 下雪的夜：雲蓋住大半個天空，雲縫裡零星的星
// - 地平線一圈遠山的稜線（山頂有月光照到的雪），一圈都有、北邊（鐘樓後面）比較高
// - 月亮本身在月光（LIGHT0）的方向；平常的鏡頭朝北，月亮在背後，看到的是雲與山
// 不用 TIME：反射用的 radiance 只算一次（雲要動之後再考慮，見 D-117）。

uniform vec3 zenith_color : source_color = vec3(0.010, 0.014, 0.028);
uniform vec3 horizon_color : source_color = vec3(0.050, 0.062, 0.092);
uniform vec3 cloud_dark : source_color = vec3(0.050, 0.058, 0.080);
uniform vec3 cloud_lit : source_color = vec3(0.32, 0.36, 0.46);
uniform float cloud_cover = 0.42;
uniform float cloud_scale = 0.55;
uniform vec3 ridge_color : source_color = vec3(0.020, 0.025, 0.040);
uniform vec3 ridge_snow : source_color = vec3(0.085, 0.100, 0.140);
uniform vec3 moon_color : source_color = vec3(0.90, 0.93, 1.0);
uniform float moon_size = 0.022;
uniform float moon_energy = 4.0;
uniform float star_energy = 0.7;

float hash2(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float hash3(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), u.x),
		mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), u.x), u.y);
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

// 遠山的高度（以仰角的 sin 表示）。用方位角的 cos／sin 當噪聲座標，一圈接得起來沒有接縫。
float ridge_height(vec3 dir) {
	vec2 az = normalize(dir.xz + vec2(1e-5));
	float big = fbm(az * 2.2 + vec2(3.1, 7.4));
	float jag = noise(az * 14.0 + vec2(5.0, 1.0));
	// 北邊（-Z）高一點：鐘樓後面的山
	float north = max(-az.y, 0.0);
	return 0.012 + 0.07 * big * big + 0.012 * jag + 0.045 * north * big;
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float up = d.y;

	// 底色：天頂暗、地平線亮一點
	float hz = 1.0 - clamp(up, 0.0, 1.0);
	vec3 col = mix(zenith_color, horizon_color, pow(hz, 4.0));

	vec3 to_moon = LIGHT0_ENABLED ? LIGHT0_DIRECTION : normalize(vec3(0.45, 0.62, 0.65));
	float moon_dot = max(dot(d, to_moon), 0.0);

	// 月亮與月暈（雲之前畫，雲會蓋住一部分）
	float halo = pow(moon_dot, 24.0) * 0.12 + pow(moon_dot, 260.0) * 0.5;
	col += moon_color * halo;
	float disc = smoothstep(moon_size, moon_size * 0.8, acos(clamp(dot(d, to_moon), -1.0, 1.0)));
	col += moon_color * disc * moon_energy;

	// 星：雲縫才看得到；反射用的 cubemap 不畫（地上的水不要一堆小亮點）
	if (!AT_CUBEMAP_PASS && up > 0.05) {
		vec3 cell = floor(d * 260.0);
		float h = hash3(cell);
		if (h > 0.998) {
			vec3 center = (cell + 0.5) / 260.0;
			float dist = length(d - normalize(center)) * 260.0;
			float star = smoothstep(0.55, 0.0, dist) * (0.3 + 0.7 * hash3(cell + 7.0));
			col += vec3(0.75, 0.82, 1.0) * star * star_energy * smoothstep(0.05, 0.25, up);
		}
	}

	// 雲：投影到一片高高的平面；越靠地平線越扁、越淡
	if (up > -0.02) {
		vec2 uv = d.xz / (max(up, 0.0) + 0.12) * cloud_scale;
		float n = fbm(uv + vec2(0.0, 4.0));
		float detail = fbm(uv * 3.1 + vec2(8.0, 2.0));
		float dens = smoothstep(cloud_cover - 0.12, cloud_cover + 0.18, n * 0.8 + detail * 0.25);
		// 雲的邊緣比中間亮（月光從後面透過來的銀邊）
		float edge = dens * (1.0 - dens) * 4.0;
		// 月亮在背後時看到的是雲被照亮的正面（不會全黑）；靠近月亮的雲更亮
		float lit = 0.3 + 0.7 * pow(moon_dot, 3.0);
		vec3 cloud = mix(cloud_dark, cloud_lit, clamp(lit * (0.35 + 0.65 * detail) + edge * 0.18 * (0.3 + lit), 0.0, 1.0));
		float fade = smoothstep(-0.02, 0.16, up);
		col = mix(col, cloud, dens * fade * 0.92);
	}

	// 遠山：稜線以下是山，靠稜線那一段是月光照到的雪；越低越暗、混一點地平線的霧
	float rh = ridge_height(d);
	if (up < rh) {
		float snow_line = smoothstep(rh - 0.035, rh - 0.004, up) * (0.4 + 0.6 * noise(d.xz * 40.0));
		vec3 mountain = mix(ridge_color, ridge_snow, snow_line * (0.45 + 0.55 * pow(moon_dot, 2.0)));
		mountain = mix(mountain, horizon_color, 0.25);
		float aa = smoothstep(rh, rh - 0.002, up);
		col = mix(col, mountain, aa);
	}

	COLOR = col;
}
