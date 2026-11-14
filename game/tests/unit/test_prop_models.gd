extends TestCase
## 現成素材（CC0）的接入點：找得到就用現成的模型，找不到就退回程式拼的。
## 席菈的劍是第一個換的（KayKit 的雙手劍，game/assets/props/kaykit/）。


func test_missing_prop_returns_null() -> void:
	assert_eq(PropModels.scene_for("kaykit/nothing_here"), null, "沒有這個檔")
	assert_eq(PropModels.scene_for(""), null)
	assert_eq(PropModels.instance("kaykit/nothing_here"), null)


func _mesh_count(n: Node) -> int:
	var c: int = 1 if n is MeshInstance3D and (n as MeshInstance3D).mesh != null else 0
	for child: Node in n.get_children():
		c += _mesh_count(child)
	return c
