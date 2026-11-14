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


func test_missing_dodge_falls_back_to_roll() -> void:
	var p: Puppet = _puppet(_fake_model(["Armature|idle"], true, ""))
	assert_eq(p.model_animation, "Armature|idle", "glTF 前綴也找得到")
	assert_eq((p.hand("R").get_parent() as BoneAttachment3D).bone_name, "RightHand", "沒有 mixamorig 前綴的骨骼名")
	p.play_action("dodge")
	p.advance(0.15)
	var roll: Node3D = p.get_node("Roll") as Node3D
	assert_true(absf(roll.rotation.x) > 0.5, "沒有 dodge_roll：整個人前滾（%.2f）" % roll.rotation.x)
	assert_eq(p.model_animation, "Armature|idle", "其他動作退回 idle")
	p.advance(0.5)
	assert_true(absf(roll.rotation.x) < 0.001, "滾完回正")
	p.queue_free()
	await tree.process_frame


## 循環動作的 `_loop` 結尾也認得（席菈試作的 GLB 走路叫 walk_loop）；照樣循環播放
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


## ：模型有 `release` 這段動作 → 釋放的那 0.36 秒播它，播完回到原本的狀態；滾到一半不播；沒有這段動作就照舊。
func test_model_plays_release_animation() -> void:
	var p: Puppet = _puppet(_fake_model(["idle", "run", "light_attack_01", "release"]))
	p.advance(0.016)
	assert_eq(p.model_animation, "idle")
	p.play_release()
	p.advance(0.016)
	assert_eq(p.model_animation, "release", "釋放的那一下播 release")
	p.advance(Puppet.RELEASE_POSE_TIME)
	p.advance(0.016)
	assert_eq(p.model_animation, "idle", "播完回到站著")
	p.play_action("dodge")
	p.play_release()
	p.advance(0.016)
	assert_ne(p.model_animation, "release", "滾到一半不擺釋放的姿勢")
	p.queue_free()
	var plain: Puppet = _puppet(_fake_model(["idle", "run"]))
	plain.play_release()
	plain.advance(0.016)
	assert_eq(plain.model_animation, "idle", "模型沒有 release：照舊播原本的動作")
	plain.queue_free()
	await tree.process_frame


## 有一條右手臂的假模型（T 字站姿：手臂沿著 +X）。前臂骨頭自己的軸故意轉過（VRM 轉來的骨頭軸不沿著骨頭）。
func _arm_model() -> PackedScene:
	var root := Node3D.new()
	root.name = "ArmModel"
	var sk := Skeleton3D.new()
	sk.name = "Skeleton3D"
	root.add_child(sk)
	sk.owner = root
	var twisted := Basis(Vector3(0, 0, 1), 0.7) * Basis(Vector3(1, 0, 0), -0.4)
	var bones: Array = [
		["Hips", -1, Transform3D(Basis.IDENTITY, Vector3(0, 1.0, 0))],
		["RightUpperArm", 0, Transform3D(Basis.IDENTITY, Vector3(0.2, 0.4, 0))],
		["RightLowerArm", 1, Transform3D(twisted, Vector3(0.3, 0, 0))],
		["RightHand", 2, Transform3D(Basis.IDENTITY, twisted.inverse() * Vector3(0.25, 0, 0))],
		["LeftHand", 0, Transform3D(Basis.IDENTITY, Vector3(-0.75, 0.4, 0))],
	]
	for b: Array in bones:
		var i: int = sk.add_bone(str(b[0]))
		sk.set_bone_parent(i, int(b[1]))
		sk.set_bone_rest(i, b[2] as Transform3D)
	sk.reset_bone_poses()
	var scene := PackedScene.new()
	scene.pack(root)
	root.free()
	return scene


