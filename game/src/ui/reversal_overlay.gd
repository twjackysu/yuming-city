class_name ReversalOverlay
extends ColorRect
## 反轉的畫面回饋：整個畫面一層（reversal_overlay.gdshader），邊緣紫紅 → 碎裂 → 金光。
## 純顯示：Hud 每幀把玩家的 ReversalCue 丟進來，沒在播就藏起來（不佔填充率）。

const SHADER: Shader = preload("res://src/ui/reversal_overlay.gdshader")

var _mat: ShaderMaterial


func _ready() -> void:
	name = "ReversalOverlay"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	material = _mat
	visible = false


func refresh(cue: ReversalCue) -> void:
	visible = cue != null and cue.is_playing()
	if not visible:
		return
	_mat.set_shader_parameter("curse", cue.curse())
	_mat.set_shader_parameter("shatter", cue.shatter())
	_mat.set_shader_parameter("gold", cue.gold())
	_mat.set_shader_parameter("aspect", size.x / maxf(size.y, 1.0))


## 現在丟給 shader 的三個數字（測試用）
func levels() -> Vector3:
	if not visible:
		return Vector3.ZERO
	return Vector3(float(_mat.get_shader_parameter("curse")), float(_mat.get_shader_parameter("shatter")), float(_mat.get_shader_parameter("gold")))
