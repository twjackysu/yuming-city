class_name RestoreMix
extends Node
## 重現期間的混音（D-183；03-art-audio-direction「九息期間 SFX 低通＋Music 壓低，讓心跳最清楚」）。
##
## 重現中（石拱立著倒數、或乾運河裡按住重現讓心跳變快）：SFX 匯流排的低通從 20 kHz 慢慢收到 900 Hz、
## Music 壓低 8 dB——風、打擊、腳步都悶下去，只剩心跳清楚。心跳本身走 Heart 匯流排（不經過 SFX 的低通，
## 音量跟著「音效」滑桿，見 Settings.MIRROR_VOLUME）。
##
## 來源用輪詢：在 GROUP 群組、有 `restore_mix_active() -> bool` 的節點只要有一個回傳 true 就算重現中。
## 關卡換掉、回標題時來源自己消失，不會卡在悶住的狀態。暫停時一律放開（選單的聲音不要悶）。
## Game 自動建一個（`Game.restore_mix`），PROCESS_MODE_ALWAYS。

const GROUP: StringName = &"restore_sources"
const SFX_BUS: StringName = &"SFX"
const MUSIC_BUS: StringName = &"Music"
## 平常（聽不出有濾波）
const OPEN_HZ: float = 20000.0
## 重現中（悶住，但打擊還聽得出是打擊）
const CLOSED_HZ: float = 900.0
const MUSIC_DUCK_DB: float = -8.0
## 進入很快（心跳第一下就要清楚）、放開慢一點（時間慢慢回來）
const ATTACK_SEC: float = 0.25
const RELEASE_SEC: float = 0.9

## 0＝平常、1＝完全悶住
var amount: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	apply_amount(0.0)


func _process(delta: float) -> void:
	step(delta, sources_active())


## 現在有沒有東西在重現（暫停中一律 false）。
func sources_active() -> bool:
	if not is_inside_tree() or get_tree().paused:
		return false
	for n: Node in get_tree().get_nodes_in_group(GROUP):
		if n.has_method("restore_mix_active") and bool(n.call("restore_mix_active")):
			return true
	return false


## 往目標推 delta 秒並套到匯流排上。
func step(delta: float, active: bool) -> void:
	var target: float = 1.0 if active else 0.0
	var sec: float = ATTACK_SEC if target > amount else RELEASE_SEC
	amount = move_toward(amount, target, delta / sec)
	apply_amount(amount)


## 低通的截止頻率：在對數尺度上內插（耳朵聽起來是均勻地悶下去）。
static func cutoff_for(a: float) -> float:
	var t: float = clampf(a, 0.0, 1.0)
	return exp(lerpf(log(OPEN_HZ), log(CLOSED_HZ), t))


static func duck_for(a: float) -> float:
	return MUSIC_DUCK_DB * clampf(a, 0.0, 1.0)


## 建好效果（Settings.ensure_buses 呼叫；已經有就跳過）。
static func ensure_effects() -> void:
	var sfx: int = AudioServer.get_bus_index(SFX_BUS)
	if sfx >= 0 and _find_effect(sfx, "AudioEffectLowPassFilter") < 0:
		var lp := AudioEffectLowPassFilter.new()
		lp.cutoff_hz = OPEN_HZ
		AudioServer.add_bus_effect(sfx, lp, 0)
		AudioServer.set_bus_effect_enabled(sfx, 0, false)
	var music: int = AudioServer.get_bus_index(MUSIC_BUS)
	if music >= 0 and _find_effect(music, "AudioEffectAmplify") < 0:
		var amp := AudioEffectAmplify.new()
		amp.volume_db = 0.0
		AudioServer.add_bus_effect(music, amp, 0)


static func apply_amount(a: float) -> void:
	var sfx: int = AudioServer.get_bus_index(SFX_BUS)
	var i: int = _find_effect(sfx, "AudioEffectLowPassFilter")
	if i >= 0:
		var lp: AudioEffectLowPassFilter = AudioServer.get_bus_effect(sfx, i) as AudioEffectLowPassFilter
		lp.cutoff_hz = cutoff_for(a)
		# 平常整個關掉（20 kHz 的濾波也還是會動到一點點高頻，而且省一點 CPU）
		AudioServer.set_bus_effect_enabled(sfx, i, a > 0.001)
	var amp: AudioEffectAmplify = music_duck()
	if amp != null:
		amp.volume_db = duck_for(a)


static func lowpass() -> AudioEffectLowPassFilter:
	var sfx: int = AudioServer.get_bus_index(SFX_BUS)
	var i: int = _find_effect(sfx, "AudioEffectLowPassFilter")
	return AudioServer.get_bus_effect(sfx, i) as AudioEffectLowPassFilter if i >= 0 else null


static func lowpass_enabled() -> bool:
	var sfx: int = AudioServer.get_bus_index(SFX_BUS)
	var i: int = _find_effect(sfx, "AudioEffectLowPassFilter")
	return i >= 0 and AudioServer.is_bus_effect_enabled(sfx, i)


static func music_duck() -> AudioEffectAmplify:
	var music: int = AudioServer.get_bus_index(MUSIC_BUS)
	var i: int = _find_effect(music, "AudioEffectAmplify")
	return AudioServer.get_bus_effect(music, i) as AudioEffectAmplify if i >= 0 else null


static func _find_effect(bus: int, cls: String) -> int:
	if bus < 0:
		return -1
	for i: int in AudioServer.get_bus_effect_count(bus):
		var e: AudioEffect = AudioServer.get_bus_effect(bus, i)
		if e != null and e.get_class() == cls:
			return i
	return -1
