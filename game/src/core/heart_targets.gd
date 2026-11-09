class_name HeartTargets
extends RefCounted
## 第 3 章段落 3「假心臟」的目標選擇（08-chapter2-3.md；段落 3 實作時接上，NEXT 第 5 節）：
## 鐘舌送葬者跟著「聽起來最近」的心跳源走。心跳源有兩種：
##   - 假心臟：彌夏照 RhythmTrial.TARGET_BPM 做的，放在地上的位置；
##   - 重現中的諾恩：切片裡重現有心跳聲，重現時心跳變快——聽起來比實際距離近（RESTORE_PULL），也聽得更遠。
## 不是禁止在牠附近用重現，是一個玩家自己會發現的規則：一按住 V，牠就轉向你。
## 純邏輯：給位置，回傳目標；關卡只負責讓牠走過去。

const NONE: String = ""
const DECOY: String = "decoy"
const NOEN: String = "noen"
## 假心臟聽得到的距離（公尺，水平距離）
const HEAR_RANGE: float = 9.0
## 重現中的諾恩：有效距離 = 實際距離 × RESTORE_PULL（越小越吸引）；聽得到的距離 = HEAR_RANGE ÷ RESTORE_PULL
const RESTORE_PULL: float = 0.5


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## 從 from 聽：回傳 {"kind": NONE|DECOY|NOEN, "index": 假心臟的索引（不是假心臟時 -1）, "pos": 目標位置, "score": 有效距離}。
static func pick(from: Vector3, decoys: Array[Vector3], noen_pos: Vector3, noen_restoring: bool) -> Dictionary:
	var best: Dictionary = {"kind": NONE, "index": -1, "pos": from, "score": INF}
	for i: int in decoys.size():
		var d: float = _flat(from, decoys[i])
		if d <= HEAR_RANGE and d < float(best["score"]):
			best = {"kind": DECOY, "index": i, "pos": decoys[i], "score": d}
	if noen_restoring:
		var dn: float = _flat(from, noen_pos)
		var score: float = dn * RESTORE_PULL
		if dn <= HEAR_RANGE / RESTORE_PULL and score < float(best["score"]):
			best = {"kind": NOEN, "index": -1, "pos": noen_pos, "score": score}
	return best
