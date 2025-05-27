class_name Player extends CharacterBody3D


const MOVE_SPEED := 5
const LOOK_SPEED := 0.001


@onready var head := $Head


func _enter_tree() -> void:
	set_multiplayer_authority(int(name))


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _physics_process(_delta: float) -> void:
	
	if not is_multiplayer_authority(): return
	
	if not is_on_floor():
		velocity = get_gravity()
	
	var input_dir: Vector2
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var temp_dir := input_dir.rotated(-rotation.y)
	var final_dir := Vector3(temp_dir.x, 0, temp_dir.y)
	velocity.x = final_dir.x * MOVE_SPEED
	velocity.z = final_dir.z * MOVE_SPEED
	
	move_and_slide()


func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority(): return
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_look(event.relative * LOOK_SPEED)


func rotate_look(rot: Vector2) -> void:
	var look_rotation := Vector3(head.rotation.x, rotation.y, 0)
	look_rotation.x -= rot.y
	look_rotation.x = clamp(look_rotation.x, deg_to_rad(85), deg_to_rad(-85))
	look_rotation.y -= rot.x
	transform.basis = Basis()
	rotate_y(look_rotation.y)
	head.transform.basis = Basis()
	head.rotate_x(look_rotation.x)
