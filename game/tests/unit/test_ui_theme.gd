extends TestCase
## 選單樣式（D-067）：全域 Theme 的按鈕／滑桿焦點不是 Godot 預設的白色方框，而是左側暖金色細條＋淡出的暖光。


func test_theme_button_and_slider_styles() -> void:
	var theme: Theme = UiFonts.build_theme()
	var focus: StyleBoxTexture = theme.get_stylebox("focus", "Button") as StyleBoxTexture
	assert_not_null(focus, "按鈕焦點用自己畫的貼圖框")
	if focus != null:
		assert_eq(int(focus.texture_margin_left), UiTheme.BAR_WIDTH, "左側細條是九宮格邊界（不隨按鈕寬度拉伸）")
		var img: Image = focus.texture.get_image()
		var bar: Color = img.get_pixel(0, 1)
		var after: Color = img.get_pixel(UiTheme.BAR_WIDTH + 1, 1)
		var tail: Color = img.get_pixel(img.get_width() - 1, 1)
		assert_true(bar.a > 0.9 and bar.r > bar.b, "細條是實心暖色")
		assert_true(after.a > 0.1 and after.a < 0.3, "細條右邊是淡淡的暖光（a=%.2f）" % after.a)
		assert_true(tail.a < 0.02, "往右淡出到透明")
	var focus_text: Color = theme.get_color("font_focus_color", "Button")
	var text: Color = theme.get_color("font_color", "Button")
	var disabled: Color = theme.get_color("font_disabled_color", "Button")
	assert_true(focus_text.r - focus_text.b > 0.15, "焦點文字是暖色")
	assert_true(text.b >= text.r, "平常的文字偏冷")
	assert_true(disabled.get_luminance() < text.get_luminance() - 0.2, "不能按的文字明顯比較暗")
	var normal: StyleBox = theme.get_stylebox("normal", "Button")
	assert_true(normal.content_margin_left >= UiTheme.BAR_WIDTH + 6, "文字不會壓在細條上")
	assert_true(theme.get_stylebox("focus", "HSlider") is StyleBoxTexture, "滑桿焦點跟按鈕一樣")
	var fill: StyleBoxFlat = theme.get_stylebox("grabber_area", "HSlider") as StyleBoxFlat
	assert_true(fill != null and fill.bg_color.r > fill.bg_color.b, "滑桿已填滿的部分是暖色")
	var knob: Texture2D = theme.get_icon("grabber", "HSlider")
	assert_true(knob != null and knob.get_width() >= 12, "滑桿有圓形把手")
	if knob != null:
		var k: Image = knob.get_image()
		assert_true(k.get_pixel(0, 0).a < 0.05 and k.get_pixel(k.get_width() / 2, k.get_height() / 2).a > 0.9, "把手是圓的（角落透明）")


## 標題畫面：遊戲啟動時全域 Theme 已套用，「新遊戲」拿到焦點時畫的是這個焦點框。
func test_title_menu_uses_theme_focus() -> void:
	var boot: Control = (load("res://scenes/boot/boot.tscn") as PackedScene).instantiate() as Control
	tree.root.add_child(boot)
	await tree.process_frame
	await tree.process_frame
	var new_game: Button = boot.get_node("%NewGame") as Button
	assert_true(new_game.has_focus(), "標題畫面一開始焦點在「新遊戲」")
	assert_true(new_game.get_theme_stylebox("focus") is StyleBoxTexture, "焦點框是暖金色細條（不是預設白框）")
	assert_true(new_game.get_theme_color("font_focus_color").r > new_game.get_theme_color("font_focus_color").b,
		"焦點文字是暖色")
	boot.queue_free()
	await tree.process_frame
