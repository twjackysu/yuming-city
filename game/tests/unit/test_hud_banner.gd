extends TestCase
## HUD 上方的一行提示：show_banner 停留後淡出、hide_banner 立刻收掉（截圖旗標跳段落時用，盤點截圖 33）。


func test_show_then_hide_banner() -> void:
	var hud: Hud = (load("res://scenes/ui/hud.tscn") as PackedScene).instantiate() as Hud
	tree.root.add_child(hud)
	await tree.process_frame
	assert_eq(hud.banner_text(), "", "一開始沒有提示")
	hud.show_banner("RB_BARRELS_BROKEN", 4.0)
	assert_eq(hud.banner_text(), "RB_BARRELS_BROKEN", "顯示中")
	hud.hide_banner()
	assert_eq(hud.banner_text(), "", "收掉之後馬上沒有")
	await tree.process_frame
	assert_eq(hud.banner_text(), "", "下一幀也不會再淡入")
	hud.show_banner("RB_WAGES_PAID", 1.0)
	assert_eq(hud.banner_text(), "RB_WAGES_PAID", "收掉之後還能再顯示")
	hud.queue_free()
	await tree.process_frame
