class_name InputSetup
extends RefCounted
## 預設按鍵（鍵鼠＋手把），對應 docs/design/02-gameplay.md 的操作表。
## 啟動時由 App 呼叫 ensure_actions()；Settings 讀到 settings.cfg 的 [input] 後用 apply_bindings() 覆寫。
## 綁定表格式：action -> [鍵鼠 spec, 手把 spec]（spec 見 BINDINGS 說明）。rebind() 是純函式，方便測試。

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

const SLOT_KBM: int = 0
const SLOT_PAD: int = 1
const NONE: Vector2i = Vector2i(-1, -1)
## 不能重新綁定：暫停（Esc／Start 一定叫得出選單）；移動的手把搖桿固定。
const FIXED_ACTIONS: PackedStringArray = ["pause"]
const FIXED_PAD_ACTIONS: PackedStringArray = ["move_forward", "move_back", "move_left", "move_right"]
## 按鍵設定頁的顯示順序與翻譯 key
const ACTION_KEYS: Dictionary = {
	"move_forward": "ACT_MOVE_FORWARD",
	"move_back": "ACT_MOVE_BACK",
	"move_left": "ACT_MOVE_LEFT",
	"move_right": "ACT_MOVE_RIGHT",
	"sprint": "ACT_SPRINT",
	"dodge": "ACT_DODGE",
	"attack": "ACT_ATTACK",
	"lock_on": "ACT_LOCK_ON",
	"insight": "ACT_INSIGHT",
	"command_weakpoint": "ACT_COMMAND_WEAKPOINT",
	"command_evade": "ACT_COMMAND_EVADE",
	"command_guard": "ACT_COMMAND_GUARD",
	"interact": "ACT_INTERACT",
	"nine_breath": "ACT_NINE_BREATH",
	"journal": "ACT_JOURNAL",
	"pause": "ACT_PAUSE",
}
const _MOUSE_BINDABLE: Array[int] = [
	MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_XBUTTON1, MOUSE_BUTTON_XBUTTON2,
]
const _TRIGGER_THRESHOLD: float = 0.6

const _AXIS_SIGN: Dictionary = {
	"move_forward": -1.0,
	"move_back": 1.0,
	"move_left": -1.0,
	"move_right": 1.0,
	"insight": 1.0,
}


## Godot 內建的 ui_accept／ui_cancel 只有鍵盤（Enter、Space／Esc）：手把能用十字鍵移動焦點，
## 卻按不下對話選項、選單按鈕，也關不掉選單。補上 A 確認、B 返回（固定，不進按鍵設定）。
const UI_PAD: Dictionary = {
	"ui_accept": JOY_BUTTON_A,
	"ui_cancel": JOY_BUTTON_B,
}


static func ensure_actions() -> void:
	for action: String in BINDINGS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action, DEADZONE)
		for spec: Vector2i in (BINDINGS[action] as Array):
			InputMap.action_add_event(action, _make_event(action, spec))
	ensure_ui_pad()


static func ensure_ui_pad() -> void:
	for action: String in UI_PAD:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var b := InputEventJoypadButton.new()
		b.button_index = UI_PAD[action] as JoyButton
		if not InputMap.action_has_event(action, b):
			InputMap.action_add_event(action, b)


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


static func defaults() -> Dictionary:
	var out: Dictionary = {}
	for action: String in BINDINGS:
		out[action] = (BINDINGS[action] as Array).duplicate()
	return out


static func is_rebindable(action: String, slot: int) -> bool:
	if not BINDINGS.has(action) or FIXED_ACTIONS.has(action):
		return false
	return not (slot == SLOT_PAD and FIXED_PAD_ACTIONS.has(action))


## 這個 spec 能不能放在這個欄位（鍵鼠欄只收鍵盤／滑鼠，手把欄只收手把）。
static func spec_fits_slot(spec: Vector2i, slot: int) -> bool:
	if slot == SLOT_KBM:
		return spec.x == 0 or (spec.x == 1 and _MOUSE_BINDABLE.has(spec.y))
	if slot == SLOT_PAD:
		return spec.x == 2 or (spec.x == 3 and (spec.y == JOY_AXIS_TRIGGER_LEFT or spec.y == JOY_AXIS_TRIGGER_RIGHT))
	return false


