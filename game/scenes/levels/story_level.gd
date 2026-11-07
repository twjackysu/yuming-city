class_name StoryLevel
extends Node3D
## 切片關卡共用的劇情邏輯：梨販／鐘樓觸發區、敲鐘演出事件、北街陷落、南街石拱、送葬者戰。
## 沙盒（scenes/dev/sandbox.gd）和霜橋鎮（scenes/levels/frostbridge.gd）都繼承這個，只負責擺場景。
##
## 子類別在 _ready 裡：擺好場景 → 設好 _bell／_bell_light／_north_houses／arch_site → 呼叫 _init_story()。

var _rng := RandomNumberGenerator.new()
## 北街的房子；敲完九下後沉陷（每棟一個 Node3D，meta "height"）
var _north_houses: Array[Node3D] = []
var _north_collapsed: bool = false
var _bell: Node3D
var _bell_light: OmniLight3D
## 南街石拱（九息可保存物）
var arch_site: NineBreathSite
## 送葬者戰（鐵架拋擲、車隊抵達）；還沒開打時是 null
var encounter: ConvoyEncounter


## 劇情相關的共通初始化：過場畫面、日記畫面、過場事件、讀檔後的北街狀態。
func _init_story() -> void:
	add_child(CutsceneView.new())
	var journal := JournalView.new()
	journal.name = "JournalView"
	add_child(journal)
	Game.cutscene_started.connect(_on_cutscene_started)
	Game.cutscene_ended.connect(_on_cutscene_ended)
	if Game.session.state.get_flag("slice.north_street_collapsed", false):
		collapse_north_street(false)


## 子類別覆寫：傷者車隊路線、席菈與送葬者出現的位置。
func _caravan_route() -> PackedVector3Array:
	return PackedVector3Array([Vector3(-1.2, 0, 5.0), Vector3(-0.4, 0, -6.0), Vector3(0.0, 0, -12.0), Vector3(0.6, 0, -21.0)])


func _sheila_spawn() -> Vector3:
	return Vector3(-1.4, 0.0, 3.2)


func _boss_spawn() -> Vector3:
	return Vector3(0.0, 0.0, -6.0)


## 送葬者戰：送葬者（＋席菈）（＋傷者車隊）＋ConvoyEncounter。測試也用這個。
func spawn_convoy_fight(with_caravan: bool, with_sheila: bool = true, boss_pos: Vector3 = Vector3.INF) -> ConvoyEncounter:
	var boss := Undertaker.new()
	boss.name = "Undertaker"
	boss.position = boss_pos if boss_pos.is_finite() else _boss_spawn()
	add_child(boss)
	if with_sheila and not has_node("Sheila"):
		var ally := Sheila.new()
		ally.name = "Sheila"
		ally.position = _sheila_spawn()
		add_child(ally)
	var caravan: Caravan = null
	if with_caravan:
		caravan = Caravan.new()
		caravan.name = "Caravan"
		caravan.route = _caravan_route()
		add_child(caravan)
	encounter = ConvoyEncounter.new().setup(boss, caravan, arch_site)
	encounter.name = "ConvoyEncounter"
	encounter.banner.connect(_banner)
	add_child(encounter)
	return encounter


func _banner(key: String, seconds: float) -> void:
	var hud: Hud = get_node_or_null("Hud") as Hud
	if hud != null:
		hud.show_banner(key, seconds)


func _trigger(node_name: String, pos: Vector3, size: Vector3, action: Callable) -> Area3D:
	var area := Area3D.new()
	area.name = node_name
	area.position = pos
	area.monitorable = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	area.add_child(shape)
	area.body_entered.connect(func(body: Node3D) -> void:
		if body is PlayerController:
			action.call())
	add_child(area)
	return area


func _on_pear_seller() -> void:
	if not Game.session.state.get_flag("slice.met_pear_seller", false):
		Game.start_dialogue("slice_pear_seller")


func _on_bell_tower() -> void:
	if Game.session.quests.stage_of(GameSession.MAIN_QUEST) != "ring_bell" or Game.is_player_locked():
		return
	# 中途讀檔或重來時從第一下重新數
	Game.session.set_flag("slice.bell_rings", 0)
	Game.play_cutscene("slice_bell_nine")


func _camera_marker(marker_name: String, pos: Vector3, target: Vector3) -> void:
	var m := Marker3D.new()
	m.name = marker_name
	add_child(m)
	m.look_at_from_position(pos, target)


func _on_cutscene_started(r: CutsceneRunner) -> void:
	r.event_fired.connect(_on_cutscene_event)


func _on_cutscene_event(event: String, _shot: Dictionary) -> void:
	match event:
		"ring", "ring_final":
			ring_bell_visual(event == "ring_final")
		"collapse":
			collapse_north_street(true)


func _on_cutscene_ended(_id: String, _skipped: bool) -> void:
	# 跳過時沒有 collapse 事件：照旗標補上結果
	if Game.session.state.get_flag("slice.north_street_collapsed", false) and not _north_collapsed:
		collapse_north_street(false)


## 鐘擺一下＋鐘樓的燈亮一下。
func ring_bell_visual(final: bool) -> void:
	if _bell == null:
		return
	Sfx.play_flat(self, "bell_ninth" if final else "bell", 0.0 if final else -3.0)
	var t := create_tween()
	t.tween_property(_bell, "rotation_degrees:x", 16.0 if final else 11.0, 0.12).set_trans(Tween.TRANS_SINE)
	t.tween_property(_bell, "rotation_degrees:x", -8.0, 0.35).set_trans(Tween.TRANS_SINE)
	t.tween_property(_bell, "rotation_degrees:x", 0.0, 0.5).set_trans(Tween.TRANS_SINE)
	if _bell_light != null:
		var flash := create_tween()
		flash.tween_property(_bell_light, "light_energy", 14.0 if final else 9.0, 0.06)
		flash.tween_property(_bell_light, "light_energy", 4.0, 0.9)


## 北街陷落：鐘樓附近的房子沉下去、歪掉。animate=false 時直接放到最後狀態（讀檔、跳過）。
func collapse_north_street(animate: bool) -> void:
	_north_collapsed = true
	var i: int = 0
	for house: Node3D in _north_houses:
		var h: float = float(house.get_meta("height", 5.0))
		var end_pos: Vector3 = house.position + Vector3(0, -h * 0.65, 0)
		var tilt := Vector3(_rng.randf_range(-9, 9), 0, _rng.randf_range(-12, 12))
		if animate:
			var t := create_tween().set_parallel()
			t.tween_property(house, "position", end_pos, 1.6).set_delay(i * 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			t.tween_property(house, "rotation_degrees", tilt, 1.6).set_delay(i * 0.12)
		else:
			house.position = end_pos
			house.rotation_degrees = tilt
		i += 1


func is_north_collapsed() -> bool:
	return _north_collapsed
