class_name CoalDrop
extends RefCounted
## 第 3 章段落 4「煤車」的時機判定（08-chapter2-3.md；段落 4 實作時由 canal 關卡接上，D-165）：
## 送葬者進了閘道之後，諾恩割斷上方煤車的繩索，煤要 FALL_SEC 秒才落到河床——
## 判定用「煤落下那一刻牠會在哪裡」（現在的位置＋走路方向 × 速度 × FALL_SEC），離煤車正下方 PIN_HALF 以內＝壓住；
## 還沒走到＝太早、已經走過＝太晚（兩種都會掙脫 → 變成戰鬥，打到失衡再回到煤車）。
## 只看沿著運河的那一軸（z）：閘道裡河道很窄，左右偏不了多少。
## 牠停著的時候（例如諾恩按住重現、牠轉過來聽）速度是 0——停在正下方就一定壓得住，這是玩家自己會發現的用法。
## 純邏輯：給位置與速度，回傳結果；關卡只負責演。

const PINNED: String = "pinned"
const EARLY: String = "early"
const LATE: String = "late"
## 煤從煤車落到河床要多久（秒）
const FALL_SEC: float = 0.5
## 離煤車正下方多近算壓住（公尺，沿運河）
const PIN_HALF: float = 0.8


## 煤落下那一刻牠在哪裡（z）。walk_dir：牠往哪個方向走（-1＝往北、+1＝往南）；speed：公尺／秒（停著＝0）。
static func landing_z(undertaker_z: float, walk_dir: float, speed: float) -> float:
	return undertaker_z + signf(walk_dir) * maxf(speed, 0.0) * FALL_SEC


## 割斷繩索那一刻判定：PINNED／EARLY／LATE。
static func judge(undertaker_z: float, walk_dir: float, speed: float, cart_z: float) -> String:
	var at: float = landing_z(undertaker_z, walk_dir, speed)
	var off: float = at - cart_z
	if absf(off) <= PIN_HALF:
		return PINNED
	# 還在煤車「前面」（往走路方向看還沒到）＝太早；已經過了＝太晚
	var dir: float = signf(walk_dir) if walk_dir != 0.0 else -1.0
	return EARLY if off * dir < 0.0 else LATE
