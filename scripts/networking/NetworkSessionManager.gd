class_name NetworkSessionManager
extends Node

signal session_started(is_host: bool, port: int)
signal session_ended(reason: String)
signal peer_joined(peer_id: int, total_peers: int)
signal peer_left(peer_id: int, total_peers: int)
signal command_rejected(peer_id: int, command_id: StringName, reason: String)
signal state_snapshot_broadcast(snapshot: Dictionary)

const DEFAULT_PORT: int = 7777
const MAX_PLAYERS: int = 4
const ALLOWED_COMMANDS: Array[StringName] = [
	&"interact",
	&"recruit",
	&"build_wall",
	&"repair_wall",
]
const MIN_WORLD_X: float = WorldConstants.MIN_PLAYABLE_X
const MAX_WORLD_X: float = WorldConstants.MAX_PLAYABLE_X
const MAX_PEER_SPEED_PX_PER_SEC: float = 260.0
const BASE_JITTER_ALLOWANCE_PX: float = 24.0

var is_online_active: bool = false
var is_host_authority: bool = true
var server_clock_sec: float = 0.0
var connected_peers: Array[int] = [1]
var peer_positions: Dictionary = {1: 0.0}
var peer_last_move_time: Dictionary = {1: 0.0}
var _session_target: ForgottenShoreSession


func bind_gameplay_session(session: ForgottenShoreSession) -> void:
	_session_target = session


func advance_server_clock(delta: float) -> void:
	if delta > 0.0:
		server_clock_sec += delta


func start_host_session(port: int = DEFAULT_PORT, max_clients: int = MAX_PLAYERS - 1) -> Error:
	if port < 1024 or port > 65535:
		return ERR_INVALID_PARAMETER
	if max_clients < 1 or max_clients > (MAX_PLAYERS - 1):
		return ERR_INVALID_PARAMETER

	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var err: Error = peer.create_server(port, max_clients)
	if err != OK:
		return err

	multiplayer.multiplayer_peer = peer
	is_online_active = true
	is_host_authority = true
	connected_peers = [1]
	peer_positions = {1: 0.0}
	peer_last_move_time = {1: server_clock_sec}
	session_started.emit(true, port)
	return OK


func join_host_session(address: String, port: int = DEFAULT_PORT) -> Error:
	if address.strip_edges().is_empty() or port < 1024 or port > 65535:
		return ERR_INVALID_PARAMETER

	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var err: Error = peer.create_client(address.strip_edges(), port)
	if err != OK:
		return err

	multiplayer.multiplayer_peer = peer
	is_online_active = true
	is_host_authority = false
	session_started.emit(false, port)
	return OK


func close_session(reason: String = "manual_close") -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	is_online_active = false
	is_host_authority = true
	connected_peers = [1]
	peer_positions = {1: 0.0}
	peer_last_move_time = {1: server_clock_sec}
	session_ended.emit(reason)


func register_test_peer(peer_id: int, initial_x: float = 0.0) -> bool:
	if peer_id <= 1 or connected_peers.has(peer_id):
		return false
	if connected_peers.size() >= MAX_PLAYERS:
		return false
	connected_peers.append(peer_id)
	peer_positions[peer_id] = clampf(initial_x, MIN_WORLD_X, MAX_WORLD_X)
	peer_last_move_time[peer_id] = server_clock_sec
	peer_joined.emit(peer_id, connected_peers.size())
	return true


func unregister_peer(peer_id: int) -> bool:
	if peer_id == 1 or not connected_peers.has(peer_id):
		return false
	connected_peers.erase(peer_id)
	peer_positions.erase(peer_id)
	peer_last_move_time.erase(peer_id)
	peer_left.emit(peer_id, connected_peers.size())
	return true


func is_movement_within_speed_limit(peer_id: int, claimed_x: float) -> bool:
	if not connected_peers.has(peer_id):
		return false
	if is_nan(claimed_x) or is_inf(claimed_x) or claimed_x < MIN_WORLD_X or claimed_x > MAX_WORLD_X:
		return false
	var tracked_x: float = float(peer_positions.get(peer_id, 0.0))
	var last_time: float = float(peer_last_move_time.get(peer_id, server_clock_sec))
	var elapsed: float = maxf(0.0, server_clock_sec - last_time)
	var max_allowed_dist: float = BASE_JITTER_ALLOWANCE_PX + (elapsed * MAX_PEER_SPEED_PX_PER_SEC)
	return absf(claimed_x - tracked_x) <= max_allowed_dist


func update_peer_position(peer_id: int, new_x: float) -> bool:
	if not is_movement_within_speed_limit(peer_id, new_x):
		return false
	peer_positions[peer_id] = new_x
	peer_last_move_time[peer_id] = server_clock_sec
	return true


func submit_client_command(peer_id: int, command_id: StringName, claimed_x: float, params: Dictionary = {}) -> bool:
	if not is_host_authority:
		command_rejected.emit(peer_id, command_id, "Local node is not host authority")
		return false
	if not connected_peers.has(peer_id):
		command_rejected.emit(peer_id, command_id, "Unknown peer ID")
		return false
	if not ALLOWED_COMMANDS.has(command_id):
		command_rejected.emit(peer_id, command_id, "Command not permitted from peer: %s" % String(command_id))
		return false
	if not is_movement_within_speed_limit(peer_id, claimed_x):
		command_rejected.emit(peer_id, command_id, "Position desync or speed-hack detected")
		return false

	# If bound to a gameplay session, execute first; do NOT mutate peer_positions if rejected!
	if _session_target != null:
		var ok: bool = _session_target.execute_command(command_id, claimed_x, params)
		if not ok:
			command_rejected.emit(peer_id, command_id, "Gameplay command rejected by session")
			return false
		peer_positions[peer_id] = claimed_x
		peer_last_move_time[peer_id] = server_clock_sec
		state_snapshot_broadcast.emit(_session_target.build_save_payload())
		return true

	peer_positions[peer_id] = claimed_x
	peer_last_move_time[peer_id] = server_clock_sec
	return true
