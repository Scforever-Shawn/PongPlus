extends Node2D

const DEFAULT_PORT := 7777
const MAX_CLIENTS := 1
const SNAPSHOT_INTERVAL := 1.0 / 30.0

enum GameMode { MENU, LOCAL, HOST, CLIENT }

var score_p1: int = 0
var score_p2: int = 0
var game_mode: GameMode = GameMode.MENU
var snapshot_timer := 0.0
var item_spawn_timer: float = 0.0
var next_network_item_id := 1
var network_items: Dictionary = {}

@onready var ball: Ball = $Ball
@onready var paddle_p1: Paddle = $PaddleP1
@onready var paddle_p2: Paddle = $PaddleP2
@onready var score_label = $CanvasLayer/ScoreLabel
@onready var camera = $Camera2D

var item_scene: PackedScene = preload("res://item.tscn")

# Camera Shake
var shake_intensity: float = 0.0
var shake_timer: float = 0.0
var base_camera_pos = Vector2(576, 324)

# Runtime multiplayer UI
var menu_layer: CanvasLayer
var status_label: Label
var address_input: LineEdit

func _ready():
    update_score_display()
    item_spawn_timer = randf_range(5.0, 10.0)
    ball.simulation_enabled = false
    paddle_p1.input_enabled = false
    paddle_p2.input_enabled = false
    _build_multiplayer_menu()

    multiplayer.peer_connected.connect(_on_peer_connected)
    multiplayer.peer_disconnected.connect(_on_peer_disconnected)
    multiplayer.connected_to_server.connect(_on_connected_to_server)
    multiplayer.connection_failed.connect(_on_connection_failed)
    multiplayer.server_disconnected.connect(_on_server_disconnected)

func _process(delta):
    if game_mode == GameMode.MENU:
        return

    if _is_simulation_authority():
        if ball.global_position.x < 0:
            AudioManager.play_sound("score")
            score_p2 += 1
            reset_round()
        elif ball.global_position.x > get_viewport_rect().size.x:
            AudioManager.play_sound("score")
            score_p1 += 1
            reset_round()

    # Camera Shake process
    if shake_timer > 0:
        shake_timer -= delta
        if camera:
            camera.position = base_camera_pos + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_intensity
        if shake_timer <= 0 and camera:
            camera.position = base_camera_pos

    # Item spawning is authoritative. Online items are mirrored by RPC.
    if _is_simulation_authority() and ball.simulation_enabled:
        if item_spawn_timer > 0:
            item_spawn_timer -= delta
            if item_spawn_timer <= 0:
                spawn_item()
                item_spawn_timer = randf_range(8.0, 15.0)

func _physics_process(delta):
    if game_mode == GameMode.HOST and multiplayer.has_multiplayer_peer():
        snapshot_timer -= delta
        if snapshot_timer <= 0.0:
            snapshot_timer = SNAPSHOT_INTERVAL
            _send_snapshot.rpc(
                ball.global_position,
                ball.direction,
                ball.speed,
                ball.is_powered,
                paddle_p1.global_position.y,
                paddle_p2.global_position.y,
                paddle_p1.is_parrying(),
                paddle_p2.is_parrying(),
                paddle_p1.scale.y,
                paddle_p2.scale.y,
                score_p1,
                score_p2
            )
    elif game_mode == GameMode.CLIENT and multiplayer.has_multiplayer_peer():
        var direction := 0.0
        if Input.is_action_pressed("p1_up"):
            direction -= 1.0
        if Input.is_action_pressed("p1_down"):
            direction += 1.0
        _submit_client_input.rpc_id(1, direction)
        if Input.is_action_just_pressed("p1_parry"):
            _request_client_parry.rpc_id(1)

