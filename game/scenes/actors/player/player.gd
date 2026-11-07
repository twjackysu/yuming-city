class_name PlayerController
extends CharacterBody3D
## 諾恩：第三人稱移動＋越肩鏡頭（docs/design/02-gameplay.md「鏡頭」）。
## 鏡頭架（CameraRig）設 top_level，自己跟隨玩家，避免角色轉身時鏡頭跟著甩。

const WALK_SPEED: float = 3.4
const SPRINT_SPEED: float = 5.8
const ACCEL: float = 12.0
const TURN_SPEED: float = 10.0
const GRAVITY: float = 18.0
const DODGE_SPEED: float = 8.5
const DODGE_TIME: float = 0.35
const DODGE_INVULN: float = 0.25
const DODGE_COOLDOWN: float = 0.2
const MOUSE_SENS: float = 0.0025
const PAD_LOOK_SPEED: float = 2.8
const PAD_DEADZONE: float = 0.15
const PITCH_MIN: float = deg_to_rad(-55.0)
const PITCH_MAX: float = deg_to_rad(40.0)
const CAMERA_HEIGHT: float = 1.6
const FOV_WALK: float = 70.0
const FOV_SPRINT: float = 75.0

var yaw: float = 0.0
var pitch: float = -0.18
var invulnerable: bool = false

var _dodge_left: float = 0.0
var _dodge_cooldown: float = 0.0
var _dodge_dir: Vector3 = Vector3.ZERO

@onready var _rig: Node3D = $CameraRig
@onready var _pitch_node: Node3D = $CameraRig/Pitch
@onready var _arm: SpringArm3D = $CameraRig/Pitch/SpringArm3D
@onready var _camera: Camera3D = $CameraRig/Pitch/SpringArm3D/Camera3D
@onready var _body: Node3D = $Body


func _ready() -> void:
	_rig.top_level = true
	_arm.add_excluded_object(get_rid())
	yaw = rotation.y
	_snap_rig()
	_camera.current = true


## 把輸入（x=左右，y=前後，前為負）依鏡頭水平角度轉成世界方向。純函式，方便測試。
static func move_direction(input: Vector2, camera_yaw: float) -> Vector3:
	var dir := Basis(Vector3.UP, camera_yaw) * Vector3(input.x, 0.0, input.y)
	if dir.length() > 1.0:
		dir = dir.normalized()
	return dir


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		_add_look(Vector2(-motion.relative.x, -motion.relative.y) * MOUSE_SENS)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _add_look(delta_look: Vector2) -> void:
	yaw = wrapf(yaw + delta_look.x, -PI, PI)
	pitch = clampf(pitch + delta_look.y, PITCH_MIN, PITCH_MAX)


func _physics_process(delta: float) -> void:
	var pad := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if pad.length() > PAD_DEADZONE:
		_add_look(-pad * PAD_LOOK_SPEED * delta)

	var input: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir: Vector3 = move_direction(input, yaw)
	var sprinting: bool = Input.is_action_pressed("sprint") and input.length() > 0.1

	_dodge_cooldown = maxf(_dodge_cooldown - delta, 0.0)
	if Input.is_action_just_pressed("dodge") and _dodge_left <= 0.0 and _dodge_cooldown <= 0.0:
		_dodge_dir = dir if dir.length() > 0.1 else -_body.global_basis.z
		_dodge_dir = _dodge_dir.normalized()
		_dodge_left = DODGE_TIME

	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	if _dodge_left > 0.0:
		_dodge_left -= delta
		invulnerable = _dodge_left > DODGE_TIME - DODGE_INVULN
		horizontal = _dodge_dir * DODGE_SPEED
		if _dodge_left <= 0.0:
			_dodge_cooldown = DODGE_COOLDOWN
			invulnerable = false
	else:
		var target: Vector3 = dir * (SPRINT_SPEED if sprinting else WALK_SPEED)
		horizontal = horizontal.lerp(target, clampf(ACCEL * delta, 0.0, 1.0))

	velocity.x = horizontal.x
	velocity.z = horizontal.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta
	move_and_slide()

	if horizontal.length() > 0.3:
		var face: float = atan2(-horizontal.x, -horizontal.z)
		_body.rotation.y = lerp_angle(_body.rotation.y, face, clampf(TURN_SPEED * delta, 0.0, 1.0))

	var fov_target: float = FOV_SPRINT if sprinting else FOV_WALK
	_camera.fov = lerpf(_camera.fov, fov_target, clampf(4.0 * delta, 0.0, 1.0))
	_follow_rig(delta)


func _follow_rig(delta: float) -> void:
	var target: Vector3 = global_position + Vector3(0.0, CAMERA_HEIGHT, 0.0)
	_rig.global_position = _rig.global_position.lerp(target, clampf(14.0 * delta, 0.0, 1.0))
	_rig.rotation = Vector3(0.0, yaw, 0.0)
	_pitch_node.rotation = Vector3(pitch, 0.0, 0.0)


func _snap_rig() -> void:
	_rig.global_position = global_position + Vector3(0.0, CAMERA_HEIGHT, 0.0)
	_rig.rotation = Vector3(0.0, yaw, 0.0)
	_pitch_node.rotation = Vector3(pitch, 0.0, 0.0)
