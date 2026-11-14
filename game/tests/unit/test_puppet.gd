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
