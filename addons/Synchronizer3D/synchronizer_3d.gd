class_name Synchronizer3D extends Node


## [Synchronizer3D] serves as an alternative to [MultiplayerSynchronizer] for synchronizing
## position and rotation properties for a [Node3D].[br][br]
## [b]Motivation[/b]:[br]
## [MultiplayerSynchronizer] is an extremely useful node for prototyping,
## but it has a number of limitations. This addresses two such limitations in particular:
## being unable to use [constant MultiplayerPeer.TRANSFER_MODE_UNRELIABLE] for on-change updates, and 
## being unable to interpolate/extrapolate between received updates.[br][br]
## [b]How it Works[/b]:[br]
## Every update interval, the authority node will check [member sync_node] for property changes.
## If changes exist, the authority will send an update to each other connected peer.
## Non-authority peers will interpolate/extrapolate between received updates if enabled.[br][br]
## [b]How to Use[/b]:[br]
## To use [Synchronizer3D] simply add it as a child of the node you wish to synchronize properties for,
## and configure it in the inspector. You can specify which properties to synchronize,
## when the authority should send updates, and whether non-authority peers should interpolate and/or
## extrapolate between updates. Most of the functions in this class should [b]not[/b] be touched
## with the exception of [method force_update], which can be used by the authority
## to reliably force a node's current properties. This is particularly useful in situations like
## teleporting the [member sync_node].[br][br]
## [b]Limitations[/b]:[br]
## The main limitation of this node comes from its greatest strength: synchronizing only position and rotation.
## This means [Synchronizer3D] lacks the flexiblity of [MultiplayerSynchronizer], but this drawback comes with
## the benefits of interpolation and extrapolation, and bandwidth optimization.
## In a simple apples-to-apples comparison, I've found in my testing that this optimization is associated with a ~90% bandwidth reduction
## compared to [MultiplayerSynchronizer] for syncing position and rotation.
## That being said, there are other limitations as well:[br]
## [Synchronizer3D] can only be used to synchronize position and rotation for a [Node3D] (and classes that extend [Node3D]).[br]
## For non-authority peers, the [member Node.physics_interpolation_mode] of [member sync_node]
## should be set to [constant Node.PHYSICS_INTERPOLATION_MODE_OFF] when using [Synchronizer3D]'s
## interpolation/extrapolation features. Using these together will almost certainly create unexpected
## bugs (or are they expected if I'm talking about them here?).
## That being said, there may be cases where you wish to change the authority of [member sync_node], and therefore
## change its [member Node.physics_interpolation_mode].
## While changing authority is supported, [Synchronizer3D] will [b]not[/b] automatically change
## [member Node.physics_interpolation_mode] following authority changes; this needs to be handled separately.[br]
## This node should only be added to the [SceneTree] once the [MultiplayerAPI] has a [MultiplayerPeer].


## When using [constant UPDATE_MODE_IDLE], it's hard to know what interval peers should expect
## since it is dependent on the authority peer's framerate. So we just estimate here that
## we'll be receiving 60 updates per second.
const ARBITRARY_INTERVAL := 1.0 / 60.0


## Specifies when properties updates are sent from the multiplayer authority
## to other peers.
enum UpdateMode {
	UPDATE_MODE_PHYSICS, ## Properties are synchronized every physics frame.
	UPDATE_MODE_IDLE,    ## Properties are synchronized every process frame.
	UPDATE_MODE_DELTA   ## Properties are synchronized every [member delta_interval] seconds.
}


## The [Node3D] to synchronize properties for. [br][br]
## If left empty, defaults to the parent of this [Synchronizer3D].
@export var sync_node: Node3D
## Whether to synchronize the global position of [member sync_node].
@export var synchronize_position := true
## Whether to synchronize the global rotation of [member sync_node].
@export var synchronize_rotation := true
## Specifies when properties are synchronized.
## Specifically, the multiplayer authority of [member sync_node] will
## send updates to all other peers on the specified interval.
@export var update_mode := UpdateMode.UPDATE_MODE_PHYSICS
## Specifies the interval (in seconds) between updates when 
## [member update_mode] is set to [constant UPDATE_MODE_DELTA].
@export var delta_interval := 0.1
## Whether to interpolate between received updates.
@export var interpolate := true
## Whether to extrapolate past received updates.
## Ignored if [member Interpolate] is off.
## See [member max_extrapolation].
@export var extrapolate := true
## Specifies an upper limit for extrapolation in physics frames.[br][br]
## For example, setting this to 2 allows us to predict properties
## up to 2 physics frames past the last received update.[br][br]
## Ignored if either [member interpolate] or [member extrapolate] are off.
@export var max_extrapolation := 2


