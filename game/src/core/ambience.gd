class_name Ambience
extends RefCounted
## 關卡的循環環境音（D-180）：霜橋鎮的風雪、酒館的壁爐、白晝城的鐘擺、乾運河的低風。
## 音檔是 `scripts/gen_sfx.py` 產生的 wav（頭尾已經交叉淡化），這裡複製一份並設成整段循環；
## 環境音走 SFX 匯流排（跟著「音效」音量），配樂走 Music 匯流排；缺檔時安靜回傳 null。

## 播放器上記著是哪一段音（測試、除錯用）。
const META: StringName = &"ambience_sfx"
## 淡入的起點（聽不到）
const MUTED_DB: float = -60.0


## 整段循環的複本（不改到 Sfx 快取裡共用的那份）。
static func looped(sfx_name: String) -> AudioStreamWAV:
	var src: AudioStreamWAV = Sfx.stream(sfx_name) as AudioStreamWAV
	if src == null:
		return null
	var s: AudioStreamWAV = src.duplicate() as AudioStreamWAV
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = int(s.get_length() * float(s.mix_rate))
	return s


## 不分位置的整片環境音（風、遠處的水）。
static func play(parent: Node, sfx_name: String, volume_db: float, node_name: String = "Ambience", bus: StringName = &"SFX") -> AudioStreamPlayer:
	var s: AudioStreamWAV = looped(sfx_name)
	if s == null or parent == null:
		return null
	var p := AudioStreamPlayer.new()
	p.name = node_name
	p.stream = s
	p.bus = bus
	p.volume_db = volume_db
	p.set_meta(META, sfx_name)
	parent.add_child(p)
	p.play()
	return p


## 配樂（D-181）：走 Music 匯流排（跟著「音樂」音量）；fade_in 秒內從無聲慢慢漲到 volume_db。
static func music(parent: Node, sfx_name: String, volume_db: float, fade_in: float, node_name: String) -> AudioStreamPlayer:
	var p: AudioStreamPlayer = play(parent, sfx_name, MUTED_DB if fade_in > 0.0 else volume_db, node_name, &"Music")
	if p != null and fade_in > 0.0:
		p.create_tween().tween_property(p, "volume_db", volume_db, fade_in)
	return p


## 播放器正在播哪一段環境音（不是 Ambience 建的回傳空字串）。
static func sfx_of(p: Node) -> String:
	return str(p.get_meta(META, "")) if p != null else ""


## 從某個東西發出來的環境音（壁爐）：走近變大聲、轉身聽得出方向。
static func play_at(parent: Node3D, sfx_name: String, pos: Vector3, volume_db: float, unit_size: float, node_name: String) -> AudioStreamPlayer3D:
	var s: AudioStreamWAV = looped(sfx_name)
	if s == null or parent == null:
		return null
	var p := AudioStreamPlayer3D.new()
	p.name = node_name
	p.stream = s
	p.bus = &"SFX"
	p.volume_db = volume_db
	p.unit_size = unit_size
	p.max_distance = 30.0
	p.position = pos
	p.set_meta(META, sfx_name)
	parent.add_child(p)
	p.play()
	return p
