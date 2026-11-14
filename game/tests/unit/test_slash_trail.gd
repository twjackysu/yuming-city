extends TestCase
## 揮劍的劍光（SlashTrail）：帶子的形狀、劍尖在哪裡、諾恩出手時有沒有畫出來、顏色與大小跟不跟著狀態與連段。


func test_ribbon_stays_round_between_two_samples() -> void:
	# 劍從朝上轉到朝前（90 度），中間沒有別的取樣：外緣每一點離手都是劍長，不是切過去的一條弦（弦的中點只有 0.71）
	var hands := PackedVector3Array([Vector3.ZERO, Vector3.ZERO])
	var tips := PackedVector3Array([Vector3.UP, Vector3.FORWARD])
	var built: Array = SlashTrail.ribbon(hands, tips, Vector2(0.5, 1.0))
	var pts: PackedVector3Array = built[0]
	var along: PackedFloat32Array = built[1]
	assert_true(pts.size() >= 2 * (int(90.0 / SlashTrail.STEP_DEG) + 1), "90 度補了很多段（%d 點）" % pts.size())
	assert_eq(pts.size(), along.size() * 2, "一對一對，每一對有一個位置")
	for i: int in along.size():
		assert_true(absf(pts[i * 2].length() - 0.5) < 0.001, "內緣離手 0.5（第 %d 對：%.3f）" % [i, pts[i * 2].length()])
		assert_true(absf(pts[i * 2 + 1].length() - 1.0) < 0.001, "外緣離手 1.0（第 %d 對：%.3f）" % [i, pts[i * 2 + 1].length()])
		assert_true(i == 0 or along[i] > along[i - 1], "位置一路往後")
	assert_true(pts[1].is_equal_approx(Vector3.UP), "從第一個取樣開始")
	assert_true(pts[pts.size() - 1].is_equal_approx(Vector3.FORWARD), "到最後一個取樣結束")
	assert_eq(along[0], 0.0)
	assert_eq(along[along.size() - 1], 1.0, "最後一對落在第二個取樣")
	var one: Array = SlashTrail.ribbon(PackedVector3Array([Vector3.ZERO]), PackedVector3Array([Vector3.UP]), Vector2(0, 1))
	assert_eq((one[0] as PackedVector3Array).size(), 2, "只有一個取樣＝一對點，畫不出面")


func test_blade_tip_is_the_far_end_of_the_longest_axis() -> void:
	var weapon := Node3D.new()
	var model := Node3D.new()
	model.rotation_degrees = Vector3(0, 0, 180)
	model.scale = Vector3.ONE * 0.5
	var blade := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.1, 2.0, 0.02)
	blade.mesh = box
	blade.position = Vector3(0, 0.8, 0)  # 模型自己的座標：握把在下、劍身往上到 1.8
	model.add_child(blade)
	weapon.add_child(model)
	var tip: Vector3 = PlayerController.blade_tip(weapon)
	assert_true(tip.is_equal_approx(Vector3(0, -0.9, 0)), "轉了半圈、縮成一半：劍尖在 −Y 0.9（%s）" % tip)
	var empty := Node3D.new()
	assert_eq(PlayerController.blade_tip(empty), Vector3.ZERO, "沒有網格")
	empty.free()
	weapon.free()


## 諾恩砍一刀：揮的那一段有劍光、貼著劍、揮完淡掉；第一刀是鏽色，身上有反轉中的狀態之後是金的；收尾那一刀比較大。
func test_swing_draws_a_trail_rust_then_gold_and_bigger_on_the_finisher() -> void:
	var root := Node3D.new()
	tree.root.add_child(root)
	var player: PlayerController = (load("res://scenes/actors/player/player.tscn") as PackedScene).instantiate() as PlayerController
	root.add_child(player)
	await tree.physics_frame
	var first: SlashTrail = player.slash_trail()
	assert_not_null(first, "手上有劍就有劍光")
	assert_false(first.visible, "沒出手的時候看不到")
	var tints: Array[Color] = []
	var widths: Array[float] = []
	for swing: int in 3:
		player.start_attack()
		var trail: SlashTrail = null
		var seen: bool = false
		var widest: float = 0.0
		for i: int in 90:
			await tree.process_frame
			trail = player.slash_trail()
			if trail.visible and trail.sample_count() >= 3:
				seen = true
				widest = maxf(widest, trail.mesh.get_aabb().get_longest_axis_size())
			if seen and not trail.recording:
				break
		assert_true(seen, "第 %d 刀：揮的那一段看得到劍光" % (swing + 1))
		var mat: ShaderMaterial = trail.material_override as ShaderMaterial
		tints.append(mat.get_shader_parameter("tint") as Color)
		widths.append(widest)
		assert_true(widest > 0.5, "第 %d 刀：弧有大小（%.2f m）" % [swing + 1, widest])
		if swing == 0:
			var swish: AudioStream = Sfx.stream("slash")
			var heard: int = 0
			for c: Node in player.get_children():
				if c is AudioStreamPlayer3D and (c as AudioStreamPlayer3D).stream == swish:
					heard += 1
			assert_eq(heard, 1, "揮出去有一聲（沒砍到東西也有）")
			# 揮完之後淡掉
			for i: int in 40:
				await tree.process_frame
			assert_false(trail.visible, "揮完就消失")
			assert_eq(trail.sample_count(), 0, "每一段都過了壽命")
			player.status_effects.apply_source("rusty_sword_cut")
		# 等這一刀收招，在連段的時間內接下一刀
		for i: int in 60:
			if player.puppet().action != "attack":
				break
			await tree.physics_frame
	assert_eq(tints[0], SlashTrail.RUST_TINT, "身上沒有狀態：鏽色")
	assert_eq(tints[1], SlashTrail.GOLD_TINT, "身上有反轉中的狀態：金色")
	assert_true(player.is_finisher(), "第三刀是收尾")
	assert_true(widths[2] > widths[1] * 1.15, "收尾那一刀的弧最大（%.2f 對 %.2f）" % [widths[2], widths[1]])
	root.queue_free()
	await tree.process_frame
