extends TestCase
## 提燈照不出諾恩自己的影子（D-118）：原本諾恩把左手的提燈擋住，畫面下半一大片黑楔形。


func test_lantern_does_not_shadow_noen() -> void:
	var root := Node3D.new()
	tree.root.add_child(root)
	var player: PlayerController = (load("res://scenes/actors/player/player.tscn") as PackedScene).instantiate() as PlayerController
	root.add_child(player)
	var light: OmniLight3D = player.find_child("LanternLight", true, false) as OmniLight3D
	assert_not_null(light, "有提燈的光")
	assert_true(light.shadow_enabled, "提燈照樣投牆、席菈、敵人的影子")
	assert_eq(light.shadow_caster_mask & PlayerController.SELF_LAYER, 0, "諾恩那一層不投提燈的影子")
	assert_true((light.shadow_caster_mask & 1) != 0, "第 1 層（場景、其他角色）照樣投影")
	var geoms: Array[Node] = player.get_node("Body").find_children("*", "GeometryInstance3D", true, false)
	assert_true(geoms.size() >= 6, "諾恩身上有人偶的幾何（%d 個）" % geoms.size())
	for g: Node in geoms:
		var layers: int = (g as GeometryInstance3D).layers
		assert_true((layers & PlayerController.SELF_LAYER) != 0, "%s 在諾恩那一層" % g.name)
		assert_true((layers & 1) != 0, "%s 照樣在第 1 層（鏡頭、月光、路燈看得到）" % g.name)
	# 之後才加到身上的東西（夾板、換上的模型）
	var extra := MeshInstance3D.new()
	extra.mesh = BoxMesh.new()
	player.get_node("Body").add_child(extra)
	assert_true((extra.layers & PlayerController.SELF_LAYER) != 0, "之後加上的幾何也在諾恩那一層")
	root.queue_free()
	await tree.process_frame
