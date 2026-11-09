extends TestCase
## 第 3 章段落 3「假心臟」的目標選擇（HeartTargets）：最近的假心臟、聽不到就不動、
## 重現中的諾恩聽起來比較近（在牠附近按住 V，牠會轉向諾恩）、沒重現的諾恩不算。


func test_follows_nearest_decoy_in_range() -> void:
	var decoys: Array[Vector3] = [Vector3(0, 0, -8), Vector3(0, 0, -3), Vector3(0, 0, 4)]
	var r: Dictionary = HeartTargets.pick(Vector3.ZERO, decoys, Vector3(50, 0, 0), false)
	assert_eq(r["kind"], HeartTargets.DECOY)
	assert_eq(r["index"], 1, "最近的假心臟")
	assert_eq(r["pos"], Vector3(0, 0, -3))


func test_nothing_in_range() -> void:
	var decoys: Array[Vector3] = [Vector3(0, 0, -(HeartTargets.HEAR_RANGE + 0.5))]
	var r: Dictionary = HeartTargets.pick(Vector3.ZERO, decoys, Vector3(1, 0, 0), false)
	assert_eq(r["kind"], HeartTargets.NONE, "聽不到假心臟、諾恩沒在重現 → 不動")
	assert_eq(r["index"], -1)


func test_restoring_noen_pulls_harder() -> void:
	var decoys: Array[Vector3] = [Vector3(0, 0, -4)]
	var noen := Vector3(6, 0, 0)
	assert_eq(HeartTargets.pick(Vector3.ZERO, decoys, noen, false)["kind"], HeartTargets.DECOY, "沒重現：跟假心臟")
	assert_eq(HeartTargets.pick(Vector3.ZERO, decoys, noen, true)["kind"], HeartTargets.NOEN, "重現中：6 m 的諾恩比 4 m 的假心臟吸引")
	var far := Vector3(HeartTargets.HEAR_RANGE / HeartTargets.RESTORE_PULL + 1.0, 0, 0)
	assert_eq(HeartTargets.pick(Vector3.ZERO, decoys, far, true)["kind"], HeartTargets.DECOY, "重現也有聽得到的距離")
	var empty: Array[Vector3] = []
	assert_eq(HeartTargets.pick(Vector3.ZERO, empty, Vector3(0, 0, 12), true)["kind"], HeartTargets.NOEN, "沒有假心臟時，12 m 外重現也聽得到")


func test_height_is_ignored() -> void:
	var decoys: Array[Vector3] = [Vector3(0, -4.5, -2)]
	assert_eq(HeartTargets.pick(Vector3(0, 1, 0), decoys, Vector3.ZERO, false)["kind"], HeartTargets.DECOY, "河床上的假心臟：只算水平距離")
