class_name DeadListBoard
extends Node3D
## 第 1 章段落 4（D-170）：梨販攤旁的死者名單——兩根木柱撐一塊木板，貼滿了紙，一張一個名字。
## 張數＝切片結果的死亡人數（D-037：29／30／31／33，`dead_count`）。
## 白天的霜橋鎮才有（frostbridge `_build_day`）；走近按互動鍵 → 對話 ch1_dead_list（講完設 ch1.read_dead_list）。
## 提示「按 {key}　看名單」在 HUD 下方中央（InteractPrompt）。

const RANGE: float = 2.0
const DIALOGUE: String = "ch1_dead_list"
const READ_FLAG: String = "ch1.read_dead_list"
## 木板（本地座標，正面朝 +Z）
const BOARD_W: float = 1.7
const BOARD_H: float = 1.1
const BOARD_BOTTOM: float = 0.7
const BOARD_T: float = 0.05
## 一張紙的大小、一排幾張
const PAPER: Vector2 = Vector2(0.15, 0.19)
const COLUMNS: int = 9
## 北街原本有幾個受困者（RescueSite 四個）
const NORTH_TRAPPED: int = 4

var paper_count: int = 0
var _player: PlayerController
var _near: bool = false


## 切片結果的死亡人數，跟收束時艾妲說的那句同一套條件（D-037，slice_ada_aftermath 的 text_if）：
## 救滿四人且車隊沒被打 29 → 車隊被打三次以上 33 → 救滿四人 30 → 其他 31（原作）。
static func dead_count(st: GameState) -> int:
	var rescued: int = int(st.get_flag("slice.rescued_count", 0))
	var injured: int = int(st.get_flag("slice.convoy_injured", 0))
	if rescued >= NORTH_TRAPPED and injured < 1:
		return 29
	if injured >= 3:
		return 33
	if rescued >= NORTH_TRAPPED:
		return 30
	return 31


## 北街沒救出來的人數（名單最下面寫「北街」的那幾張）。
static func north_unrescued(st: GameState) -> int:
	return clampi(NORTH_TRAPPED - int(st.get_flag("slice.rescued_count", 0)), 0, NORTH_TRAPPED)


func _ready() -> void:
	add_to_group("interact_prompts")
	var st: GameState = Game.session.state if Game.session != null else GameState.new()
	_build(dead_count(st))


func is_near() -> bool:
	return _near


func interact_hint() -> Dictionary:
	if not _near:
		return {}
	return {"fmt": TranslationServer.translate("CH1_DEAD_LIST_HINT"), "action": "interact", "progress": -1.0}


func _physics_process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		for n: Node in get_tree().get_nodes_in_group("player"):
			_player = n as PlayerController
			break
	_near = _player != null and not Game.is_player_locked() and not Game.is_in_dialogue() \
		and _flat_distance(_player.global_position) <= RANGE
	if _near and Input.is_action_just_pressed("interact"):
		read()


func _flat_distance(p: Vector3) -> float:
	var g: Vector3 = global_position
	return Vector2(p.x - g.x, p.z - g.z).length()


## 看名單（測試也用）。
func read() -> void:
	if Game.is_in_dialogue():
		return
	Sfx.play_flat(self, "ui_tick", -12.0)
	Game.start_dialogue(DIALOGUE)


# ---------------------------------------------------------------- 外觀

func _build(count: int) -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.3, 0.22, 0.15)
	wood.roughness = 0.9
	for x: float in [-BOARD_W * 0.42, BOARD_W * 0.42]:
		_box("Post", Vector3(0.09, BOARD_BOTTOM + BOARD_H + 0.12, 0.09), Vector3(x, (BOARD_BOTTOM + BOARD_H + 0.12) * 0.5, -0.05), wood)
	_box("Board", Vector3(BOARD_W, BOARD_H, BOARD_T), Vector3(0, BOARD_BOTTOM + BOARD_H * 0.5, 0), wood)
	# 木板頂上一條薄雪（昨晚的雪）
	var snow := StandardMaterial3D.new()
	snow.albedo_color = Color(0.86, 0.89, 0.93)
	snow.roughness = 0.8
	_box("BoardSnow", Vector3(BOARD_W + 0.02, 0.035, BOARD_T + 0.04), Vector3(0, BOARD_BOTTOM + BOARD_H + 0.017, 0), snow)
	var paper_mesh: ArrayMesh = papers_mesh(count)
	paper_count = count
	var papers := MeshInstance3D.new()
	papers.name = "Papers"
	papers.mesh = paper_mesh
	add_child(papers)
	# 碰撞：別讓人穿過木板
	var body := StaticBody3D.new()
	body.name = "Collision"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(BOARD_W, BOARD_BOTTOM + BOARD_H, 0.2)
	shape.shape = box
	shape.position = Vector3(0, (BOARD_BOTTOM + BOARD_H) * 0.5, -0.03)
	body.add_child(shape)
	add_child(body)


