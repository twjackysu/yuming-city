extends TestCase
## 第 3 章段落 4「煤車」的時機判定（CoalDrop）：看的是煤落下那一刻牠在哪裡；
## 太早＝還沒走到、太晚＝已經走過；停著的時候在正下方一定壓得住。


func test_standing_under_the_cart_is_pinned() -> void:
	assert_eq(CoalDrop.judge(-30.0, -1.0, 0.0, -30.0), CoalDrop.PINNED, "停在正下方")
	assert_eq(CoalDrop.judge(-30.0 + CoalDrop.PIN_HALF - 0.05, -1.0, 0.0, -30.0), CoalDrop.PINNED, "差一點點也算")


func test_lead_for_fall_time() -> void:
	var speed: float = 1.15
	# 往北走（-Z）：煤要 FALL_SEC 才落地，提早一點割才剛好
	var lead: float = speed * CoalDrop.FALL_SEC
	assert_eq(CoalDrop.judge(-30.0 + lead, -1.0, speed, -30.0), CoalDrop.PINNED, "提早一點割：落下時牠剛好在正下方")
	assert_eq(CoalDrop.landing_z(-29.0, -1.0, speed), -29.0 - lead)
	assert_eq(CoalDrop.judge(-30.0 + 2.5, -1.0, speed, -30.0), CoalDrop.EARLY, "還差兩公尺多：太早")
	assert_eq(CoalDrop.judge(-30.0 - 1.0, -1.0, speed, -30.0), CoalDrop.LATE, "已經走過：太晚")


func test_direction_matters() -> void:
	# 往南走（+Z）時，前後顛倒
	assert_eq(CoalDrop.judge(-33.0, 1.0, 1.0, -30.0), CoalDrop.EARLY, "往南走、還在北邊：太早")
	assert_eq(CoalDrop.judge(-28.0, 1.0, 1.0, -30.0), CoalDrop.LATE, "往南走、已經在南邊：太晚")


func test_stopped_far_away_is_early_or_late_by_side() -> void:
	assert_eq(CoalDrop.judge(-27.0, -1.0, 0.0, -30.0), CoalDrop.EARLY, "停在還沒走到的地方")
	assert_eq(CoalDrop.judge(-33.0, -1.0, 0.0, -30.0), CoalDrop.LATE, "停在走過頭的地方")
