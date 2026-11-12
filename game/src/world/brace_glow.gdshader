shader_type spatial;
// 硬撐的紅光（D-241）：蓋在敵人整個身體上的一層（GeometryInstance3D.material_overlay），加法混色。
// 只有棍頭的兩圈箍變紅時（D-240），縮小的連拍圖上看不出來——「該閃了」的訊號要大到整個人的輪廓都是紅的。
// 邊緣（視線擦過的地方）最亮、正面也有一層底色：遠看是一個紅色的人形，近看是一圈紅邊。
// strength 由程式每幀寫（剛變紅的那一下最亮、之後一下一下跳、擺前兆時再往上）。
render_mode unshaded, blend_add, cull_back, depth_draw_never, shadows_disabled;

uniform vec3 glow_color : source_color = vec3(1.0, 0.16, 0.05);
uniform float fill = 0.55;
uniform float rim = 2.6;
uniform float rim_power = 1.8;
uniform float strength = 1.0;
// 貼在鏡頭上的時候跟著身體一起淡掉（身體是抖動淡出，CameraFade；這一層不淡的話會剩一個紅色的殘影）
uniform float fade_near = 0.4;
uniform float fade_far = 1.0;

void fragment() {
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float edge = pow(1.0 - facing, rim_power);
	float near_fade = smoothstep(fade_near, fade_far, length(VERTEX));
	ALBEDO = glow_color * (fill + rim * edge) * strength * near_fade;
}
