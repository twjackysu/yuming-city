extends TestCase
## 操作盤點（docs/design/11-combat-first.md 3.2 最後一點，D-244）：把「按下去之後發生什麼」量成數字。
## 每一項印一行 `CONTROLS …`，PROGRESS 的表從這裡抄。只量戰鬥場；劇情那 20 分鐘的數字不動。
## 要看數字（固定幀率，每次一樣）：
##   TEST_FILTER=controls $(scripts/get-godot.sh) --headless --fixed-fps 60 --path game -s res://tests/run_tests.gd | grep CONTROLS
## 這裡量的是「按鍵有沒有被吃掉、這一下有沒有打到、幾幀之後身體在動」，量不出手感好不好。

const PATH: String = "res://scenes/levels/underground_market.tscn"
const KEYS: PackedStringArray = ["move_forward", "move_back", "move_left", "move_right", "sprint", "attack", "dodge"]
## 諾恩的身高（算他佔畫面多高用）
const BODY_HEIGHT: float = 1.78

var _dir: String = ""
var _original: GameSession


func before_each() -> void:
	_dir = "user://test_controls_%d" % Time.get_ticks_usec()
	_original = _game().get("session") as GameSession


func after_each() -> void:
	tree.paused = false
	Engine.time_scale = 1.0
	for a: String in KEYS:
		Input.action_release(a)
	_game().set("arena_mode", false)
	_game().set("arena_bot", "")
	_game().set("arena_runs", 0)
	_game().set("arena_wave", 0)
	_game().call("arena_revived")
	_game().set("session", _original)
	for d: String in [_dir, _dir + "_reboot"]:
		if DirAccess.dir_exists_absolute(d):
			for f: String in DirAccess.get_files_at(d):
				DirAccess.remove_absolute(d.path_join(f))
			DirAccess.remove_absolute(d)


func _game() -> Node:
	return tree.root.get_node("Game")


func _frames(n: int) -> void:
	for i: int in n:
		await tree.physics_frame


## 開戰鬥場第一波，敵人與席菈停住；第二個敵人搬遠，只留一個當靶。
func _open() -> UndergroundMarket:
	_game().set("session", GameSession.new(QuestDB.load_default(), _dir))
	_game().set("arena_bot", "")
	_game().call("start_arena", false, 0)
	var level: UndergroundMarket = (load(PATH) as PackedScene).instantiate() as UndergroundMarket
	tree.root.add_child(level)
	await tree.physics_frame
	await tree.process_frame
	for e: EnemyActor in level.arena.enemies:
		e.set_physics_process(false)
	var sheila: Node3D = level.get_node_or_null("Sheila") as Node3D
	if sheila != null:
		sheila.set_physics_process(false)
	level.arena.set_physics_process(false)
	level.arena.enemies[1].global_position += Vector3(0.0, 0.0, -8.0)
	return level


func _close(level: UndergroundMarket) -> void:
	level.queue_free()
	await tree.process_frame
	await tree.process_frame


## 站到靶的正前方 dist 公尺（靶在北邊＝-z），身體與鏡頭都朝著他，等動作與速度歸零。
func _face_target(player: PlayerController, e: EnemyActor, dist: float, side: float = 0.0) -> void:
	for a: String in KEYS:
		Input.action_release(a)
	await _frames(45)
	player.global_position = e.global_position + Vector3(side, 0.0, dist)
	player.velocity = Vector3.ZERO
	(player.get_node("Body") as Node3D).rotation.y = 0.0
	player.yaw = 0.0
	await _frames(3)


## 按一下（這一幀按、下一幀放）
func _tap(action: String) -> void:
	Input.action_press(action)
	await tree.physics_frame
	Input.action_release(action)


## 身體的正面跟「往靶的方向」差幾度
func _off_deg(player: PlayerController, e: EnemyActor) -> float:
	var body: Node3D = player.get_node("Body") as Node3D
	var fwd: Vector3 = -body.global_basis.z
	var to: Vector3 = e.global_position - player.global_position
	return rad_to_deg(Vector2(fwd.x, fwd.z).angle_to(Vector2(to.x, to.z)))


func _ratio(player: PlayerController) -> float:
	var p: Puppet = player.puppet()
	return p.action_time / float(Puppet.ACTION_TIME[p.action]) if p.action != "" else 0.0


