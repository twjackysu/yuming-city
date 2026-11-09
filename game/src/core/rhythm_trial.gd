class_name RhythmTrial
extends RefCounted
## 第 3 章段落 2「趴在水溝裡（觀察）」的判定（D-164；08-chapter2-3.md）。
## 席菈用布包著小石頭，隔著銅片敲一種節奏；掛著的送葬者照「離人的心跳有多近」反應：
## 轉頭（TURN）／偏頭（TILT）／不動（STILL）。不規則的節奏一律不動（牠跟的是心跳，不是聲音）。
## 純邏輯：對話選項記下這次敲哪一種（旗標 ch3.last_tempo），關卡在「敲」那一句出現時呼叫 try_last()，
## 結果寫進旗標 ch3.react（對話的下一句用 text_if 讀），送葬者的動作也照這個演。

const TARGET_BPM: float = 72.0
## 差多少以內轉頭、偏頭（每分鐘幾下）
const TURN_WITHIN: float = 8.0
const TILT_WITHIN: float = 26.0
const STILL: String = "still"
const TILT: String = "tilt"
const TURN: String = "turn"
## 玩家可以選的節奏：id → 每分鐘幾下（負數＝不規則）。選項的順序照 ORDER。
const TEMPOS: Dictionary = {
	"very_slow": 40.0,
	"slow": 56.0,
	"steady": 72.0,
	"fast": 96.0,
	"very_fast": 120.0,
	"irregular": -1.0,
}
const ORDER: PackedStringArray = ["very_slow", "slow", "steady", "fast", "very_fast", "irregular"]
## 不規則：忽快忽慢的間隔（秒），固定序列（每次聽起來一樣、測試可以重現）
const IRREGULAR: PackedFloat32Array = [0.35, 1.2, 0.5, 0.95, 0.3, 1.4, 0.6]
const FLAG_LAST: String = "ch3.last_tempo"
const FLAG_REACT: String = "ch3.react"
const FLAG_TRIES: String = "ch3.rhythm_tries"
const FLAG_FOUND: String = "ch3.rhythm_found"


static func is_tempo(tempo_id: String) -> bool:
	return TEMPOS.has(tempo_id)


static func bpm(tempo_id: String) -> float:
	return float(TEMPOS.get(tempo_id, -1.0))


static func reaction_for_bpm(beats_per_minute: float) -> String:
	if beats_per_minute <= 0.0:
		return STILL
	var off: float = absf(beats_per_minute - TARGET_BPM)
	if off <= TURN_WITHIN:
		return TURN
	if off <= TILT_WITHIN:
		return TILT
	return STILL


static func reaction(tempo_id: String) -> String:
	return reaction_for_bpm(bpm(tempo_id))


## 第 i 下到下一下的間隔（秒）。
static func interval(tempo_id: String, i: int) -> float:
	var b: float = bpm(tempo_id)
	if b <= 0.0:
		return IRREGULAR[posmod(i, IRREGULAR.size())]
	return 60.0 / b


## 敲 count 下，每一下從開始算起的時間（秒）；第一下在 0。
static func knock_times(tempo_id: String, count: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var t: float = 0.0
	for i: int in count:
		out.append(t)
		t += interval(tempo_id, i)
	return out


## 試過的節奏（旗標 ch3.tempo_<id>），照 ORDER。
static func tried(state: GameState) -> PackedStringArray:
	var out := PackedStringArray()
	for id: String in ORDER:
		if bool(state.get_flag("ch3.tempo_" + id, false)):
			out.append(id)
	return out


## 對話選了節奏之後、「敲」那一句出現時：照 ch3.last_tempo 判定，寫進 ch3.react。回傳反應（沒選過回傳 ""）。
static func try_last(state: GameState) -> String:
	var id: String = str(state.get_flag(FLAG_LAST, ""))
	if not is_tempo(id):
		return ""
	var r: String = reaction(id)
	state.set_flag(FLAG_REACT, r)
	return r
