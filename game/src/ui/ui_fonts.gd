class_name UiFonts
extends RefCounted
## 遊戲字型。字型由 scripts/gen-assets.sh 產生（Noto CJK TC 子集，不進 git）；
## 檔案不存在時回傳 null，介面退回 Godot 預設字型＋系統字型 fallback。

const TITLE_SERIF: String = "res://assets/generated/fonts/title_serif_tc.otf"
const UI_SANS: String = "res://assets/generated/fonts/ui_sans_tc.otf"
const UI_SANS_MEDIUM: String = "res://assets/generated/fonts/ui_sans_tc_medium.otf"


static func load_font(path: String) -> Font:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Font


## 建立全域 Theme：預設字型用 UI 黑體；按鈕與滑桿的焦點樣式見 UiTheme。
static func build_theme() -> Theme:
	var theme := Theme.new()
	var ui: Font = load_font(UI_SANS)
	if ui != null:
		theme.default_font = ui
	theme.default_font_size = 22
	UiTheme.style(theme)
	return theme
