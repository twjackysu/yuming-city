class_name RebootOpening
extends Node
## 新版前十分鐘（劇情重寫，D-201～D-204，docs/design/09-reboot-first-ten-minutes.md）在霜橋鎮的控制器。
## frostbridge.gd 在 Game.session.is_reboot() 時掛上這個節點，不跑切片的觸發點、石拱（石拱停用）。
## 這一版做到：開場（雷德在鐵門後、波克在推車上、生命 55）→ 推車到北街轉角 → 藥桶破了、主街上一片毒霧 →
## 第一次中毒自動覺醒（畫面中間兩行字）→ 離開、毒效結束 → 再踏回去確認 → 霧散了 → 推車到南街口。
## 席菈接應之後（meet_sheila 以後）是下一步。

const QUEST: String = GameSession.REBOOT_MAIN_QUEST
## 跟 frostbridge.gd 的 RISE 一樣（北街台地高度）
const RISE: float = 0.9
## 開場短演出把諾恩打到這麼多（鐵架擦過背），自由操作開始時生命穩定
const OPENING_HP: float = 55.0

## 鐵門在北街北端（雷德在門後）
const GATE_Z: float = -45.6
const GATE_HALF: float = 3.4
const RED_POS: Vector3 = Vector3(0.6, RISE, -46.8)
## 推車路線：鐵門前 → 北街轉角（石階頂）→ 石階中段（等霧散）→ 主街 → 廣場 → 南街口
const CART_ROUTE_XZ: Array[Vector2] = [
	Vector2(-0.8, -42.6), Vector2(-0.6, -31.0), Vector2(-0.5, -29.2), Vector2(-0.5, -27.4),
	Vector2(-0.4, -25.2), Vector2(-0.2, -16.0), Vector2(0.4, -6.0), Vector2(0.9, 3.0), Vector2(1.0, 11.0),
]
## 路線上第幾個點＝北街轉角（推車到這裡藥桶就破了）、在霧散之前停在哪一點（石階中段，高處）
const CORNER_POINT: int = 2
## 諾恩沒等推車、自己走到這裡（石階中段）也算到了轉角
const PLAYER_CORNER_Z: float = -27.8
const HOLD_POINT: int = 3
## 推車跟著諾恩走：諾恩在這個距離內才往前推
const ESCORT_RANGE: float = 6.0
const ESCORT_SPEED: float = 1.7

## 破藥桶與毒霧（毒霧整個蓋住主街：半徑大於街的半寬，繞不過去）
const BARREL_SPOTS: Array[Vector3] = [Vector3(-2.7, 0.0, -23.6), Vector3(-1.7, 0.0, -24.0), Vector3(2.9, 0.0, -23.8)]
const MIST_CENTER: Vector3 = Vector3(0.0, 0.0, -18.6)
const MIST_RADIUS: float = 4.4
## 再踏回去確認之後，霧這麼久散掉（推車才過得去）
const MIST_CLEAR_SEC: float = 5.0
## 測試可以調短
var mist_clear_sec: float = MIST_CLEAR_SEC

## 席菈從南街西側的側門出來（推車停在南街口），走近就開始接應的對話
const SHEILA_DOOR: Vector3 = Vector3(-2.3, 0.0, 13.2)
const SHEILA_TALK_RANGE: float = 3.4
## 席菈接應之後的階段（她在場、波克已經進店）
const AFTER_SHEILA_STAGES: PackedStringArray = ["guardian_fight", "portable_poison", "market_lead"]

## 檢查點 → 諾恩出生的位置與朝向（度；180＝面向南）
const SPAWNS: Dictionary = {
	# 開場面向北：鐵門與門後的雷德在眼前（對話結束後自己轉身往南）
	"rb_start": [Vector3(0.6, RISE + 0.05, -40.4), 0.0],
	"rb_before_mist": [Vector3(0.9, 0.5, -27.6), 180.0],
	"rb_sheila": [Vector3(0.0, 0.05, 9.6), 180.0],
	"rb_guardian": [Vector3(0.0, 0.05, 9.6), 180.0],
	"rb_portable": [Vector3(0.0, 0.05, 9.6), 180.0],
	"rb_market": [Vector3(0.0, 0.05, 9.6), 0.0],
}

