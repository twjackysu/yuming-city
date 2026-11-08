class_name RescueSite
extends Node3D
## 北街陷落後的受困者（切片段落 3「救援」，docs/design/05-vertical-slice-plan.md）。
## 救援階段走近 → 按住互動鍵搬開瓦礫（HOLD_SEC 秒，放開歸零）→ 救出：
##   slice.rescued.<site_id>＝true、slice.rescued_count +1（影響死者名單與艾妲的態度）。
## 救出三人後任務進入「席菈」段落（slice_main.json），在送葬者戰之前還可以繼續救。
## 讀檔後已救出的點只剩散開的碎石，不能再救。

signal rescued(site_id: String)

const HOLD_SEC: float = 1.6
const RANGE: float = 2.2
## 可以救人的任務階段
const STAGES: PackedStringArray = ["rescue", "meet_sheila"]

@export var site_id: String = "a"
var hold: float = 0.0
var _player: PlayerController
var _rubble: Node3D
var _person: Node3D
var _label: Label3D
var _done: bool = false
## 搬瓦礫的刮石聲間隔與次數（測試用）
const SCRAPE_EVERY: float = 0.35
var scrape_count: int = 0


func _ready() -> void:
	add_to_group("rescue_sites")
	_build()
	_done = bool(_state().get_flag(flag_key(), false))
	if _done:
		_show_cleared()


func flag_key() -> String:
	return "slice.rescued." + site_id


func _state() -> GameState:
	return Game.session.state if Game.session != null else GameState.new()


func is_rescued() -> bool:
	return _done


func is_available() -> bool:
	if _done or Game.session == null:
		return false
	return Game.session.quests.stage_of(GameSession.MAIN_QUEST) in STAGES


func prompt_shown() -> bool:
	return _label.visible


func _physics_process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		for n: Node in get_tree().get_nodes_in_group("player"):
			_player = n as PlayerController
			break
	var near: bool = is_available() and _player != null and not Game.is_player_locked() \
		and _player.global_position.distance_to(global_position) <= RANGE
	_label.visible = near
	if near:
		_label.text = TranslationServer.translate("RESCUE_HOLD_HINT").format({"key": InputGlyphs.label_for_action("interact", App.last_device)})
	update_hold(delta, near and Input.is_action_pressed("interact"))


## 按住／放開。按滿 HOLD_SEC 救出；回傳是否在這一幀救出。
func update_hold(delta: float, pressed: bool) -> bool:
	if not is_available():
		hold = 0.0
		return false
	var before: float = hold
	hold = hold + delta if pressed else 0.0
	# 搬的時候每 0.35 秒刮一下石頭（第一下立刻響）
	if pressed and is_inside_tree() and (before == 0.0 or floorf(hold / SCRAPE_EVERY) > floorf(before / SCRAPE_EVERY)):
		Sfx.play_at(self, "rubble_scrape", global_position + Vector3.UP * 0.4, -6.0, 0.12, 8.0)
		scrape_count += 1
	# 搬的時候瓦礫跟著晃
	_rubble.position = Vector3(sin(hold * 40.0), 0.0, cos(hold * 33.0)) * 0.03 * minf(hold, 1.0) if hold > 0.0 else Vector3.ZERO
	if hold >= HOLD_SEC:
		rescue()
		return true
	return false


func rescue() -> void:
	if _done:
		return
	_done = true
	hold = 0.0
	_label.visible = false
	if Game.session != null:
		Game.session.set_flag(flag_key(), true)
		Game.session.add_flag("slice.rescued_count")
	if is_inside_tree():
		Sfx.play_at(self, "blunt_weak", global_position + Vector3.UP * 0.5, -4.0, 0.05, 10.0)
		var t := create_tween().set_parallel()
		var i: int = 0
		for c: Node in _rubble.get_children():
			var n: Node3D = c as Node3D
			var away: Vector3 = Vector3(n.position.x, 0.0, n.position.z).normalized() * 1.2
			t.tween_property(n, "position", n.position + away - Vector3(0, 0.15, 0), 0.5).set_delay(i * 0.04).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			i += 1
		# 被拉起來、站好，然後被扶往南邊（先淡出，傷者車隊在送葬者戰再出現）
		t.tween_property(_person, "rotation_degrees:z", 0.0, 0.7).set_delay(0.35)
		t.tween_property(_person, "position", Vector3(0.0, 0.0, 0.0), 0.7).set_delay(0.35)
		t.chain().tween_property(_person, "scale", Vector3(1, 0.001, 1), 0.4).set_delay(1.2)
	else:
		_show_cleared()
	rescued.emit(site_id)


