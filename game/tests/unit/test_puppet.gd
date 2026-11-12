extends TestCase
## 程序人偶：狀態名（將來 AnimationTree 用同一組）、動作播完回到移動、走路時四肢有擺動。


func _make() -> Puppet:
	var p := Puppet.new()
	tree.root.add_child(p)
	return p


func test_states_follow_speed() -> void:
	var p: Puppet = _make()
	assert_eq(Puppet.STATES, PackedStringArray(["idle", "walk", "run", "dodge", "attack"]), "狀態名固定")
	assert_eq(p.current_state(), "idle")
	p.set_move_speed(3.4)
	assert_eq(p.current_state(), "walk")
	p.set_move_speed(5.8)
	assert_eq(p.current_state(), "run")
	p.set_move_speed(0.0)
	assert_eq(p.current_state(), "idle")
	p.free()


func test_actions_return_to_locomotion() -> void:
	var p: Puppet = _make()
	p.set_move_speed(3.4)
	p.play_action("dodge")
	assert_eq(p.current_state(), "dodge")
	p.advance(0.2)
	assert_eq(p.current_state(), "dodge", "閃避還沒播完")
	assert_true(absf(p.get_node("Roll").rotation.x) > 0.5, "閃避時在翻滾")
	p.advance(0.2)
	assert_eq(p.current_state(), "walk", "播完回到走路")
	p.advance(0.01)
	assert_eq(p.get_node("Roll").rotation.x, 0.0, "翻滾結束身體回正")
	p.play_action("attack")
	p.advance(0.15)
	assert_true(p.joint("shoulder_R").rotation.x > 1.0, "攻擊舉起右手")
	p.advance(0.5)
	assert_eq(p.current_state(), "walk")
	p.free()


func test_walk_swings_limbs() -> void:
	var p: Puppet = _make()
	p.set_move_speed(3.4)
	var max_thigh: float = 0.0
	var opposite: bool = false
	for i: int in 40:
		p.advance(1.0 / 60.0)
		var l: float = p.joint("thigh_L").rotation.x
		var r: float = p.joint("thigh_R").rotation.x
		max_thigh = maxf(max_thigh, absf(l))
		if absf(l) > 0.1 and signf(l) != signf(r):
			opposite = true
	assert_true(max_thigh > 0.25, "走路時大腿擺動（%.2f）" % max_thigh)
	assert_true(opposite, "左右腿反向")
	assert_not_null(p.hand("L"), "左手（提燈）")
	assert_not_null(p.hand("R").get_node_or_null("BellHammer"), "右手鐘錘")
	p.free()


func test_player_drives_puppet() -> void:
	var player: PlayerController = (load("res://scenes/actors/player/player.tscn") as PackedScene).instantiate() as PlayerController
	tree.root.add_child(player)
	await tree.physics_frame
	assert_not_null(player.puppet(), "玩家有人偶")
	assert_not_null(player.puppet().hand("L").get_node_or_null("Lantern"), "提燈在左手")
	player.queue_free()
	await tree.process_frame


## 仰躺（車上的傷者）：整個人貼地、頭朝 +Z、比骨盆遠；站著的人偶頭在高處。
func test_lying_on_back() -> void:
	var p: Puppet = _make()
	p.lying = "back"
	p.advance(0.1)
	var hips: Vector3 = p.joint("hips").global_position
	var neck: Vector3 = p.joint("neck").global_position
	assert_true(hips.length() < 0.25, "骨盆在原點附近（%s）" % hips)
	assert_true(neck.y < 0.45, "脖子貼地（%.2f）" % neck.y)
	assert_true(neck.z > 0.4, "頭朝 +Z（%.2f）" % neck.z)
	var feet: Vector3 = p.joint("knee_L").global_position
	assert_true(feet.z < 0.0 and feet.y < 0.45, "腿往 -Z 平放")
	p.free()


## 坐姿（第 2 章黎歐坐在主椅上）：骨盆在座面高度、膝蓋往前（人偶面向 -Z）、小腿垂直往下到地面附近。
func test_sitting() -> void:
	var p: Puppet = _make()
	p.sitting = true
	p.advance(0.1)
	var hips: Vector3 = p.joint("hips").global_position
	var knee: Vector3 = p.joint("knee_L").global_position
	assert_true(absf(hips.y - Puppet.SIT_HIP_HEIGHT) < 0.02, "骨盆在座面高度（%.2f）" % hips.y)
	assert_true(knee.z < -0.35 and absf(knee.y - hips.y) < 0.1, "大腿往前平放（膝 %s）" % knee)
	var foot: Vector3 = p.joint("knee_L").to_global(Vector3(0, -Puppet.SHIN_LEN, 0))
	assert_true(foot.y < 0.12 and absf(foot.z - knee.z) < 0.1, "小腿垂直往下到地面附近（%s）" % foot)
	p.free()


func test_wounded_use_puppets() -> void:
	var c := Caravan.new()
	c.route = PackedVector3Array([Vector3.ZERO, Vector3(0, 0, 5)])
	tree.root.add_child(c)
	var lying: int = 0
	for n: Node in c.find_children("*", "Puppet", true, false):
		if (n as Puppet).lying == "back":
			lying += 1
	assert_eq(lying, 2, "車上兩名傷者仰躺")
	c.free()


## 出手加速（D-234）：attack_speed 只讓出手的動作播得快，閃避還是原速。
func test_attack_speed_only_speeds_the_attack() -> void:
	var p: Puppet = _make()
	p.attack_speed = 1.5
	p.play_action("attack")
	var frames: int = 0
	while p.action == "attack" and frames < 200:
		p.advance(1.0 / 60.0)
		frames += 1
	var normal: int = ceili(float(Puppet.ACTION_TIME["attack"]) * 60.0)
	assert_true(frames < normal - 6, "出手播得比較快（%d 幀，原本 %d）" % [frames, normal])
	assert_true(frames >= int(float(normal) / 1.5) - 1, "但只快 1.5 倍")
	p.play_action("dodge")
	frames = 0
	while p.action == "dodge" and frames < 200:
		p.advance(1.0 / 60.0)
		frames += 1
	assert_true(absi(frames - ceili(float(Puppet.ACTION_TIME["dodge"]) * 60.0)) <= 1, "閃避還是原速（%d 幀）" % frames)
	p.free()
