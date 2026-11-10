class_name Footsteps
extends RefCounted
## 腳步聲（D-182；席菈 D-184）：每走 stride 公尺（跑步 sprint_stride）踏一步，聲音照關卡的地面
## （關卡的 `footstep_surface(位置)`：雪、石、木；沒有就當石頭）。騰空時不算步。諾恩和席菈共用這一份。

const SURFACES: PackedStringArray = ["snow", "stone", "wood"]

var stride: float
var sprint_stride: float
var step_db: float
var sprint_db: float
## 音高隨機的幅度（同一個人每步不要一模一樣）
var pitch_jitter: float = 0.1
## 3D 音的 unit_size（越小越快聽不到）
var unit_size: float = 3.0
var count: int = 0
var last_surface: String = ""
var _acc: float = 0.0


func _init(p_stride: float, p_sprint_stride: float, p_step_db: float, p_sprint_db: float) -> void:
	stride = p_stride
	sprint_stride = p_sprint_stride
	step_db = p_step_db
	sprint_db = p_sprint_db


## 這一幀走了 moved 公尺。回傳這一幀有沒有踏一步（有就已經播了聲音）。
func tick(owner: Node3D, moved: float, sprinting: bool, grounded: bool) -> bool:
	if not grounded or moved <= 0.0:
		return false
	_acc += moved
	var s: float = sprint_stride if sprinting else stride
	if _acc < s:
		return false
	_acc = fmod(_acc, s)
	count += 1
	last_surface = surface_at(owner)
	if owner != null and owner.is_inside_tree():
		Sfx.play_at(owner, "step_" + last_surface, owner.global_position + Vector3.UP * 0.05,
				(sprint_db if sprinting else step_db) + randf_range(-1.5, 1.5), pitch_jitter, unit_size)
	return true


## 腳下是什麼：先問父節點（關卡），父節點不是關卡就問目前的場景；都沒說就是石頭。
static func surface_at(owner: Node3D) -> String:
	if owner == null:
		return "stone"
	var candidates: Array[Node] = [owner.get_parent()]
	if owner.is_inside_tree():
		candidates.append(owner.get_tree().current_scene)
	for level: Node in candidates:
		if level != null and level.has_method("footstep_surface"):
			var surface: String = str(level.call("footstep_surface", owner.global_position))
			if SURFACES.has(surface):
				return surface
	return "stone"