var last_pos: Vector3
var start_pos_set := false
var end_pos_set := false
var start_pos: Vector3
var end_pos: Vector3
var pos_delta := 0.0

var last_rot: Quaternion
var start_rot_set := false
var end_rot_set := false
var start_rot: Quaternion
var end_rot: Quaternion
var rot_delta := 0.0

var timer: Timer


## Handles initialization.[br][br]
## Connects [signal MultiplayerAPI.peer_connected] to [method _on_peer_connected].[br][br]
## If [member sync_node] was not set in the inspector, sets [member sync_node] as
## the parent of this [Synchronizer3D].[br][br]
## For non-authority peers, sets [member sync_node]'s [member Node.physics_interpolation_mode]
## to [constant Node.PHYSICS_INTERPOLATION_MODE_OFF].[br][br]
## If [member update_mode] is [constant UPDATE_MODE_DELTA], adds a [Timer] as a child
## and starts it.
func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	
	if not sync_node:
		sync_node = get_parent()
	
	if synchronize_position: last_pos = sync_node.global_position
	if synchronize_rotation: last_rot = sync_node.quaternion
	
	if interpolate and not is_multiplayer_authority():
		sync_node.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	
	if update_mode == UpdateMode.UPDATE_MODE_DELTA:
		timer = Timer.new()
		timer.timeout.connect(_on_timer_timeout)
		add_child.call_deferred(timer)
		await timer.ready
		timer.start(delta_interval)


## Sends property updates when [member update_mode] is [constant UPDATE_MODE_DELTA].
func _on_timer_timeout() -> void:
	if is_multiplayer_authority(): send_updates()
	timer.start(delta_interval)


## Send initial property updates to joining peers.
func _on_peer_connected(peer_id: int) -> void:
	if is_multiplayer_authority():
		if synchronize_position: force_position.rpc_id(peer_id, sync_node.global_position)
		if synchronize_rotation: force_rotation.rpc_id(peer_id, sync_node.quaternion.get_euler())


## RPC to update position on non-authority peers.
@rpc("authority", "call_remote", "unreliable")
func update_pos(pos: Vector3) -> void:
	if not start_pos_set:
		start_pos = pos
		start_pos_set = true
	else:
		if not end_pos_set:
			end_pos = pos
			end_pos_set = true
		else:
			start_pos = sync_node.global_position
			if interpolate:
				# if we are currently extrapolating...
				if extrapolate and pos_delta > get_update_interval():
					var real_dist := end_pos.distance_to(pos)
					var extrap_dist := end_pos.distance_to(sync_node.global_position)
					# if we extrapolated further than the "real" distance...
					if extrap_dist > real_dist:
						# sit at this update and wait for the next.
						end_pos_set = false
					# else...
					else:
						# business as usual.
						end_pos = pos
				else:
					end_pos = pos
				pos_delta = fmod(pos_delta, get_update_interval())
			else:
				end_pos = pos


## RPC to update rotation on non-authority peers.[br][br]
## As a minor bandwidth optimization, rotation is sent as [Vector3] (euler angles), then
## reconstructed by peers as a [Quaternion].
## See the manual page [url=https://docs.godotengine.org/en/stable/tutorials/3d/using_transforms.html#problems-of-euler-angles]
## Problems of Euler Angles[/url].
@rpc("authority", "call_remote", "unreliable")
func update_rot(e_rot: Vector3) -> void:
	var rot := Quaternion.from_euler(e_rot)
	if not start_rot_set:
		start_rot = rot
		start_rot_set = true
	else:
		if not end_rot_set:
			end_rot = rot
			end_rot_set = true
		else:
			start_rot = sync_node.quaternion
			if interpolate:
				if extrapolate and rot_delta > get_update_interval():
					var real_angle := end_rot.angle_to(rot)
					var extrap_angle := end_rot.angle_to(sync_node.quaternion)
					if extrap_angle > real_angle:
						end_rot_set = false
					else:
						end_rot = rot
				else:
					end_rot = rot
				rot_delta = fmod(rot_delta, get_update_interval())
			else:
				end_rot = rot