## ：模型沒有人偶的關節 → joint() 給對應骨頭上的掛點，方向跟人偶的關節一樣（−Y 往下一節、−Z 朝前），
## 所以護腕（掛在 elbow_R 底下、往下擺）不用分人偶還是模型。
func test_lit_models_override_unlit_materials() -> void:
	var root := Node3D.new()
	root.name = "FakeModel"
	var sk := Skeleton3D.new()
	sk.name = "Skeleton3D"
	root.add_child(sk)
	sk.owner = root
	sk.add_bone("Hips")
	var mi := MeshInstance3D.new()
	mi.name = "Body"
	var mesh := BoxMesh.new()
	var src := StandardMaterial3D.new()
	src.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	src.albedo_color = Color(0.3, 0.2, 0.1)
	mesh.material = src
	mi.mesh = mesh
	sk.add_child(mi)
	mi.owner = root
	var scene := PackedScene.new()
	scene.pack(root)
	root.free()
	var was: bool = Puppet.lit_models
	assert_true(was, "預設吃場景的光（D-255）")
	Puppet.lit_models = false
	var plain: Puppet = _puppet(scene)
	var plain_mi: MeshInstance3D = plain.model.find_child("Body", true, false) as MeshInstance3D
	assert_true(plain_mi.get_surface_override_material(0) == null, "關掉：不動材質")
	assert_eq((plain_mi.get_active_material(0) as BaseMaterial3D).shading_mode, BaseMaterial3D.SHADING_MODE_UNSHADED, "關掉：照原檔不受光")
	Puppet.lit_models = true
	var lit: Puppet = _puppet(scene)
	Puppet.lit_models = was
	var lit_mi: MeshInstance3D = lit.model.find_child("Body", true, false) as MeshInstance3D
	var m: BaseMaterial3D = lit_mi.get_surface_override_material(0) as BaseMaterial3D
	assert_not_null(m, "受光：每個 surface 蓋一份複本")
	assert_eq(m.shading_mode, BaseMaterial3D.SHADING_MODE_PER_PIXEL)
	assert_eq(m.diffuse_mode, BaseMaterial3D.DIFFUSE_TOON, "平塗")
	assert_eq(m.specular_mode, BaseMaterial3D.SPECULAR_DISABLED)
	assert_eq(m.albedo_color, Color(0.3, 0.2, 0.1), "顏色照原本的")
	assert_eq((plain_mi.get_active_material(0) as BaseMaterial3D).shading_mode, BaseMaterial3D.SHADING_MODE_UNSHADED, "另一個角色不受影響（材質是複本）")
	plain.queue_free()
	lit.queue_free()
	await tree.process_frame


## 只有骨盆、頭、兩肩的假模型；front_z＝臉朝哪邊（−1＝Godot 的正面，+1＝glTF 的慣例）。
func _facing_model(front_z: float) -> PackedScene:
	var root := Node3D.new()
	root.name = "FacingModel"
	var sk := Skeleton3D.new()
	sk.name = "Skeleton3D"
	root.add_child(sk)
	sk.owner = root
	# 臉朝 −Z 的人右手在 +X；臉朝 +Z 的人右手在 −X
	var right_x: float = -front_z * 0.2
	var bones: Array = [
		["Hips", Vector3(0, 0.9, 0)], ["Head", Vector3(0, 0.6, 0)],
		["LeftUpperArm", Vector3(-right_x, 0.45, 0)], ["RightUpperArm", Vector3(right_x, 0.45, 0)],
		["LeftLowerArm", Vector3(-right_x, -0.25, 0)], ["RightLowerArm", Vector3(right_x, -0.25, 0)],
		["LeftHand", Vector3(0, -0.25, 0)], ["RightHand", Vector3(0, -0.25, 0)],
	]
	var parents: Dictionary = {"LeftLowerArm": "LeftUpperArm", "RightLowerArm": "RightUpperArm", "LeftHand": "LeftLowerArm", "RightHand": "RightLowerArm"}
	for b: Array in bones:
		var i: int = sk.add_bone(str(b[0]))
		var parent: String = str(parents.get(str(b[0]), "Hips"))
		if i > 0:
			sk.set_bone_parent(i, sk.find_bone(parent))
		var at: Vector3 = b[1] as Vector3
		if parents.has(str(b[0])) and parent.ends_with("UpperArm"):
			at.x = 0.0
		sk.set_bone_rest(i, Transform3D(Basis.IDENTITY, at))
	sk.reset_bone_poses()
	var scene := PackedScene.new()
	scene.pack(root)
	root.free()
	return scene


