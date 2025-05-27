extends Node


@onready var host_button := $VBoxContainer/HostButton
@onready var join_button := $VBoxContainer/JoinButton
@onready var buttons := $VBoxContainer
@onready var players_node := $Players
@onready var player_scene := preload("res://addons/brackeys-proto-controller-main/proto_controller/proto_controller.tscn")


func _ready() -> void:
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	multiplayer.peer_connected.connect(_on_peer_connected)


func _on_host_pressed() -> void:
	var peer := ENetMultiplayerPeer.new()
	peer.create_server(2646)
	multiplayer.set_multiplayer_peer(peer)
	buttons.hide()
	spawn_player(1)


func _on_join_pressed() -> void:
	var peer := ENetMultiplayerPeer.new()
	peer.create_client("127.0.0.1", 2646)
	multiplayer.set_multiplayer_peer(peer)
	buttons.hide()


func spawn_player(id: int) -> void:
	var player = player_scene.instantiate()
	player.name = str(id)
	players_node.add_child(player)


func _on_peer_connected(peer_id: int) -> void:
	if is_multiplayer_authority():
		spawn_player(peer_id)
