extends Area2D
class_name Item

func _ready():
    # Connect body entered signal
    body_entered.connect(_on_body_entered)
    # Destroy after 10 seconds if not collected
    get_tree().create_timer(10.0).timeout.connect(queue_free)

func _on_body_entered(body):
    if body is Ball:
        AudioManager.play_sound("powerup")
        body.trigger_power_up()
        queue_free()
