extends TestCase
## 諾恩的普通攻擊射火球（Jacky 2026-11-14）。


class Dummy:
	extends Node3D
	var health: Health

	func _init() -> void:
		health = Health.new()
		health.name = "Health"
		add_child(health)
		add_to_group("damageable")


func _player(root: Node3D) -> PlayerController:
	var player: PlayerController = (load("res://scenes/actors/player/player.tscn") as PackedScene).instantiate() as PlayerController
	root.add_child(player)
	return player


func test_attack_shoots_a_fireball_that_hits_a_far_enemy_once() -> void:
	var root := Node3D.new()
	tree.root.add_child(root)
	var player: PlayerController = _player(root)
	if player.staff() == null:
		root.queue_free()
		await tree.process_frame
		return  # 沒有法杖的模型（素材沒產生）：不射火球
	var foe := Dummy.new()
	root.add_child(foe)
	foe.global_position = player.global_position + (-player.get_node("Body").global_basis.z) * 8.0
	var before: float = foe.health.hp
	var near_hits: int = player.strike()
	assert_eq(near_hits, 0, "8 m 外近身那一下打不到")
	assert_eq(player.fireballs_cast, 1, "出手就射一顆火球")
	var ball: Fireball = player.last_fireball
	assert_not_null(ball)
	var hit: bool = false
	for i: int in 120:
		if ball.advance(1.0 / 60.0):
			hit = true
			break
	assert_true(hit, "火球飛到 8 m 外的敵人")
	assert_true(foe.health.hp < before, "敵人扣血（%.0f → %.0f）" % [before, foe.health.hp])
	var after: float = foe.health.hp
	ball.advance(1.0 / 60.0)
	assert_eq(foe.health.hp, after, "一顆火球只打一次")
	root.queue_free()
	await tree.process_frame


func test_enemy_struck_up_close_is_not_hit_twice() -> void:
	var root := Node3D.new()
	tree.root.add_child(root)
	var player: PlayerController = _player(root)
	var foe := Dummy.new()
	root.add_child(foe)
	foe.global_position = player.global_position + (-player.get_node("Body").global_basis.z) * 1.0
	var before: float = foe.health.hp
	assert_eq(player.strike(), 1, "近身打到")
	var once: float = before - foe.health.hp
	if player.last_fireball != null:
		for i: int in 60:
			player.last_fireball.advance(1.0 / 60.0)
	assert_eq(before - foe.health.hp, once, "近身已經打到的人不會再被同一下的火球打到")
	root.queue_free()
	await tree.process_frame


func test_fireball_fizzles_at_max_range() -> void:
	var root := Node3D.new()
	tree.root.add_child(root)
	var ball: Fireball = Fireball.create(null, Vector3.FORWARD, 6.0, 20.0, [])
	root.add_child(ball)
	for i: int in 200:
		ball.advance(1.0 / 60.0)
	assert_true(ball.traveled >= Fireball.MAX_RANGE, "飛滿射程")
	assert_true(ball.is_queued_for_deletion(), "沒打到人就熄掉")
	root.queue_free()
	await tree.process_frame
