extends TestCase
## 現成素材（CC0）的接入點（D-256）：找得到就用現成的模型，找不到就退回程式拼的。
## 席菈的劍是第一個換的（KayKit 的雙手劍，game/assets/props/kaykit/）。


func test_missing_prop_returns_null() -> void:
	assert_eq(PropModels.scene_for("kaykit/nothing_here"), null, "沒有這個檔")
	assert_eq(PropModels.scene_for(""), null)
	assert_eq(PropModels.instance("kaykit/nothing_here"), null)


func test_sword_model_is_in_the_project() -> void:
	assert_eq(PropModels.path_for(Sheila.SWORD_MODEL), "res://assets/props/kaykit/sword_2handed.gltf")
	var sword: Node3D = PropModels.instance(Sheila.SWORD_MODEL)
	assert_true(sword != null, "現成的劍匯入過（檔案在 git 裡）")
	if sword == null:
		return
	assert_true(_mesh_count(sword) > 0, "有網格")
	sword.free()


## 席菈手上掛的是現成的模型（而且還是掛在 BrokenSword 底下——護手與方向的程式沒變）
func test_sheila_holds_the_ready_made_sword() -> void:
	var sheila := Sheila.new()
	tree.root.add_child(sheila)
	sheila.set_physics_process(false)  # 只看外觀：沒有 leader 的話 _move() 會出錯
	await tree.process_frame
	var sword: Node3D = sheila.find_child("BrokenSword", true, false) as Node3D
	assert_true(sword != null, "右手上有劍")
	if sword != null:
		var model: Node3D = sword.get_node_or_null("Model") as Node3D
		assert_true(model != null, "用現成的模型")
		if model != null:
			assert_true(_mesh_count(model) > 0, "模型有網格")
			assert_true(absf(model.scale.x - Sheila.SWORD_MODEL_SCALE) < 0.001, "縮到配她的身高")
	sheila.queue_free()
	await tree.process_frame


func _mesh_count(n: Node) -> int:
	var c: int = 1 if n is MeshInstance3D and (n as MeshInstance3D).mesh != null else 0
	for child: Node in n.get_children():
		c += _mesh_count(child)
	return c