var level: StoryLevel
var player: PlayerController
var cart: Caravan
var mist: PoisonMist
var barrels: Array[Node3D] = []
var red: Puppet
## 第一次覺醒之後，諾恩已經離開毒霧、毒效也結束了（之後再踏進去才算「確認」）
var left_mist_after_awaken: bool = false
var _mist_clearing: bool = false
var _hold_traveled: float = 0.0
var _corner_traveled: float = 0.0


func _ready() -> void:
	level = get_parent() as StoryLevel
	player = level.get_node_or_null("Player") as PlayerController
	_build_markers()
	_build_gate()
	_build_barrels()
	_build_cart()
	var st: GameState = Game.session.state
	if st.get_flag("rb.barrels_broken", false):
		_break_barrels(false)
	if player != null:
		_place_player(st.checkpoint)
		# 新遊戲（還沒存過生命）：開場被鐵架擦傷
		if not st.vitals.has("hp"):
			player.health.hp = OPENING_HP
		player.reversal.awakened.connect(_on_awakened)
		player.snap_camera()
	Game.dialogue_ended.connect(_on_dialogue_ended)
	Game.session.stage_changed.connect(_on_stage_changed)
	var now: String = stage()
	if now == "meet_sheila":
		_spawn_sheila(SHEILA_DOOR)
	elif now in AFTER_SHEILA_STAGES or Game.session.quests.is_done(QUEST):
		_pok_into_shop()
		if player != null:
			_spawn_sheila(player.global_position + Vector3(-1.4, 0.0, 1.2))
	if not st.get_flag("rb.opening_done", false):
		_begin_opening.call_deferred()
	# 截圖用：`--rb-at=mist` 一進場就站在毒霧裡（第一次覺醒的兩行字）
	if player != null and str(App.parse_user_args(OS.get_cmdline_user_args()).get("rb-at", "")) == "mist":
		player.global_position = MIST_CENTER + Vector3(0.9, 0.05, -2.6)
		player.snap_camera()


## 截圖用（`--rb-at=`）：照正式流程設旗標，推到那一段。start＝開場對話；mist＝藥桶破了、第一次進霧前
static func dev_advance(s: GameSession, at: String) -> void:
	if at in ["mist"]:
		s.set_flag("rb.opening_done", true)
		s.set_flag("rb.barrels_broken", true)


func stage() -> String:
	return Game.session.quests.stage_of(QUEST)


# ---------------------------------------------------------------- 開場

func _begin_opening() -> void:
	if not is_inside_tree() or Game.session.state.get_flag("rb.opening_done", false):
		return
	Game.start_dialogue("rb_opening")


func _on_dialogue_ended(dialogue_id: String) -> void:
	match dialogue_id:
		"rb_opening":
			_red_runs_off()
		"rb_mist_confirmed":
			_clear_mist()
		"rb_sheila_meet":
			_pok_into_shop()


## 雷德頭也不回地往北跑掉（鐵門照樣鎖著）
func _red_runs_off() -> void:
	if red == null or not is_instance_valid(red):
		return
	red.move_speed = 4.0
	red.rotation_degrees.y = 0.0
	var t := red.create_tween()
	t.tween_property(red, "position:z", RED_POS.z - 4.0, 1.4)
	t.tween_callback(red.queue_free)
	red = null


# ---------------------------------------------------------------- 每幀

