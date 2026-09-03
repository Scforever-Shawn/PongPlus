extends Node2D

var score_p1: int = 0
var score_p2: int = 0

@onready var ball = $Ball
@onready var score_label = $CanvasLayer/ScoreLabel
@onready var camera = $Camera2D

var item_scene: PackedScene = preload("res://item.tscn")
var item_spawn_timer: float = 0.0

# Camera Shake
var shake_intensity: float = 0.0
var shake_timer: float = 0.0
var base_camera_pos = Vector2(576, 324)

func _ready():
    update_score_display()
    item_spawn_timer = randf_range(5.0, 10.0)

func _process(delta):
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
        
    # Item Spawning
    if item_spawn_timer > 0:
        item_spawn_timer -= delta
        if item_spawn_timer <= 0:
            spawn_item()
            item_spawn_timer = randf_range(8.0, 15.0)

func spawn_item():
    var item = item_scene.instantiate()
    add_child(item)
    # Spawn in the center area
    item.global_position = Vector2(get_viewport_rect().size.x / 2.0 + randf_range(-100, 100), get_viewport_rect().size.y / 2.0 + randf_range(-200, 200))

func reset_round():
    update_score_display()
    ball.reset_ball()
    # Reset paddles
    $PaddleP1.global_position.y = get_viewport_rect().size.y / 2
    $PaddleP2.global_position.y = get_viewport_rect().size.y / 2

func shake_camera(intensity: float, duration: float):
    shake_intensity = intensity
    shake_timer = duration

func update_score_display():
    if score_label:
        score_label.text = str(score_p1) + " : " + str(score_p2)