## Serves different purposes for authority and non authority peers respectively.[br][br]
## [b]Authority[/b]
## Sends property updates when [member update_mode] is [constant UPDATE_MODE_IDLE].[br][br]
## [b]Non-Authority Peers[/b]
## Sets the current properties as received from the authority.
## Interpolates and extrapolates (predicts) properties if enabled.
func _process(delta: float) -> void:
	if is_multiplayer_authority():
		if update_mode == UpdateMode.UPDATE_MODE_IDLE: send_updates()
	else:
		if synchronize_position:
			if start_pos_set:
				if not end_pos_set: sync_node.global_position = start_pos
				else:
					if interpolate:
						pos_delta += delta
						sync_node.global_position = start_pos.lerp(end_pos, get_weight(pos_delta))
					else:
						sync_node.global_position = end_pos
		if synchronize_rotation:
			if start_rot_set:
				if not end_rot_set: sync_node.quaternion = start_rot
				else:
					if interpolate:
						rot_delta += delta
						sync_node.quaternion = start_rot.slerp(end_rot, get_weight(rot_delta))
					else:
						sync_node.quaternion = end_rot


## Sends property updates when [member update_mode] is [constant UPDATE_MODE_PHYSICS].
func _physics_process(_delta: float) -> void:
	if is_multiplayer_authority() and update_mode == UpdateMode.UPDATE_MODE_PHYSICS:
		send_updates()


## Used internally to send updates when there is a property change.
## Triggered based on [member update_mode].
func send_updates() -> void:
	if synchronize_position:
		var cur_pos := sync_node.global_position
		if not cur_pos.is_equal_approx(last_pos):
			update_pos.rpc(cur_pos)
			last_pos = cur_pos
	if synchronize_rotation:
		var cur_rot := sync_node.quaternion
		if not cur_rot.is_equal_approx(last_rot):
			update_rot.rpc(cur_rot.get_euler())
			last_rot = cur_rot


## Get the estimated update interval based on [member update_mode].[br][br]
## Used internally for interpolation/extrapolation.
func get_update_interval() -> float:
	match update_mode:
		UpdateMode.UPDATE_MODE_PHYSICS: return 1.0 / Engine.physics_ticks_per_second
		UpdateMode.UPDATE_MODE_DELTA: return delta_interval
		_: return ARBITRARY_INTERVAL


## Get the interpolation weight given delta.[br][br]
## Used internally for interpolation/extrapolation.
func get_weight(delta: float) -> float:
	var weight := delta / get_update_interval()
	var weight_max: float
	if extrapolate:
		weight_max = max_extrapolation + 1.0
	else:
		weight_max = 1.0
	return clampf(weight, 0.0, weight_max)


## Force updates for current position and rotation (if enabled).
## Essentially resets interpolation and extrapolation and forces the current properties.[br][br]
## This should only be used by the multiplayer authority. Particularly useful when teleporting
## the [member sync_node]. Uses [constant MultiplayerPeer.TRANSFER_MODE_RELIABLE], so use sparingly.
func force_update() -> void:
	if synchronize_position: force_position.rpc(sync_node.global_position)
	if synchronize_rotation: force_rotation.rpc(sync_node.quaternion.get_euler())


## Used by [method force_update] to force a position update.
@rpc("authority", "call_remote", "reliable")
func force_position(pos: Vector3) -> void:
	start_pos = pos
	start_pos_set = true
	end_pos_set = false


## Used by [method force_update] to force a rotation update.
@rpc("authority", "call_remote", "reliable")
func force_rotation(e_rot: Vector3) -> void:
	start_rot = Quaternion.from_euler(e_rot)
	start_rot_set = true
	end_rot_set = false