func _physics_process(delta: float) -> void:
	if player == null or Game.session == null or not Game.session.is_reboot():
		return
	_update_cart(delta)
	var st: GameState = Game.session.state
	match stage():
		"escape":
			# 推車推到北街轉角（或諾恩自己先走下石階）→ 藥桶破了
			if (cart != null and cart.runner.traveled >= _corner_traveled - 0.01) or player.global_position.z >= PLAYER_CORNER_Z:
				_break_barrels(true)
				Game.session.set_flag("rb.barrels_broken", true)
		"poison_discovery":
			_update_mist_test(st)
		"meet_sheila":
			var sheila: Node3D = level.get_node_or_null("Sheila") as Node3D
			if sheila != null and not Game.is_player_locked() and not st.get_flag("rb.sheila_met", false) \
					and sheila.global_position.distance_to(player.global_position) <= SHEILA_TALK_RANGE:
				Game.start_dialogue("rb_sheila_meet")


func _update_cart(delta: float) -> void:
	if cart == null:
		return
	var r: CaravanRunner = cart.runner
	var near: bool = player.global_position.distance_to(cart.global_position) <= ESCORT_RANGE
	r.speed = ESCORT_SPEED if near and not Game.is_player_locked() and not r.is_arrived else 0.0
	# 霧散之前推車停在石階上（高處，波克不進毒霧）
	if not Game.session.state.get_flag("rb.mist_reentered", false) or _mist_clearing or mist != null:
		if r.traveled >= _hold_traveled:
			r.traveled = _hold_traveled
			r.speed = 0.0
	# 藥桶還沒破：推到轉角就停（下一幀破桶）
	if not Game.session.state.get_flag("rb.barrels_broken", false) and r.traveled >= _corner_traveled:
		r.traveled = _corner_traveled
		r.speed = 0.0


func _update_mist_test(st: GameState) -> void:
	if not st.get_flag("rb.reversal_awakened", false) or st.get_flag("rb.mist_reentered", false):
		return
	if Game.is_player_locked() or mist == null:
		return
	var inside: bool = mist.contains(player.global_position)
	if not left_mist_after_awaken:
		if not inside and not player.status_effects.has("poison"):
			left_mist_after_awaken = true
			if not st.get_flag("rb.mist_test_hinted", false):
				Game.start_dialogue("rb_mist_test")
		return
	if inside:
		Game.session.set_flag("rb.mist_reentered", true)
		Game.start_dialogue("rb_mist_confirmed")


## 第一次中毒 → 逆轉體質（ReversalSlots 自動裝進第一格）：畫面中間兩行字，不暫停
func _on_awakened(_status_id: String) -> void:
	var hud: Hud = level.get_node_or_null("Hud") as Hud
	if hud != null:
		hud.show_center_lines("RB_AWAKEN_LINE1", "RB_AWAKEN_LINE2", 4.5)
	Game.session.set_flag("rb.reversal_awakened", true)


func _on_stage_changed(quest_id: String, _from: String, to_stage: String) -> void:
	if quest_id == QUEST and to_stage == "meet_sheila":
		_spawn_sheila(SHEILA_DOOR)


func _spawn_sheila(pos: Vector3) -> void:
	if level.has_node("Sheila"):
		return
	var ally := Sheila.new()
	ally.name = "Sheila"
	ally.position = Vector3(pos.x, level.ground_y(pos), pos.z)
	ally.rotation_degrees.y = 90.0
	level.add_child(ally)


## 席菈接手：波克被扶進店裡（車上沒人了）
func _pok_into_shop() -> void:
	if cart == null:
		return
	for part: String in ["Cart/Wounded0", "Cart/Blanket0"]:
		var n: Node3D = cart.get_node_or_null(part) as Node3D
		if n != null:
			n.visible = false


func _on_cart_arrived() -> void:
	if Game.session.is_reboot() and stage() == "poison_discovery":
		Game.session.set_flag("rb.reached_south", true)


# ---------------------------------------------------------------- 場景

func _build_markers() -> void:
	_marker("RbNorthCorner", Vector3(0.0, RISE + 1.0, -30.0))
	_marker("RbMistEdge", Vector3(0.0, 1.0, MIST_CENTER.z - MIST_RADIUS + 0.6))
	_marker("RbSouthGate", Vector3(1.0, 1.0, 11.0))


