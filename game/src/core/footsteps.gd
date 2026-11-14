class_name Footsteps
extends RefCounted
## 腳步聲：踏一步（stomp）就照腳下的地面播一聲（關卡的 `footstep_surface(位置)`：雪、石、木；沒有就當石頭）。
## 什麼時候踏由人偶決定——腳落地的那一刻（Puppet.footfall），所以聲音跟畫面上的腳對得上。

const SURFACES: PackedStringArray = ["snow", "stone", "wood"]

var step_db: float
var sprint_db: float
## 音高隨機的幅度（同一個人每步不要一模一樣）
var pitch_jitter: float = 0.1
var count: int = 0
var last_surface: String = ""


func _init(p_step_db: float, p_sprint_db: float) -> void:
	step_db = p_step_db
	sprint_db = p_sprint_db


## 踏一步。聲音掛在 owner 的父節點（關卡）底下：人停掉 process_mode、倒下被釋放時，正在播的那一步照樣播完。
func stomp(owner: Node3D, sprinting: bool = false) -> void:
	count += 1
	last_surface = surface_at(owner)
	if owner == null or not owner.is_inside_tree():
		return
	var parent: Node = owner.get_parent() if owner.get_parent() != null else owner
	Sfx.play_at(parent, "step_" + last_surface, owner.global_position + Vector3.UP * 0.05,
			(sprint_db if sprinting else step_db) + randf_range(-1.5, 1.5), pitch_jitter, 3.0)


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
