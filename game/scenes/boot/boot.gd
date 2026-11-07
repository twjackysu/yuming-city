extends Control
## 標題畫面。所有可見文字都用翻譯 key（見 res://i18n/strings.csv）。

@onready var _menu: VBoxContainer = %Menu
@onready var _new_game: Button = %NewGame
@onready var _continue: Button = %Continue
@onready var _language: Button = %Language
@onready var _quit: Button = %Quit


func _ready() -> void:
	var serif: Font = UiFonts.load_font(UiFonts.TITLE_SERIF)
	if serif != null:
		(%Title as Label).add_theme_font_override("font", serif)
		(%Subtitle as Label).add_theme_font_override("font", serif)
	_continue.disabled = true  # 存檔系統完成前先停用
	_new_game.pressed.connect(_on_new_game)
	_language.pressed.connect(_on_language)
	_quit.pressed.connect(func() -> void: get_tree().quit())
	_new_game.grab_focus.call_deferred()


func _on_new_game() -> void:
	# 垂直切片場景尚未建立；先保留入口。
	print("[Boot] new game requested")


func _on_language() -> void:
	var next: String = "zh_TW" if Settings.locale == "en" else "en"
	Settings.set_locale(next)
