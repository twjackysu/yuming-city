shader_type spatial;
// 屋瓦（D-107，第三輪盤點第 10 項）：完整的屋頂原本是平塗的深色，近看沒有瓦。
// 斜面的 UV 是公尺（RoofMesh：u＝沿屋簷、v＝從屋簷往屋脊）：一排排錯開的深色石板瓦——
// 每排下緣一道淺色的瓦邊（接住路燈與月光）、往上被上一排蓋住的地方一道陰影、瓦與瓦之間的縫、
// 每片瓦自己的深淺與粗糙度、瓦邊上一點白霜。遠處（一個像素蓋過好幾片瓦）淡回平均色，避免閃爍。
// 山牆三角形（UV < 0）是素面。上半部本來就被屋頂的雪蓋住，雪的下緣露出最下面幾排。

uniform vec3 base_color : source_color = vec3(0.11, 0.11, 0.13);
uniform vec3 frost_color : source_color = vec3(0.5, 0.55, 0.64);
uniform float row_h = 0.26;
uniform float tile_w = 0.34;
uniform float tone_var = 0.22;
uniform float frost = 0.16;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec3 col = base_color;
	float rough = 0.82;
	if (UV.y >= 0.0) {
		float r = UV.y / row_h;
		float row = floor(r);
		float fy = fract(r);  // 0＝這排瓦的下緣（露在外面），1＝被上一排蓋住的地方
		float u = UV.x / tile_w + mod(row, 2.0) * 0.5 + hash(vec2(row, 7.0)) * 0.2;
		float tile = floor(u);
		float fx = fract(u);
		float h = hash(vec2(row, tile));
		// 每片瓦的深淺、偶爾一片偏暖或偏冷
		vec3 tile_col = base_color * (1.0 + (h - 0.5) * 2.0 * tone_var);
		tile_col *= mix(vec3(1.0), vec3(1.08, 1.0, 0.92), step(0.86, h));
		tile_col *= mix(vec3(1.0), vec3(0.92, 0.97, 1.08), step(h, 0.1));
		// 下緣的瓦邊：一條淺色的厚邊（接住光）
		float lip = 1.0 - smoothstep(0.03, 0.14, fy);
		// 上一排的影子：越靠近上一排的下緣越暗
		float under = smoothstep(0.62, 1.0, fy);
		// 瓦縫
		float joint = 1.0 - smoothstep(0.0, 0.035, fx) * smoothstep(0.0, 0.035, 1.0 - fx);
		vec3 pattern = tile_col * (1.0 + lip * 0.55) * (1.0 - under * 0.55) * (1.0 - joint * 0.6);
		// 瓦邊上的薄霜（每片不一樣）
		pattern = mix(pattern, frost_color, lip * frost * smoothstep(0.3, 1.0, hash(vec2(tile, row + 3.0))));
		float pattern_rough = mix(0.62, 0.86, h) + joint * 0.1 - lip * 0.08;
		// 遠處：一個像素蓋過一片瓦以上就淡回平均色
		float fw = max(fwidth(r), fwidth(u));
		float detail = 1.0 - smoothstep(0.35, 0.8, fw);
		col = mix(base_color * 0.95, pattern, detail);
		rough = mix(0.8, pattern_rough, detail);
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = 0.45;
}