## 等待重新綁定時，把玩家按的東西轉成 spec；不適用（放開、滾輪、搖桿輕推、別的裝置）回傳 NONE。
static func spec_from_event(event: InputEvent, slot: int) -> Vector2i:
	var spec: Vector2i = NONE
	var key: InputEventKey = event as InputEventKey
	var mouse: InputEventMouseButton = event as InputEventMouseButton
	var button: InputEventJoypadButton = event as InputEventJoypadButton
	var motion: InputEventJoypadMotion = event as InputEventJoypadMotion
	if key != null and key.pressed and not key.echo:
		var code: Key = key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
		spec = Vector2i(0, code)
	elif mouse != null and mouse.pressed:
		spec = Vector2i(1, mouse.button_index)
	elif button != null and button.pressed:
		spec = Vector2i(2, button.button_index)
	elif motion != null and motion.axis_value >= _TRIGGER_THRESHOLD:
		spec = Vector2i(3, motion.axis)
	if spec == NONE or not spec_fits_slot(spec, slot):
		return NONE
	return spec


## 回傳新的綁定表（不改傳入的表）。新鍵已被同一欄的別的動作用掉時，兩個動作交換。
## 不能綁的情況（固定動作、欄位不符、跟暫停鍵相同）回傳原表。
static func rebind(bindings: Dictionary, action: String, slot: int, spec: Vector2i) -> Dictionary:
	if not is_rebindable(action, slot) or not spec_fits_slot(spec, slot):
		return bindings
	for fixed: String in FIXED_ACTIONS:
		if slot_of(bindings, fixed, slot) == spec:
			return bindings
	var out: Dictionary = {}
	for a: String in BINDINGS:
		out[a] = [slot_of(bindings, a, SLOT_KBM), slot_of(bindings, a, SLOT_PAD)]
	var old: Vector2i = (out[action] as Array)[slot]
	for other: String in out:
		if other != action and is_rebindable(other, slot) and (out[other] as Array)[slot] == spec:
			(out[other] as Array)[slot] = old
	(out[action] as Array)[slot] = spec
	return out


## 套用到 InputMap（先確保動作存在）。
static func apply_bindings(bindings: Dictionary) -> void:
	ensure_actions()
	for action: String in BINDINGS:
		InputMap.action_erase_events(action)
		for slot: int in [SLOT_KBM, SLOT_PAD]:
			InputMap.action_add_event(action, _make_event(action, slot_of(bindings, action, slot)))


## 從設定檔讀到的值重建綁定表：從預設開始逐筆 rebind，壞掉的值略過、衝突自動解開。
static func from_saved(saved: Dictionary) -> Dictionary:
	var out: Dictionary = defaults()
	for action: String in BINDINGS:
		var entry: Array = saved.get(action, []) as Array
		if entry.size() != 2:
			continue
		for slot: int in [SLOT_KBM, SLOT_PAD]:
			var v: Variant = entry[slot]
			if v is Vector2i:
				out = rebind(out, action, slot, v as Vector2i)
	return out


## 只留跟預設不同的動作（存檔用）。
static func diff_from_defaults(bindings: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for action: String in BINDINGS:
		var cur: Array = [slot_of(bindings, action, SLOT_KBM), slot_of(bindings, action, SLOT_PAD)]
		if cur != (BINDINGS[action] as Array):
			out[action] = cur
	return out


static func slot_of(bindings: Dictionary, action: String, slot: int) -> Vector2i:
	var entry: Array = bindings.get(action, BINDINGS[action]) as Array
	if entry.size() == 2 and entry[slot] is Vector2i:
		return entry[slot] as Vector2i
	return (BINDINGS[action] as Array)[slot] as Vector2i
