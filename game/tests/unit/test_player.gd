extends TestCase
## 玩家移動的純函式部分。


func _approx(a: Vector3, b: Vector3) -> bool:
	return a.distance_to(b) < 0.001


func test_move_direction_follows_camera_yaw() -> void:
	assert_true(_approx(PlayerController.move_direction(Vector2(0, -1), 0.0), Vector3(0, 0, -1)), "鏡頭朝 -Z 時按前進往 -Z")
	assert_true(_approx(PlayerController.move_direction(Vector2(1, 0), 0.0), Vector3(1, 0, 0)), "右")
	# 鏡頭左轉 90°（yaw = +PI/2）時，前進變成往 -X
	assert_true(_approx(PlayerController.move_direction(Vector2(0, -1), PI / 2.0), Vector3(-1, 0, 0)), "轉向後前進")


func test_diagonal_is_not_faster() -> void:
	var d: Vector3 = PlayerController.move_direction(Vector2(1, -1), 0.3)
	assert_true(d.length() <= 1.0001, "斜走不會比直走快")