func _marker(marker_name: String, pos: Vector3) -> void:
	if level.has_node(marker_name):
		return
	var m := Marker3D.new()
	m.name = marker_name
	m.position = pos
	level.add_child(m)


## 北街北端的鐵門（灰盒：鐵條＋兩道橫槓，擋人）；雷德在門後
func _build_gate() -> void:
	var gate := StaticBody3D.new()
	gate.name = "RbGate"
	gate.position = Vector3(0.0, RISE, GATE_Z)
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.16, 0.16, 0.17)
	iron.metallic = 0.6
	iron.roughness = 0.45
	var bars: int = 13
	for i: int in bars:
		var x: float = lerpf(-GATE_HALF, GATE_HALF, float(i) / float(bars - 1))
		_box_part(gate, Vector3(0.05, 2.4, 0.05), Vector3(x, 1.2, 0.0), iron)
	for y: float in [0.25, 1.35, 2.35]:
		_box_part(gate, Vector3(GATE_HALF * 2.0 + 0.1, 0.07, 0.07), Vector3(0.0, y, 0.0), iron)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(GATE_HALF * 2.0 + 0.4, 2.6, 0.3)
	shape.shape = box
	shape.position = Vector3(0.0, 1.3, 0.0)
	gate.add_child(shape)
	level.add_child(gate)
	if Game.session.state.get_flag("rb.opening_done", false):
		return
	red = Puppet.new()
	red.name = "Red"
	red.coat_color = Color(0.24, 0.2, 0.15)
	red.trim_color = Color(0.5, 0.42, 0.3)
	red.position = RED_POS
	red.rotation_degrees.y = 180.0
	level.add_child(red)
	# 程序人偶預設拿著鐘錘：雷德手上不拿東西
	var hammer: Node = red.hand("R").get_node_or_null("BellHammer") if red.hand("R") != null else null
	if hammer != null:
		hammer.queue_free()


func _build_barrels() -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.34, 0.25, 0.17)
	wood.roughness = 0.85
	var band := StandardMaterial3D.new()
	band.albedo_color = Color(0.2, 0.2, 0.21)
	band.metallic = 0.5
	var label := StandardMaterial3D.new()
	label.albedo_color = Color(0.82, 0.8, 0.72)
	label.roughness = 0.9
	var i: int = 0
	for spot: Vector3 in BARREL_SPOTS:
		var b := Node3D.new()
		b.name = "RbBarrel%d" % i
		b.position = spot
		b.rotation.y = 0.7 * float(i)
		var body := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.3
		cyl.bottom_radius = 0.3
		cyl.height = 0.9
		body.mesh = cyl
		body.material_override = wood
		body.position.y = 0.45
		b.add_child(body)
		for y: float in [0.15, 0.75]:
			var ring := MeshInstance3D.new()
			var rc := CylinderMesh.new()
			rc.top_radius = 0.315
			rc.bottom_radius = 0.315
			rc.height = 0.05
			ring.mesh = rc
			ring.material_override = band
			ring.position.y = y
			b.add_child(ring)
		# 骷髏標與「有毒」（灰盒：一塊淺色標籤＋字）
		var tag := MeshInstance3D.new()
		var tq := QuadMesh.new()
		tq.size = Vector2(0.34, 0.3)
		tag.mesh = tq
		tag.material_override = label
		tag.position = Vector3(0.0, 0.5, 0.305)
		b.add_child(tag)
		var text := Label3D.new()
		text.name = "Toxic"
		text.text = "RB_BARREL_TOXIC"
		text.font_size = 40
		text.pixel_size = 0.004
		text.modulate = Color(0.55, 0.06, 0.05)
		text.outline_size = 0
		text.position = Vector3(0.0, 0.5, 0.31)
		b.add_child(text)
		barrels.append(b)
		level.add_child(b)
		i += 1


