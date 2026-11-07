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
