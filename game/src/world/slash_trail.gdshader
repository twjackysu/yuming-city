shader_type spatial;
// 揮劍的劍光（SlashTrail）：一條跟著劍掃過去的帶子。UV.x＝這一段還剩多少壽命（1 貼著劍、0 要消失了），UV.y＝0 靠手、1 劍尖。
// 月牙形：貼著劍的那一頭最寬，越舊的越往劍尖縮成一條線、越暗；劍尖那一側有一條最亮的邊。
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec3 tint : source_color = vec3(0.55, 0.1, 0.05);
uniform vec3 core : source_color = vec3(0.9, 0.36, 0.18);
uniform float strength = 1.0;

void fragment() {
	float open = max(smoothstep(0.0, 0.75, UV.x), 0.001);
	float body = smoothstep(1.0 - open, 1.0, UV.y);
	float hot = smoothstep(1.0 - 0.25 * open, 1.0, UV.y);
	ALBEDO = (tint * body * body + core * hot * hot) * strength * smoothstep(0.0, 0.3, UV.x);
}