## 模型臉朝 +Z（glTF 的慣例）就自動轉半圈：身體的正面永遠是 −Z，掛在手上的東西也跟著對。
func test_backward_model_is_turned_to_face_forward() -> void:
	var ok: Puppet = _puppet(_facing_model(-1.0))
	assert_true(ok.uses_model())
	assert_true(CharacterModels.facing(ok.skeleton, ok.model).z < -0.9, "假模型臉朝 −Z")
	assert_true(absf(ok.model.rotation.y) < 0.001, "臉朝 −Z 的模型不轉")
	var flipped: Puppet = _puppet(_facing_model(1.0))
	assert_true(CharacterModels.facing(flipped.skeleton, flipped.model).z > 0.9, "假模型臉朝 +Z")
	assert_true(absf(absf(flipped.model.rotation.y) - PI) < 0.001, "臉朝 +Z 的模型轉半圈")
	await tree.process_frame
	for p: Puppet in [ok, flipped]:
		# 掛點的 −Z 朝角色的前面（世界的 −Z）、右手在世界的 +X——兩種模型都一樣
		var hand: Node3D = p.hand("R")
		assert_true(hand != null)
		assert_true((-hand.global_basis.z).dot(Vector3.FORWARD) > 0.9, "手的掛點 −Z 朝前（%s）" % str(-hand.global_basis.z))
		assert_true(hand.global_position.x > 0.05, "右手在右邊（x=%.2f）" % hand.global_position.x)
		var hips: Node3D = p.joint("hips")
		assert_true((-hips.global_basis.z).dot(Vector3.FORWARD) > 0.9, "骨盆的掛點 −Z 朝前")
		p.queue_free()
	await tree.process_frame
	# 量不出來（缺骨頭）就不轉
	var bare: Puppet = _puppet(_fake_model(["idle"]))
	assert_eq(CharacterModels.facing(bare.skeleton, bare.model), Vector3.ZERO)
	assert_true(absf(bare.model.rotation.y) < 0.001)
	bare.queue_free()
	await tree.process_frame


## 建置出來的模型（有的話）：站著與每一段動作，臉都朝身體的正面（−Z）——走路、跑步、出手不會整個人轉過去。
## 沒有模型（CI 裝不了 bpy）就略過。閃避是整個人滾一圈，不算。
func test_built_models_face_forward_in_every_clip() -> void:
	for id: String in ["noen", "sheila"]:
		var scene: PackedScene = CharacterModels.scene_for(id)
		if scene == null:
			continue
		var p: Puppet = _puppet(scene)
		assert_true(p.uses_model(), id)
		await tree.process_frame
		var rest: Vector3 = p.model.basis * CharacterModels.facing(p.skeleton, p.model)
		assert_true(rest.z < -0.9, "%s 站著臉朝 −Z（%s）" % [id, str(rest)])
		if p.anim == null:
			p.queue_free()
			continue
		for clip: String in p.anim.get_animation_list():
			if clip.to_lower().contains("dodge") or clip == "RESET":
				continue
			var worst: float = -1.0
			var length: float = p.anim.get_animation(clip).length
			p.anim.play(clip)
			for k: int in 9:
				p.anim.seek(length * float(k) / 8.0, true)
				p.anim.advance(0.0)
				p.skeleton.force_update_all_bone_transforms()
				worst = maxf(worst, (p.model.basis * CharacterModels.facing(p.skeleton, p.model, true)).z)
			print("FACING %s %s: worst z %.2f (−1 = straight ahead)" % [id, clip, worst])
			assert_true(worst < -0.2, "%s 的 %s：臉沒有轉到背後（z 最大 %.2f）" % [id, clip, worst])
		p.queue_free()
		await tree.process_frame