func _show_cleared() -> void:
	_person.visible = false
	for c: Node in _rubble.get_children():
		var n: Node3D = c as Node3D
		n.position += Vector3(n.position.x, 0.0, n.position.z).normalized() * 1.2 - Vector3(0, 0.15, 0)


func _build() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(site_id)
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.22, 0.21, 0.22)
	stone.roughness = 0.95
	var beam := StandardMaterial3D.new()
	beam.albedo_color = Color(0.2, 0.14, 0.1)
	_rubble = Node3D.new()
	_rubble.name = "Rubble"
	add_child(_rubble)
	for i: int in 7:
		var b := MeshInstance3D.new()
		var m := BoxMesh.new()
		m.size = Vector3(rng.randf_range(0.35, 0.8), rng.randf_range(0.2, 0.45), rng.randf_range(0.3, 0.7))
		b.mesh = m
		b.material_override = stone
		b.position = Vector3(rng.randf_range(-0.7, 0.7), m.size.y * 0.5 + rng.randf_range(0.0, 0.25), rng.randf_range(-0.6, 0.6))
		b.rotation_degrees = Vector3(rng.randf_range(-15, 15), rng.randf_range(0, 90), rng.randf_range(-15, 15))
		_rubble.add_child(b)
	var plank := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(2.2, 0.16, 0.22)
	plank.mesh = pm
	plank.material_override = beam
	plank.position = Vector3(0.1, 0.45, 0.05)
	plank.rotation_degrees = Vector3(0, rng.randf_range(-30, 30), 12)
	_rubble.add_child(plank)
	# 受困的人：側倒在瓦礫下
	_person = Node3D.new()
	_person.name = "Person"
	_person.position = Vector3(0.0, 0.25, 0.0)
	_person.rotation_degrees = Vector3(0, 0, 90)
	add_child(_person)
	# 程序人偶整個人側倒（_person 轉 90°），救出來時跟著 _person 轉正、站起來
	var who := Puppet.new()
	who.name = "Puppet"
	who.coat_color = Color(0.3, 0.26, 0.22)
	who.trim_color = Color(0.24, 0.2, 0.16)
	_person.add_child(who)
	var hammer: Node = who.hand("R").get_node_or_null("BellHammer") if who.hand("R") != null else null
	if hammer != null:
		hammer.queue_free()
	# 掉在一旁的提燈：在黑暗的廢墟裡指出有人
	var lamp_mat := StandardMaterial3D.new()
	lamp_mat.albedo_color = Color(0.95, 0.72, 0.42)
	lamp_mat.emission_enabled = true
	lamp_mat.emission = Color(0.95, 0.72, 0.42)
	lamp_mat.emission_energy_multiplier = 3.0
	var lamp := MeshInstance3D.new()
	var lm := SphereMesh.new()
	lm.radius = 0.08
	lm.height = 0.16
	lamp.mesh = lm
	lamp.material_override = lamp_mat
	lamp.position = Vector3(0.9, 0.1, 0.5)
	_rubble.add_child(lamp)
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.95, 0.72, 0.42)
	glow.light_energy = 1.5
	glow.omni_range = 3.6
	glow.light_volumetric_fog_energy = 0.8
	glow.position = Vector3(0.8, 0.4, 0.4)
	add_child(glow)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.fixed_size = true
	_label.pixel_size = 0.0009
	_label.font_size = 30
	_label.outline_size = 18
	_label.modulate = Color(0.95, 0.9, 0.8)
	_label.position = Vector3(0, 1.4, 0)
	_label.visible = false
	add_child(_label)
