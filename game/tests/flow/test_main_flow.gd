extends TestCase
## 主線流程測試。目前切片尚未建立，只驗證「開機 → 標題畫面 → 可選新遊戲」。
## 任務／存檔系統完成後，這裡要擴充成從新遊戲自動走到切片結尾。


func test_boot_to_title() -> void:
	var packed: PackedScene = load("res://scenes/boot/boot.tscn") as PackedScene
	assert_not_null(packed, "標題場景")
	if packed == null:
		return
	var boot: Control = packed.instantiate() as Control
	tree.root.add_child(boot)
	await tree.process_frame
	var new_game: Button = boot.get_node("%NewGame") as Button
	assert_not_null(new_game, "新遊戲按鈕")
	if new_game != null:
		assert_false(new_game.disabled, "新遊戲可按")
		assert_eq(new_game.text, "MENU_NEW_GAME", "按鈕使用翻譯 key")
	boot.queue_free()
	await tree.process_frame