func _build_multiplayer_menu():
    menu_layer = CanvasLayer.new()
    menu_layer.layer = 10
    add_child(menu_layer)

    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    menu_layer.add_child(center)

    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(420, 300)
    center.add_child(panel)

    var vbox := VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 12)
    panel.add_child(vbox)

    var title := Label.new()
    title.text = "PongPlus"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 32)
    vbox.add_child(title)

    var help := Label.new()
    help.text = "P2P / IP 直连（UDP %d）\n主机：W/S + Space\n客户端：W/S + Space" % DEFAULT_PORT
    help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vbox.add_child(help)

    var local_button := Button.new()
    local_button.text = "本地对战（P2 为 AI）"
    local_button.pressed.connect(_start_local_game)
    vbox.add_child(local_button)

    var host_button := Button.new()
    host_button.text = "创建主机"
    host_button.pressed.connect(_start_host)
    vbox.add_child(host_button)

    address_input = LineEdit.new()
    address_input.placeholder_text = "主机 IP，例如 192.168.1.10 或公网 IP"
    address_input.text = "127.0.0.1"
    vbox.add_child(address_input)

    var join_button := Button.new()
    join_button.text = "连接主机"
    join_button.pressed.connect(_join_host)
    vbox.add_child(join_button)

    status_label = Label.new()
    status_label.text = "选择游戏模式"
    status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    vbox.add_child(status_label)

func _start_local_game():
    _close_network_peer()
    game_mode = GameMode.LOCAL
    menu_layer.visible = false
    paddle_p1.is_ai = false
    paddle_p1.input_enabled = true
    paddle_p2.is_ai = true
    paddle_p2.input_enabled = true
    paddle_p1.network_replica = false
    paddle_p2.network_replica = false
    ball.network_replica = false
    ball.simulation_enabled = true
    reset_round()

func _start_host():
    _close_network_peer()
    var peer := ENetMultiplayerPeer.new()
    var error := peer.create_server(DEFAULT_PORT, MAX_CLIENTS)
    if error != OK:
        status_label.text = "创建主机失败，错误码：%s" % error
        return

    multiplayer.multiplayer_peer = peer
    game_mode = GameMode.HOST
    paddle_p1.is_ai = false
    paddle_p1.input_enabled = true
    paddle_p1.network_replica = false
    paddle_p2.is_ai = false
    paddle_p2.input_enabled = true
    paddle_p2.network_replica = false
    ball.network_replica = false
    ball.simulation_enabled = false
    status_label.text = "主机已创建，等待玩家连接… UDP %d" % DEFAULT_PORT

func _join_host():
    var host := address_input.text.strip_edges()
    if host.is_empty():
        status_label.text = "请输入主机 IP"
        return

    _close_network_peer()
    var peer := ENetMultiplayerPeer.new()
    var error := peer.create_client(host, DEFAULT_PORT)
    if error != OK:
        status_label.text = "连接初始化失败，错误码：%s" % error
        return

    multiplayer.multiplayer_peer = peer
    game_mode = GameMode.CLIENT
    paddle_p1.is_ai = false
    paddle_p1.input_enabled = false
    paddle_p1.network_replica = true
    paddle_p2.is_ai = false
    paddle_p2.input_enabled = false
    paddle_p2.network_replica = true
    ball.network_replica = true
    ball.simulation_enabled = false
    status_label.text = "正在连接 %s:%d…" % [host, DEFAULT_PORT]

func _on_peer_connected(peer_id: int):
    if game_mode != GameMode.HOST:
        return
    if peer_id != 1:
        status_label.text = "玩家已连接，比赛开始"
        menu_layer.visible = false
        ball.simulation_enabled = true
        reset_round()

func _on_peer_disconnected(peer_id: int):
    if game_mode == GameMode.HOST and peer_id != 1:
        ball.simulation_enabled = false
        paddle_p2.set_network_input(0.0)
        status_label.text = "对方已断开，等待重新连接…"
        menu_layer.visible = true

func _on_connected_to_server():
    if game_mode == GameMode.CLIENT:
        status_label.text = "已连接，比赛开始"
        menu_layer.visible = false