func _box(n: String, size: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.name = n
	var m := BoxMesh.new()
	m.size = size
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	add_child(mi)


## 貼在木板正面的紙（兩個 surface：0＝紙、1＝墨）。每張紙稍微歪一點、顏色深淺不同；
## 上面三四道短墨痕當作名字（遠看像字，不用字型）；最下面那排往右靠（還沒貼滿）。
static func papers_mesh(count: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 172
	var paper := SurfaceTool.new()
	paper.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ink := SurfaceTool.new()
	ink.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows: int = int(ceil(float(count) / float(COLUMNS)))
	var pitch: Vector2 = Vector2(BOARD_W / float(COLUMNS), BOARD_H / float(maxi(rows, 4)))
	var top: float = BOARD_BOTTOM + BOARD_H - pitch.y * 0.5 - 0.02
	var z: float = BOARD_T * 0.5 + 0.004
	for i: int in count:
		var row: int = i / COLUMNS
		var col: int = i % COLUMNS
		var c: Vector3 = Vector3(-BOARD_W * 0.5 + pitch.x * (col + 0.5) + rng.randf_range(-0.012, 0.012),
			top - row * pitch.y + rng.randf_range(-0.015, 0.015), z + i * 0.0002)
		var angle: float = rng.randf_range(-0.09, 0.09)
		var tone: float = rng.randf_range(0.0, 1.0)
		var col_paper: Color = Color(0.82, 0.78, 0.69).lerp(Color(0.74, 0.7, 0.62), tone)
		var size: Vector2 = PAPER * rng.randf_range(0.92, 1.05)
		_quad(paper, c, size, angle, col_paper)
		# 名字：第一道長（名字）、下面兩三道短（住哪、哪一天）
		var lines: int = 3 + (i % 2)
		for k: int in lines:
			var w: float = size.x * (0.62 if k == 0 else rng.randf_range(0.3, 0.55))
			var h: float = 0.012 if k == 0 else 0.007
			var off: Vector2 = Vector2(-size.x * 0.32 + w * 0.5, size.y * 0.3 - k * size.y * 0.17)
			var rot_off: Vector2 = off.rotated(angle)
			_quad(ink, c + Vector3(rot_off.x, rot_off.y, 0.0015), Vector2(w, h), angle, Color(0.1, 0.09, 0.09))
	var mesh := ArrayMesh.new()
	paper.generate_normals()
	paper.commit(mesh)
	ink.generate_normals()
	ink.commit(mesh)
	var paper_mat := StandardMaterial3D.new()
	paper_mat.vertex_color_use_as_albedo = true
	paper_mat.roughness = 0.95
	paper_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, paper_mat)
	var ink_mat := StandardMaterial3D.new()
	ink_mat.vertex_color_use_as_albedo = true
	ink_mat.roughness = 0.6
	ink_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(1, ink_mat)
	return mesh


static func _quad(st: SurfaceTool, c: Vector3, size: Vector2, angle: float, color: Color) -> void:
	var hx: Vector2 = Vector2(size.x * 0.5, 0).rotated(angle)
	var hy: Vector2 = Vector2(0, size.y * 0.5).rotated(angle)
	var a: Vector3 = c + Vector3(-hx.x - hy.x, -hx.y - hy.y, 0)
	var b: Vector3 = c + Vector3(hx.x - hy.x, hx.y - hy.y, 0)
	var d: Vector3 = c + Vector3(hx.x + hy.x, hx.y + hy.y, 0)
	var e: Vector3 = c + Vector3(-hx.x + hy.x, -hx.y + hy.y, 0)
	st.set_color(color)
	# 正面朝 +Z（Godot 的正面是順時針）
	for v: Vector3 in [a, d, b, a, e, d]:
		st.add_vertex(v)
