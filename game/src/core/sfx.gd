class_name Sfx
extends RefCounted
## 音效播放小工具。音效由 scripts/gen_sfx.py 程序生成到 res://assets/generated/sfx/（不進 git）；
## 檔案不存在時安靜跳過，不影響遊戲。全部走 SFX 匯流排（設定裡的「音效」音量）。

const DIR: String = "res://assets/generated/sfx/"
const NAMES: PackedStringArray = ["blunt", "blunt_weak", "claw", "slash", "whoosh", "rubble_scrape", "iron_clang", "ui_tick", "frost_wind", "market_murmur", "title_theme", "step_snow", "step_stone", "step_wood", "step_heavy", "part_end_theme", "poison_charge", "poison_hiss", "glass_clink"]

static var _cache: Dictionary = {}


static func stream(sfx_name: String) -> AudioStream:
	if _cache.has(sfx_name):
		return _cache[sfx_name] as AudioStream
	var path: String = DIR + sfx_name + ".wav"
	if not ResourceLoader.exists(path):
		return null
	var s: AudioStream = load(path) as AudioStream
	_cache[sfx_name] = s
	return s


## 在世界中某處播放（3D 音效，播完自動釋放）。pitch_jitter 讓連續打擊不會聽起來一模一樣。
static func play_at(parent: Node, sfx_name: String, pos: Vector3, volume_db: float = 0.0, pitch_jitter: float = 0.06, unit_size: float = 6.0) -> AudioStreamPlayer3D:
	var s: AudioStream = stream(sfx_name)
	if s == null or parent == null or not parent.is_inside_tree():
		return null
	var p := AudioStreamPlayer3D.new()
	p.stream = s
	p.bus = &"SFX"
	p.volume_db = volume_db
	p.unit_size = unit_size
	p.max_distance = 80.0
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.finished.connect(p.queue_free)
	parent.add_child(p)
	p.global_position = pos
	p.play()
	return p


## 不分位置（介面、配樂性質的聲音）。
static func play_flat(parent: Node, sfx_name: String, volume_db: float = 0.0, bus: StringName = &"SFX") -> AudioStreamPlayer:
	var s: AudioStream = stream(sfx_name)
	if s == null or parent == null or not parent.is_inside_tree():
		return null
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.bus = bus
	p.volume_db = volume_db
	p.finished.connect(p.queue_free)
	parent.add_child(p)
	p.play()
	return p
