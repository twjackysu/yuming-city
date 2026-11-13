class_name BarkLines
extends RefCounted
## 角色頭上跳出來的一句話（D-246，docs/design/11-combat-first.md 第 0 節）：諾恩的碎念、旁人的反應。
## 每種情境幾句輪流（不用亂數：機器人的場次要能重現）；回傳的是翻譯 key。
## 規則：不解釋玩法——講的是這個人覺得眼前的事哪裡不對勁。

const NOEN_ENTER: String = "enter"
const NOEN_RELEASE: String = "release"
const NOEN_RELEASE_MISS: String = "release_miss"
const THROWER_GAWK: String = "gawk"
const SHEILA_WATCH: String = "sheila"
const ENEMY_CHOKE: String = "choke"

const LINES: Dictionary = {
	"enter": ["BARK_NOEN_ENTER_1", "BARK_NOEN_ENTER_2", "BARK_NOEN_ENTER_3", "BARK_NOEN_ENTER_4"],
	"release": ["BARK_NOEN_RELEASE_1", "BARK_NOEN_RELEASE_2", "BARK_NOEN_RELEASE_3", "BARK_NOEN_RELEASE_4"],
	"release_miss": ["BARK_NOEN_MISS_1", "BARK_NOEN_MISS_2"],
	"gawk": ["BARK_THROWER_GAWK_1", "BARK_THROWER_GAWK_2", "BARK_THROWER_GAWK_3", "BARK_THROWER_GAWK_4"],
	"sheila": ["BARK_SHEILA_WATCH_1", "BARK_SHEILA_WATCH_2"],
	"choke": ["BARK_CHOKE_1", "BARK_CHOKE_2", "BARK_CHOKE_3", "BARK_CHOKE_4"],
}

var _next: Dictionary = {}


## 這個情境的下一句（輪流；沒有這個情境＝空字串）
func next(situation: String) -> String:
	var list: Array = LINES.get(situation, []) as Array
	if list.is_empty():
		return ""
	var i: int = int(_next.get(situation, 0))
	_next[situation] = (i + 1) % list.size()
	return str(list[i])


static func all_keys() -> PackedStringArray:
	var out := PackedStringArray()
	for situation: String in LINES:
		for key: String in LINES[situation] as Array:
			out.append(key)
	return out
