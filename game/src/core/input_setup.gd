class_name InputSetup
extends RefCounted
## 預設按鍵（鍵鼠＋手把），對應 docs/design/02-gameplay.md 的操作表。
## 啟動時由 App 呼叫 ensure_actions()；之後的重新綁定會覆寫這些預設值。

const DEADZONE: float = 0.2

## action -> [鍵盤或滑鼠, 手把]；Vector2i(x, y)：x=0 鍵盤 keycode，x=1 滑鼠鍵，x=2 手把按鍵，x=3 手把軸（y 為軸，正負由 _AXIS_SIGN 決定）
const BINDINGS: Dictionary = {
	"move_forward": [Vector2i(0, KEY_W), Vector2i(3, JOY_AXIS_LEFT_Y)],
	"move_back": [Vector2i(0, KEY_S), Vector2i(3, JOY_AXIS_LEFT_Y)],
	"move_left": [Vector2i(0, KEY_A), Vector2i(3, JOY_AXIS_LEFT_X)],
	"move_right": [Vector2i(0, KEY_D), Vector2i(3, JOY_AXIS_LEFT_X)],
	"sprint": [Vector2i(0, KEY_SHIFT), Vector2i(2, JOY_BUTTON_LEFT_STICK)],
	"dodge": [Vector2i(0, KEY_SPACE), Vector2i(2, JOY_BUTTON_B)],
	"attack": [Vector2i(1, MOUSE_BUTTON_LEFT), Vector2i(2, JOY_BUTTON_X)],
	"lock_on": [Vector2i(1, MOUSE_BUTTON_MIDDLE), Vector2i(2, JOY_BUTTON_RIGHT_STICK)],
	"insight": [Vector2i(1, MOUSE_BUTTON_RIGHT), Vector2i(3, JOY_AXIS_TRIGGER_LEFT)],
	"command_weakpoint": [Vector2i(0, KEY_Q), Vector2i(2, JOY_BUTTON_DPAD_UP)],
	"command_evade": [Vector2i(0, KEY_E), Vector2i(2, JOY_BUTTON_DPAD_RIGHT)],
	"command_guard": [Vector2i(0, KEY_R), Vector2i(2, JOY_BUTTON_DPAD_DOWN)],
	"interact": [Vector2i(0, KEY_F), Vector2i(2, JOY_BUTTON_A)],
	"nine_breath": [Vector2i(0, KEY_V), Vector2i(2, JOY_BUTTON_Y)],
	"journal": [Vector2i(0, KEY_TAB), Vector2i(2, JOY_BUTTON_BACK)],
	"pause": [Vector2i(0, KEY_ESCAPE), Vector2i(2, JOY_BUTTON_START)],
}

const _AXIS_SIGN: Dictionary = {
	"move_forward": -1.0,
	"move_back": 1.0,
	"move_left": -1.0,
	"move_right": 1.0,
	"insight": 1.0,
}


static func ensure_actions() -> void:
	for action: String in BINDINGS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action, DEADZONE)
		for spec: Vector2i in (BINDINGS[action] as Array):
			InputMap.action_add_event(action, _make_event(action, spec))


static func _make_event(action: String, spec: Vector2i) -> InputEvent:
	match spec.x:
		0:
			var k := InputEventKey.new()
			k.physical_keycode = spec.y as Key
			return k
		1:
			var m := InputEventMouseButton.new()
			m.button_index = spec.y as MouseButton
			return m
		2:
			var b := InputEventJoypadButton.new()
			b.button_index = spec.y as JoyButton
			return b
		_:
			var a := InputEventJoypadMotion.new()
			a.axis = spec.y as JoyAxis
			a.axis_value = float(_AXIS_SIGN.get(action, 1.0))
			return a