## 藥桶破了：倒下、裂開（animate＝剛發生；讀檔時直接擺成破掉的樣子）
func _break_barrels(animate: bool) -> void:
	if barrels.is_empty() or bool(barrels[0].get_meta("broken", false)):
		return
	var i: int = 0
	for b: Node3D in barrels:
		b.set_meta("broken", true)
		var tilt := Vector3(deg_to_rad(84.0), 0.6 * float(i) - 0.5, 0.0)
		if animate and b.is_inside_tree():
			var t := b.create_tween()
			t.tween_property(b, "rotation", tilt, 0.35).set_delay(0.08 * float(i)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		else:
			b.rotation = tilt
		b.position.y = 0.3
		i += 1
	if animate:
		Sfx.play_at(level, "blunt", BARREL_SPOTS[0] + Vector3.UP, 4.0)
		Sfx.play_at(level, "rubble_scrape", BARREL_SPOTS[2] + Vector3.UP, 0.0)
		var hud: Hud = level.get_node_or_null("Hud") as Hud
		if hud != null:
			hud.show_banner("RB_BARRELS_BROKEN", 3.5)
	_spawn_mist()


func _spawn_mist() -> void:
	if mist != null or Game.session.state.get_flag("rb.mist_reentered", false):
		return
	mist = PoisonMist.create(MIST_RADIUS, "barrel_mist")
	mist.name = "RbBarrelMist"
	mist.position = MIST_CENTER
	level.add_child(mist)


## 確認完之後霧慢慢變薄、散掉（推車才過得去）
func _clear_mist() -> void:
	if mist == null or _mist_clearing:
		return
	_mist_clearing = true
	var m: PoisonMist = mist
	var t := m.create_tween()
	t.tween_method(func(r: float) -> void:
		if is_instance_valid(m) and m.zone != null:
			m.zone.radius = r
			m.scale = Vector3(r / MIST_RADIUS, 1.0, r / MIST_RADIUS), MIST_RADIUS, 0.05, mist_clear_sec)
	t.tween_callback(func() -> void:
		if is_instance_valid(m):
			m.queue_free()
		mist = null
		_mist_clearing = false)


func _build_cart() -> void:
	var route := PackedVector3Array()
	for p: Vector2 in CART_ROUTE_XZ:
		var v := Vector3(p.x, 0.0, p.y)
		v.y = level.ground_y(v)
		route.append(v)
	cart = Caravan.new()
	cart.name = "RbCart"
	cart.route = route
	level.add_child(cart)
	# 車上只有波克一個人（車隊的第二名傷者不放）
	for part: String in ["Cart/Wounded1", "Cart/Blanket1"]:
		var n: Node3D = cart.get_node_or_null(part) as Node3D
		if n != null:
			n.visible = false
	cart.runner.speed = 0.0
	_corner_traveled = _distance_to_point(route, CORNER_POINT)
	_hold_traveled = _distance_to_point(route, HOLD_POINT)
	cart.arrived.connect(_on_cart_arrived)
	var st: GameState = Game.session.state
	if st.get_flag("rb.reached_south", false):
		cart.runner.traveled = cart.runner.length()
		cart.runner.is_arrived = true
	elif st.get_flag("rb.barrels_broken", false):
		cart.runner.traveled = _hold_traveled
	cart._sync()


static func _distance_to_point(route: PackedVector3Array, index: int) -> float:
	var d: float = 0.0
	for i: int in range(1, mini(index + 1, route.size())):
		d += route[i - 1].distance_to(route[i])
	return d


func _place_player(checkpoint: String) -> void:
	var spec: Array = SPAWNS.get(checkpoint, SPAWNS["rb_start"]) as Array
	var pos: Vector3 = spec[0] as Vector3
	pos.y = level.ground_y(pos) + 0.05
	player.global_position = pos
	player.rotation.y = deg_to_rad(float(spec[1]))
	player.yaw = player.rotation.y


func _box_part(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
