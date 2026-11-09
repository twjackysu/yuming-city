shader_type spatial;
// 磨亮的黑石（白晝城的壽命石碑，第 57 輪，D-175）。
// 白晝城沒有方向光、反射來源是一片均勻的背景色，真的反射在黑石上幾乎看不出來（一塊死黑的方塊）。
// 這裡假造「映著穹頂白燈」：越往上越亮的一層冷白光澤（上面對著穹頂）、斜看時邊緣更亮（菲涅耳），
// 再加幾條很淡的直向擦痕。不受油燈以外的光影響，強度很低（字還是最亮的東西）。

render_mode diffuse_burley, specular_schlick_ggx;

uniform vec3 albedo_color : source_color = vec3(0.025, 0.025, 0.03);
uniform vec3 sheen_color : source_color = vec3(0.93, 0.96, 1.0);
// 正面最上緣的光澤強度、斜看的邊緣光澤強度
uniform float sheen_top = 0.035;
uniform float sheen_rim = 0.08;
// 石碑半高（物件座標，盒子中心在原點）
uniform float half_height = 1.15;
uniform float streaks = 0.15;

varying vec3 obj_pos;

float hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

void vertex() {
	obj_pos = VERTEX;
}

void fragment() {
	float up = smoothstep(-0.3 * half_height, half_height, obj_pos.y);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	// 直向的擦痕：每 2 cm 一條，亮度隨機
	float col_id = floor((obj_pos.x + obj_pos.z) * 50.0);
	float streak = mix(1.0 - streaks * 0.5, 1.0 + streaks, hash11(col_id));
	ALBEDO = albedo_color;
	ROUGHNESS = 0.12;
	METALLIC = 0.3;
	SPECULAR = 0.6;
	EMISSION = sheen_color * (sheen_top * up * streak + sheen_rim * fres);
}