func _on_connection_failed():
    status_label.text = "连接失败，请检查 IP、UDP %d 端口和防火墙" % DEFAULT_PORT
    game_mode = GameMode.MENU
    _close_network_peer()

func _on_server_disconnected():
    status_label.text = "主机连接已断开"
    game_mode = GameMode.MENU
    menu_layer.visible = true
    _close_network_peer()

func _close_network_peer():
    if multiplayer.has_multiplayer_peer():
        multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()

func _is_simulation_authority() -> bool:
    return game_mode == GameMode.LOCAL or game_mode == GameMode.HOST

func is_network_game() -> bool:
    return game_mode == GameMode.HOST or game_mode == GameMode.CLIENT

func is_host() -> bool:
    return game_mode == GameMode.HOST

@rpc("any_peer", "call_remote", "unreliable")
func _submit_client_input(direction: float):
    if game_mode != GameMode.HOST or multiplayer.get_remote_sender_id() == 1:
        return
    paddle_p2.set_network_input(clamp(direction, -1.0, 1.0))

@rpc("any_peer", "call_remote", "reliable")
func _request_client_parry():
    if game_mode != GameMode.HOST or multiplayer.get_remote_sender_id() == 1:
        return
    paddle_p2.request_network_parry()

@rpc("authority", "call_remote", "unreliable_ordered")
func _send_snapshot(
    ball_position: Vector2,
    ball_direction: Vector2,
    ball_speed: float,
    ball_powered: bool,
    p1_y: float,
    p2_y: float,
    p1_parry: bool,
    p2_parry: bool,
    p1_scale_y: float,
    p2_scale_y: float,
    new_score_p1: int,
    new_score_p2: int
):
    if game_mode != GameMode.CLIENT:
        return

    ball.apply_network_state(ball_position, ball_direction, ball_speed, ball_powered)
    paddle_p1.apply_network_state(p1_y, p1_parry, p1_scale_y)
    paddle_p2.apply_network_state(p2_y, p2_parry, p2_scale_y)
    score_p1 = new_score_p1
    score_p2 = new_score_p2
    update_score_display()

func spawn_item():
    var spawn_position := Vector2(
        get_viewport_rect().size.x / 2.0 + randf_range(-100, 100),
        get_viewport_rect().size.y / 2.0 + randf_range(-200, 200)
    )

    if game_mode == GameMode.HOST:
        var item_id := next_network_item_id
        next_network_item_id += 1
        _spawn_network_item.rpc(item_id, spawn_position)
    else:
        _create_item(0, spawn_position)

@rpc("authority", "call_local", "reliable")
func _spawn_network_item(item_id: int, spawn_position: Vector2):
    _create_item(item_id, spawn_position)

func _create_item(item_id: int, spawn_position: Vector2):
    var item = item_scene.instantiate()
    add_child(item)
    item.global_position = spawn_position
    if item_id > 0:
        item.set_meta("network_item_id", item_id)
        network_items[item_id] = item
        if game_mode == GameMode.CLIENT:
            item.monitoring = false

func consume_network_item(item: Node):
    if game_mode != GameMode.HOST:
        item.queue_free()
        return
    var item_id: int = int(item.get_meta("network_item_id", 0))
    if item_id > 0:
        _remove_network_item.rpc(item_id)
    else:
        item.queue_free()

@rpc("authority", "call_local", "reliable")
func _remove_network_item(item_id: int):
    if not network_items.has(item_id):
        return
    var item = network_items[item_id]
    network_items.erase(item_id)
    if is_instance_valid(item):
        item.queue_free()

func reset_round():
    update_score_display()
    ball.reset_ball()
    paddle_p1.global_position.y = get_viewport_rect().size.y / 2
    paddle_p2.global_position.y = get_viewport_rect().size.y / 2

func shake_camera(intensity: float, duration: float):
    shake_intensity = intensity
    shake_timer = duration

func update_score_display():
    if score_label:
        score_label.text = str(score_p1) + " : " + str(score_p2)
