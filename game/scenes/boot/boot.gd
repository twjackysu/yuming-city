extends Control
## 標題畫面。所有可見文字都用翻譯 key（見 res://i18n/strings.csv）。

@onready var _menu: VBoxContainer = %Menu
@onready var _new_game: Button = %NewGame
@onready var _continue: Button = %Continue
@onready var _classic: Button = %Classic
@onready var _settings_button: Button = %Settings
## 「舊版」選項打開的那一頁（D-211）：舊版的新遊戲／繼續／返回。舊劇情凍結，但照樣能玩、舊存檔照樣能讀
@onready var _classic_menu: VBoxContainer = %ClassicMenu
@onready var _classic_new: Button = %ClassicNew
@onready var _classic_continue: Button = %ClassicContinue
@onready var _classic_back: Button = %ClassicBack
## 測試設成 false：按下去只重設／讀取狀態，不換場景
var load_levels: bool = true

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
	# 新遊戲／繼續＝新版（唯一主線）；舊版收在「舊版」選項裡
	_continue.disabled = not Game.has_reboot_continue()
	_classic_continue.disabled = not Game.has_continue()
	_new_game.pressed.connect(_on_new_game)
	_continue.pressed.connect(_on_continue)
	_classic.pressed.connect(open_classic)
	_classic_new.pressed.connect(_on_classic_new)
	_classic_continue.pressed.connect(_on_classic_continue)
	_classic_back.pressed.connect(close_classic)
	_settings_button.pressed.connect(_on_settings)
	_quit.pressed.connect(func() -> void: get_tree().quit())
	_focus_first.call_deferred()
	music = Ambience.music(self, "title_theme", MUSIC_DB, MUSIC_FADE_IN, "TitleMusic")
	# 截圖用：`-- --open=settings`、`-- --open=controls`、`-- --open=classic`
	var open_arg: String = str(App.parse_user_args(OS.get_cmdline_user_args()).get("open", ""))
	if open_arg == "settings" or open_arg == "controls":
		_on_settings.call_deferred()
	if open_arg == "controls":
		_open_controls.call_deferred()
	# `-- --open=classic`：「舊版」那一頁
	if open_arg == "classic":
		open_classic.call_deferred()


func _focus_first() -> void:
	# 用 --level 直接進關卡時，標題畫面在這之前就被換掉了
	if is_inside_tree():
		_new_game.grab_focus()


func _on_new_game() -> void:
	Game.new_reboot_game(load_levels)


func _on_continue() -> void:
	if not Game.continue_reboot_game(load_levels):
		_continue.disabled = true


func _on_classic_new() -> void:
	Game.new_game(load_levels)


func _on_classic_continue() -> void:
	if not Game.continue_game(load_levels):
		_classic_continue.disabled = true


## 「舊版」那一頁：副標題換回舊劇情的名字，焦點放在返回以外的第一個能按的
func open_classic() -> void:
	_menu.hide()
	_classic_menu.show()
	(%Subtitle as Label).text = "GAME_SUBTITLE"
	_classic_new.grab_focus()


func close_classic() -> void:
	_classic_menu.hide()
	_menu.show()
	(%Subtitle as Label).text = "RB_GAME_SUBTITLE"
	_classic.grab_focus()


func is_classic_open() -> bool:
	return _classic_menu.visible


func _unhandled_input(event: InputEvent) -> void:
	if _classic_menu.visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close_classic()


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
