extends CharacterBody2D
class_name Ball

@export var base_speed: float = 500.0
var speed: float = base_speed
var direction: Vector2 = Vector2.ZERO

var is_powered: bool = false
@onready var color_rect = $ColorRect
var original_color: Color = Color.WHITE

func _ready():
    add_to_group("ball")
    if color_rect:
        original_color = color_rect.color
    reset_ball()

func reset_ball():
    global_position = get_viewport_rect().size / 2
    speed = base_speed
    is_powered = false
    if color_rect:
        color_rect.color = original_color
    var dir_x = 1 if randf() > 0.5 else -1
    direction = Vector2(dir_x, randf_range(-0.5, 0.5)).normalized()

func trigger_power_up():
    if not is_powered:
        hit_pause(0.2)
        is_powered = true
        speed += 300.0
        if color_rect:
            color_rect.color = Color(2.0, 0.5, 0.2, 1) # Burning orange/red glow

func hit_pause(duration: float):
    get_tree().paused = true
    await get_tree().create_timer(duration, true, false, true).timeout
    get_tree().paused = false

func _physics_process(delta):
    # Only process if we have a direction
    if direction == Vector2.ZERO:
        return
        
    var collision = move_and_collide(direction * speed * delta)
    if collision:
        var collider = collision.get_collider()
        
        if collider is Paddle:
            # Check parry interaction
            var relative_y = (global_position.y - collider.global_position.y) / 50.0
            var new_dir_x = sign(global_position.x - collider.global_position.x)
            if new_dir_x == 0:
                new_dir_x = -sign(direction.x)
                
            if collider.is_parrying():
                # Perfect parry!
                AudioManager.play_sound("parry")
                if is_powered:
                    hit_pause(0.3)
                    speed += 400.0
                    get_tree().current_scene.shake_camera(10.0, 0.3)
                else:
                    hit_pause(0.1)
                    speed += 100.0
                    get_tree().current_scene.shake_camera(3.0, 0.1)
            else:
                # Normal hit or failed parry against powered ball
                if is_powered:
                    AudioManager.play_sound("break")
                    collider.break_paddle()
                    get_tree().current_scene.shake_camera(15.0, 0.3)
                    # Lose powered state
                    is_powered = false
                    speed = base_speed + 50.0
                    if color_rect:
                        color_rect.color = original_color
                else:
                    AudioManager.play_sound("hit")
                    speed += 25.0
                    
            direction = Vector2(new_dir_x, relative_y).normalized()
        else:
            # Hit wall
            AudioManager.play_sound("hit")
            direction = direction.bounce(collision.get_normal())
