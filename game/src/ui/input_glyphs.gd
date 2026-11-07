class_name InputGlyphs
extends RefCounted
## 把按鍵綁定轉成玩家看得到的鍵名（依目前裝置：鍵鼠或手把）。
## 滑鼠、手把與幾個有名字的鍵走翻譯 key（GLYPH_*）；其他鍵盤按鍵用系統鍵名（印在鍵帽上的字，不翻譯）。
## 最後使用的裝置由 App 追蹤（App.last_device／App.device_changed）。

enum Device { KBM, PAD }

const MOUSE_KEYS: Dictionary = {
	MOUSE_BUTTON_LEFT: "GLYPH_MOUSE_LEFT",
	MOUSE_BUTTON_RIGHT: "GLYPH_MOUSE_RIGHT",
	MOUSE_BUTTON_MIDDLE: "GLYPH_MOUSE_MIDDLE",
	MOUSE_BUTTON_XBUTTON1: "GLYPH_MOUSE_X1",
	MOUSE_BUTTON_XBUTTON2: "GLYPH_MOUSE_X2",
}
## 以 Xbox 配置命名（Steam Input 與多數 PC 手把的預設）
const PAD_BUTTON_KEYS: Dictionary = {
	JOY_BUTTON_A: "GLYPH_PAD_A",
	JOY_BUTTON_B: "GLYPH_PAD_B",
	JOY_BUTTON_X: "GLYPH_PAD_X",
	JOY_BUTTON_Y: "GLYPH_PAD_Y",
	JOY_BUTTON_LEFT_SHOULDER: "GLYPH_PAD_LB",
	JOY_BUTTON_RIGHT_SHOULDER: "GLYPH_PAD_RB",
	JOY_BUTTON_LEFT_STICK: "GLYPH_PAD_LS",
	JOY_BUTTON_RIGHT_STICK: "GLYPH_PAD_RS",
	JOY_BUTTON_BACK: "GLYPH_PAD_VIEW",
	JOY_BUTTON_START: "GLYPH_PAD_MENU",
	JOY_BUTTON_DPAD_UP: "GLYPH_PAD_UP",
	JOY_BUTTON_DPAD_DOWN: "GLYPH_PAD_DOWN",
	JOY_BUTTON_DPAD_LEFT: "GLYPH_PAD_LEFT",
	JOY_BUTTON_DPAD_RIGHT: "GLYPH_PAD_RIGHT",
}
const PAD_AXIS_KEYS: Dictionary = {
	JOY_AXIS_LEFT_X: "GLYPH_PAD_LSTICK",
	JOY_AXIS_LEFT_Y: "GLYPH_PAD_LSTICK",
	JOY_AXIS_RIGHT_X: "GLYPH_PAD_RSTICK",
	JOY_AXIS_RIGHT_Y: "GLYPH_PAD_RSTICK",
	JOY_AXIS_TRIGGER_LEFT: "GLYPH_PAD_LT",
	JOY_AXIS_TRIGGER_RIGHT: "GLYPH_PAD_RT",
}
const NAMED_KEYS: Dictionary = {
	KEY_SPACE: "GLYPH_KEY_SPACE",
	KEY_SHIFT: "GLYPH_KEY_SHIFT",
	KEY_CTRL: "GLYPH_KEY_CTRL",
	KEY_ALT: "GLYPH_KEY_ALT",
	KEY_TAB: "GLYPH_KEY_TAB",
	KEY_ESCAPE: "GLYPH_KEY_ESC",
	KEY_ENTER: "GLYPH_KEY_ENTER",
	KEY_BACKSPACE: "GLYPH_KEY_BACKSPACE",
}
## 搖桿輕推不算切換裝置
const AXIS_SWITCH_THRESHOLD: float = 0.5
const MOUSE_MOVE_SWITCH_PX: float = 4.0


## 一個綁定（spec，見 InputSetup.BINDINGS）的顯示文字（已翻譯）。
static func label_for_spec(spec: Vector2i) -> String:
	match spec.x:
		0:
			var code: int = spec.y
			if NAMED_KEYS.has(code):
				return TranslationServer.translate(str(NAMED_KEYS[code]))
			return OS.get_keycode_string(_display_keycode(code))
		1:
			return TranslationServer.translate(str(MOUSE_KEYS.get(spec.y, "GLYPH_UNKNOWN")))
		2:
			return TranslationServer.translate(str(PAD_BUTTON_KEYS.get(spec.y, "GLYPH_UNKNOWN")))
		3:
			return TranslationServer.translate(str(PAD_AXIS_KEYS.get(spec.y, "GLYPH_UNKNOWN")))
	return TranslationServer.translate("GLYPH_UNKNOWN")


## 動作在某裝置上的鍵名，外加方括號（例如「[F]」「[A]」）。
static func label_for_action(action: String, device: int) -> String:
	if InputMap.has_action(action):
		var want_pad: bool = device == Device.PAD
		for ev: InputEvent in InputMap.action_get_events(action):
			var spec: Vector2i = spec_of_event(ev)
			if spec != InputSetup.NONE and (spec.x >= 2) == want_pad:
				return "[%s]" % label_for_spec(spec)
	return "[%s]" % TranslationServer.translate("GLYPH_UNKNOWN")


## InputMap 裡的事件 → spec（不看按下與否）。
static func spec_of_event(ev: InputEvent) -> Vector2i:
	if ev is InputEventKey:
		var k: InputEventKey = ev as InputEventKey
		return Vector2i(0, k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode)
	if ev is InputEventMouseButton:
		return Vector2i(1, (ev as InputEventMouseButton).button_index)
	if ev is InputEventJoypadButton:
		return Vector2i(2, (ev as InputEventJoypadButton).button_index)
	if ev is InputEventJoypadMotion:
		return Vector2i(3, (ev as InputEventJoypadMotion).axis)
	return InputSetup.NONE


## 這個輸入代表玩家正在用哪個裝置；無法判斷（放開、極小的移動）回傳 -1。
static func device_of_event(ev: InputEvent) -> int:
	if ev is InputEventKey or ev is InputEventMouseButton:
		return Device.KBM if ev.is_pressed() else -1
	if ev is InputEventMouseMotion:
		return Device.KBM if (ev as InputEventMouseMotion).relative.length() >= MOUSE_MOVE_SWITCH_PX else -1
	if ev is InputEventJoypadButton:
		return Device.PAD if ev.is_pressed() else -1
	if ev is InputEventJoypadMotion:
		return Device.PAD if absf((ev as InputEventJoypadMotion).axis_value) >= AXIS_SWITCH_THRESHOLD else -1
	return -1


## 實體鍵位 → 目前鍵盤配置上的鍵（AZERTY 等配置顯示正確的字）。headless 時沿用實體鍵位。
static func _display_keycode(physical: int) -> Key:
	if DisplayServer.get_name() != "headless":
		var k: Key = DisplayServer.keyboard_get_keycode_from_physical(physical as Key)
		if k != KEY_NONE:
			return k
	return physical as Key
