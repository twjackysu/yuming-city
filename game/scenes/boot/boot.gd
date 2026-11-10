extends Control
## 標題畫面。所有可見文字都用翻譯 key（見 res://i18n/strings.csv）。

@onready var _menu: VBoxContainer = %Menu
@onready var _new_game: Button = %NewGame
@onready var _continue: Button = %Continue
@onready var _settings_button: Button = %Settings

var _settings_menu: SettingsMenu
@onready var _quit: Button = %Quit
## 標題的配樂（D-181）：長音鋪底＋霧裡遠遠的鐘聲，2.5 秒淡入；走 Music 匯流排，設定頁的「音樂」音量即時生效。
const MUSIC_DB: float = -4.0
const MUSIC_FADE_IN: float = 2.5
var music: AudioStreamPlayer


func _ready() -> void:
	var serif: Font = UiFonts.load_font(UiFonts.TITLE_SERIF)
	if serif != null:
		(%Title as Label).add_theme_font_override("font", serif)
		(%Subtitle as Label).add_theme_font_override("font", serif)
	_continue.disabled = not Game.has_continue()
	_new_game.pressed.connect(_on_new_game)
	_continue.pressed.connect(_on_continue)
	_settings_button.pressed.connect(_on_settings)
	_quit.pressed.connect(func() -> void: get_tree().quit())
	_focus_first.call_deferred()
	music = Ambience.music(self, "title_theme", MUSIC_DB, MUSIC_FADE_IN, "TitleMusic")
	# 截圖用：`-- --open=settings`、`-- --open=controls`
	var open_arg: String = str(App.parse_user_args(OS.get_cmdline_user_args()).get("open", ""))
	if open_arg == "settings" or open_arg == "controls":
		_on_settings.call_deferred()
	if open_arg == "controls":
		_open_controls.call_deferred()


func _focus_first() -> void:
	# 用 --level 直接進關卡時，標題畫面在這之前就被換掉了
	if is_inside_tree():
		_new_game.grab_focus()


func _on_new_game() -> void:
	Game.new_game()


func _on_continue() -> void:
	if not Game.continue_game():
		_continue.disabled = true


func _on_settings() -> void:
	if _settings_menu == null:
		_settings_menu = (load("res://scenes/ui/settings_menu.tscn") as PackedScene).instantiate() as SettingsMenu
		add_child(_settings_menu)
		_settings_menu.closed.connect(_on_settings_closed)
	_menu.hide()
	_settings_menu.open()


func _open_controls() -> void:
	if _settings_menu != null:
		_settings_menu.open_controls()


func _on_settings_closed() -> void:
	_menu.show()
	_settings_button.grab_focus.call_deferred()


## 測試與截圖用
func settings_menu() -> SettingsMenu:
	return _settings_menu
