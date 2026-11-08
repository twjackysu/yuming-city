shader_type spatial;
// 送葬者背上的鐵架（D-101）：原本是一般的暗褐金屬，夜裡隔著霧跟大衣、背景融成一團灰藍，
// 看不出「背上扛著一副鐵架」——而鐵架關節是他的弱點、第二階段還會整副擲出來。
// - 邊緣一圈冷色的光（看出去越斜的面越亮，像霧裡的月光擦過鐵件）：只在鐵件上，大衣不受影響
// - 朝上的面結一層薄霜（偏白、較粗糙）：橫桿頂、立柱頂在夜裡有一道淺色線
// 不打光、不投影，不增加燈的數量。擲出去的那一副（ThrownFrame）用同一個材質。
render_mode cull_back;

uniform vec3 iron_color : source_color = vec3(0.3, 0.24, 0.2);
uniform float iron_metallic : hint_range(0.0, 1.0) = 0.7;
uniform float iron_roughness : hint_range(0.0, 1.0) = 0.6;
uniform vec3 rim_color : source_color = vec3(0.55, 0.82, 1.0);
uniform float rim_energy : hint_range(0.0, 4.0) = 0.9;
uniform float rim_power : hint_range(0.5, 8.0) = 2.5;
uniform vec3 frost_color : source_color = vec3(0.78, 0.84, 0.9);
uniform float frost_amount : hint_range(0.0, 1.0) = 0.65;

// 靠近鏡頭抖動淡掉（D-115，CameraFade 設定；跟 StandardMaterial3D 的 DISTANCE_FADE_PIXEL_DITHER 同一套算法）。
// fade_far 為 0 時不淡出
uniform float fade_near = 0.0;
uniform float fade_far = 0.0;

varying float up;

void vertex() {
	up = (MODEL_MATRIX * vec4(NORMAL, 0.0)).y;
}

void fragment() {
	if (fade_far > fade_near) {
		const vec3 magic = vec3(0.06711056, 0.00583715, 52.9829189);
		float fade = smoothstep(fade_near, fade_far, length(VERTEX));
		if (fade < 0.001 || fade < fract(magic.z * fract(dot(FRAGCOORD.xy, magic.xy)))) {
			discard;
		}
	}
	// 朝上的面（世界座標）才結霜：鐵架倒地、翻滾時霜跟著面走，不會整副變白
	float frost = smoothstep(0.55, 0.9, up) * frost_amount;
	ALBEDO = mix(iron_color, frost_color, frost);
	METALLIC = mix(iron_metallic, 0.0, frost);
	ROUGHNESS = mix(iron_roughness, 0.85, frost);
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = pow(1.0 - facing, rim_power);
	EMISSION = rim_color * rim_energy * rim;
}