func test_attack_and_dodge_start_on_the_frame_they_are_pressed() -> void:
	var level: UndergroundMarket = await _open()
	var player: PlayerController = level.arena.player
	var e: EnemyActor = level.arena.enemies[0]
	await _face_target(player, e, 1.5)
	var hp0: float = e.health.hp
	Input.action_press("attack")
	var start: int = -1
	var hit: int = -1
	for i: int in 40:
		await tree.physics_frame
		if i == 0:
			Input.action_release("attack")
		if start < 0 and player.puppet().action == "attack":
			start = i + 1
		if hit < 0 and e.health.hp < hp0:
			hit = i + 1
	print("CONTROLS attack: starts %d frame(s) after the press, lands after %d frames (%.2f s)" % [start, hit, hit / 60.0])
	# 測試裡的按鍵是在物理幀中間按的，引擎從下一幀才算「剛按下」，所以最少是 2；遊戲這邊看到的那一幀就出手，沒有多等
	assert_true(start >= 1 and start <= 2, "看到按鍵的那一幀就開始出手（第 %d 幀）" % start)
	assert_true(hit >= 6 and hit <= 16, "0.1～0.27 秒打到（第 %d 幀）" % hit)
	await _face_target(player, e, 4.0)
	Input.action_press("dodge")
	var dodge_start: int = -1
	var from: Vector3 = player.global_position
	for i: int in 30:
		await tree.physics_frame
		if i == 0:
			Input.action_release("dodge")
		if dodge_start < 0 and player.puppet().action == "dodge":
			dodge_start = i + 1
	var rolled: float = player.global_position.distance_to(from)
	print("CONTROLS dodge: starts %d frame(s) after the press, travels %.2f m" % [dodge_start, rolled])
	assert_true(dodge_start >= 1 and dodge_start <= 2, "看到按鍵的那一幀就開始閃（第 %d 幀）" % dodge_start)
	assert_true(rolled > 2.0 and rolled < 3.6, "閃 2～3.6 m（%.2f）" % rolled)
	await _close(level)


func test_early_presses_are_remembered_in_the_arena_only() -> void:
	var level: UndergroundMarket = await _open()
	var player: PlayerController = level.arena.player
	var e: EnemyActor = level.arena.enemies[0]
	var hold: float = CombatTuning.num("noen.input_buffer")
	assert_true(hold >= 0.15 and hold <= 0.3, "提早按 0.15～0.3 秒內有效（%.2f）" % hold)
	# ①收招的時候按出手：這一下收完馬上接下一下
	await _face_target(player, e, 1.5)
	var hp0: float = e.health.hp
	await _tap("attack")
	var pressed: bool = false
	var hp1: float = hp0
	for i: int in 80:
		await tree.physics_frame
		if not pressed and player.puppet().action == "attack" and _ratio(player) >= 0.72:
			hp1 = e.health.hp
			pressed = true
			Input.action_press("attack")
		elif pressed:
			Input.action_release("attack")
	var chained: bool = pressed and e.health.hp < hp1 - 0.01
	print("CONTROLS buffer: attack pressed during recovery -> %s" % ("second swing lands" if chained else "EATEN"))
	assert_true(hp1 < hp0, "第一下打到了")
	assert_true(chained, "收招時按的出手沒有被吃掉")
	# ②閃到一半按出手：閃完馬上出手
	await _face_target(player, e, 4.5)
	await _tap("dodge")
	pressed = false
	var swung: bool = false
	for i: int in 50:
		await tree.physics_frame
		if not pressed and player.puppet().action == "dodge" and player.puppet().action_time >= 0.2:
			pressed = true
			Input.action_press("attack")
		elif pressed:
			Input.action_release("attack")
			swung = swung or player.puppet().action == "attack"
	print("CONTROLS buffer: attack pressed during a dodge -> %s" % ("swings as the dodge ends" if swung else "EATEN"))
	assert_true(swung, "閃避中按的出手沒有被吃掉")
	# ③挨打硬直快結束的時候按閃避：能動的第一幀就閃
	await _face_target(player, e, 1.5)
	player.health.apply_damage(10.0, {"source": e})
	assert_true(player.hurt_left > 0.0)
	pressed = false
	var dodged: bool = false
	for i: int in 50:
		await tree.physics_frame
		if not pressed and player.hurt_left > 0.0 and player.hurt_left <= 0.15:
			pressed = true
			Input.action_press("dodge")
		elif pressed:
			Input.action_release("dodge")
			dodged = dodged or player.puppet().action == "dodge"
	print("CONTROLS buffer: dodge pressed at the end of hit-stun -> %s" % ("dodges on the first free frame" if dodged else "EATEN"))
	assert_true(dodged, "硬直快結束時按的閃避沒有被吃掉")
	# ④按得太早（硬直一開始就按）不會留到後面才冒出來
	await _face_target(player, e, 1.5)
	var hp2: float = e.health.hp
	player.health.apply_damage(10.0, {"source": e})
	await _tap("attack")
	await _frames(int(CombatTuning.num("noen.hurt_stun") * 60.0) + 20)
	assert_true(absf(e.health.hp - hp2) < 0.01, "超過 %.2f 秒的舊按鍵不算" % hold)
	await _close(level)
	_game().set("arena_mode", false)
	assert_eq(CombatTuning.num("noen.input_buffer"), 0.0, "劇情裡不記（數字沒動）")
	assert_eq(CombatTuning.num("noen.attack_face_lock"), 0.0, "劇情裡出手不鎖方向")


