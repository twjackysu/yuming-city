extends TestCase
## 角色模型接入點（04-architecture）：Puppet 有模型就用模型＋AnimationPlayer，沒有就用程序人偶。
## 用程式組一個最小的「有骨架、有動作」的模型場景代替真的 GLB。


func _fake_model(anims: PackedStringArray, with_skeleton: bool = true, hand_prefix: String = "mixamorig_") -> PackedScene:
	var root := Node3D.new()
	root.name = "FakeModel"
	if with_skeleton:
		var sk := Skeleton3D.new()
		sk.name = "Skeleton3D"
		root.add_child(sk)
		sk.owner = root
		sk.add_bone(hand_prefix + "Hips")
		sk.add_bone(hand_prefix + "LeftHand")
		sk.set_bone_parent(1, 0)
		sk.set_bone_rest(1, Transform3D(Basis.IDENTITY, Vector3(-0.3, 0.0, 0.0)))
		sk.add_bone(hand_prefix + "RightHand")
		sk.set_bone_parent(2, 0)
		sk.set_bone_rest(2, Transform3D(Basis.IDENTITY, Vector3(0.3, 0.0, 0.0)))
	var ap := AnimationPlayer.new()
	ap.name = "AnimationPlayer"
	root.add_child(ap)
	ap.owner = root
	var lib := AnimationLibrary.new()
	for n: String in anims:
		var a := Animation.new()
		a.length = 1.0
		lib.add_animation(StringName(n), a)
	ap.add_animation_library(&"", lib)
	var scene := PackedScene.new()
	scene.pack(root)
	root.free()
	return scene


func _puppet(scene: PackedScene) -> Puppet:
	var p := Puppet.new()
	p.model_scene = scene
	tree.root.add_child(p)
	return p


func test_no_model_uses_procedural_puppet() -> void:
	assert_eq(CharacterModels.scene_for("nobody"), null, "沒有匯入的模型")
	assert_eq(CharacterModels.scene_for(""), null)
	var p := Puppet.new()
	p.character_id = "nobody"
	tree.root.add_child(p)
	assert_false(p.uses_model())
	assert_true(p.joint("hips") != null, "程序人偶的關節")
	assert_true(p.hand("R").has_node("BellHammer"), "右手有鐘錘")
	p.queue_free()
	await tree.process_frame


func test_model_drives_animations_by_state() -> void:
	var p: Puppet = _puppet(_fake_model(["idle", "walk", "run", "light_attack_01"]))
	assert_true(p.uses_model(), "有骨架的模型")
	assert_eq(p.joint("hips"), null, "不建程序人偶")
	assert_true(p.hand("L") is BoneAttachment3D, "左手掛點是骨骼附著點")
	assert_eq((p.hand("L") as BoneAttachment3D).bone_name, "mixamorig_LeftHand", "Godot 匯入 Mixamo 骨骼名（冒號變底線）")
	assert_true(p.hand("R").has_node("BellHammer"), "鐘錘掛在右手骨骼")
	assert_eq(p.model_animation, "idle")
	assert_eq(p.anim.get_animation("walk").loop_mode, Animation.LOOP_LINEAR, "走路循環")
	p.set_move_speed(1.6)
	p.advance(0.05)
	assert_eq(p.model_animation, "walk")
	p.set_move_speed(5.8)
	p.advance(0.05)
	assert_eq(p.model_animation, "run")
	p.play_action("attack")
	p.advance(0.05)
	assert_eq(p.model_animation, "light_attack_01")
	p.advance(1.0)
	assert_eq(p.model_animation, "run", "攻擊播完回到移動")
	p.queue_free()
	await tree.process_frame


func test_missing_dodge_falls_back_to_roll() -> void:
	var p: Puppet = _puppet(_fake_model(["Armature|idle"], true, ""))
	assert_eq(p.model_animation, "Armature|idle", "glTF 前綴也找得到")
	assert_eq((p.hand("R") as BoneAttachment3D).bone_name, "RightHand", "沒有 mixamorig 前綴的骨骼名")
	p.play_action("dodge")
	p.advance(0.15)
	var roll: Node3D = p.get_node("Roll") as Node3D
	assert_true(absf(roll.rotation.x) > 0.5, "沒有 dodge_roll：整個人前滾（%.2f）" % roll.rotation.x)
	assert_eq(p.model_animation, "Armature|idle", "其他動作退回 idle")
	p.advance(0.5)
	assert_true(absf(roll.rotation.x) < 0.001, "滾完回正")
	p.queue_free()
	await tree.process_frame


## 循環動作的 `_loop` 結尾也認得（D-140：席菈試作的 GLB 走路叫 walk_loop）；照樣循環播放
func test_loop_suffixed_animations_are_found() -> void:
	var p: Puppet = _puppet(_fake_model(["Armature|idle_loop", "Armature|walk_loop"], true, ""))
	assert_eq(p.model_animation, "Armature|idle_loop", "idle_loop 當 idle")
	p.set_move_speed(1.6)
	p.advance(0.05)
	assert_eq(p.model_animation, "Armature|walk_loop", "walk_loop 當 walk")
	assert_eq(p.anim.get_animation("Armature|walk_loop").loop_mode, Animation.LOOP_LINEAR, "走路循環")
	p.queue_free()
	await tree.process_frame


func test_model_without_skeleton_is_rejected() -> void:
	var p: Puppet = _puppet(_fake_model(["idle"], false))
	assert_false(p.uses_model(), "沒有骨架的模型不用")
	assert_true(p.joint("hips") != null, "退回程序人偶")
	p.queue_free()
	await tree.process_frame