func test_swing_keeps_facing_its_target_while_the_player_keeps_moving() -> void:
	var level: UndergroundMarket = await _open()
	var player: PlayerController = level.arena.player
	var e: EnemyActor = level.arena.enemies[0]
	for key: String in ["move_right", "move_left", "move_back"]:
		await _face_target(player, e, 1.5)
		var hp0: float = e.health.hp
		Input.action_press(key)
		await _frames(6)
		Input.action_press("attack")
		var off: float = 0.0
		for i: int in 34:
			await tree.physics_frame
			if i == 0:
				Input.action_release("attack")
			if player.puppet().action == "attack" and _ratio(player) < 0.35:
				off = absf(_off_deg(player, e))
		Input.action_release(key)
		var landed: bool = e.health.hp < hp0
		print("CONTROLS swing while holding %s: body is %.0f deg off the target when the swing lands -> %s" % [key, off, "hit" if landed else "MISS"])
		assert_true(off < CombatTuning.num("noen.strike_arc_deg") * 0.5, "按著 %s 出手：判定的時候還對著他（差 %.0f 度）" % [key, off])
		assert_true(landed, "按著 %s 出手：貼著的敵人打得到" % key)
	await _close(level)


func test_walk_start_stop_turn_and_camera_numbers() -> void:
	var level: UndergroundMarket = await _open()
	var player: PlayerController = level.arena.player
	var e: EnemyActor = level.arena.enemies[0]
	# 起步、停下：往南（背對敵人）走
	await _face_target(player, e, 5.0)
	Input.action_press("move_back")
	var up: int = -1
	for i: int in 40:
		await tree.physics_frame
		if up < 0 and Vector2(player.velocity.x, player.velocity.z).length() >= PlayerController.WALK_SPEED * 0.9:
			up = i + 1
	Input.action_release("move_back")
	var at: Vector3 = player.global_position
	var down: int = -1
	for i: int in 40:
		await tree.physics_frame
		if down < 0 and Vector2(player.velocity.x, player.velocity.z).length() <= PlayerController.WALK_SPEED * 0.1:
			down = i + 1
	var slid: float = player.global_position.distance_to(at)
	print("CONTROLS walk: %.1f m/s (sprint %.1f); 90%% speed after %d frames (%.2f s); after release stops in %d frames, slides %.2f m" % [PlayerController.WALK_SPEED, PlayerController.SPRINT_SPEED, up, up / 60.0, down, slid])
	assert_true(up > 0 and up <= 15, "0.25 秒內到九成速度（第 %d 幀）" % up)
	assert_true(down > 0 and slid < 0.45, "放開之後滑不到 0.45 m（%.2f）" % slid)
	# 轉身：面向北，往南走，身體轉過 150 度要幾幀
	await _face_target(player, e, 5.0)
	var body: Node3D = player.get_node("Body") as Node3D
	Input.action_press("move_back")
	var turned: int = -1
	for i: int in 40:
		await tree.physics_frame
		if turned < 0 and absf(wrapf(body.rotation.y, -PI, PI)) >= deg_to_rad(150.0):
			turned = i + 1
	Input.action_release("move_back")
	print("CONTROLS turn: 180 deg about-face reaches 150 deg after %d frames (%.2f s)" % [turned, turned / 60.0])
	assert_true(turned > 0 and turned <= 24, "0.4 秒內轉過身（第 %d 幀）" % turned)
	# 鏡頭：戰鬥中（沒鎖定）拉遠之後，人佔畫面多高
	await _face_target(player, e, 3.0)
	await _frames(60)
	var cam: Camera3D = player.get_node("CameraRig/Pitch/SpringArm3D/Camera3D") as Camera3D
	var depth: float = (player.global_position + Vector3.UP * BODY_HEIGHT * 0.5 - cam.global_position).dot(-cam.global_basis.z)
	var share: float = BODY_HEIGHT / (2.0 * depth * tan(deg_to_rad(cam.fov) * 0.5))
	print("CONTROLS camera (combat, no lock): arm %.2f m, vertical fov %.0f, Noen fills %.0f%% of the screen height" % [player.camera_distance(), cam.fov, share * 100.0])
	assert_true(share > 0.2 and share < 0.6, "人佔畫面高度 20%%～60%%（%.0f%%）" % (share * 100.0))
	await _close(level)
