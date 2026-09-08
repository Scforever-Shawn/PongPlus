extends Area2D
class_name Item

func _ready():
    body_entered.connect(_on_body_entered)
    get_tree().create_timer(10.0).timeout.connect(_on_expire)

func _on_body_entered(body):
    if body is Ball:
        var scene = get_tree().current_scene
        if scene.has_method("is_network_game") and scene.is_network_game():
            if not scene.has_method("is_host") or not scene.is_host():
                return
            AudioManager.play_sound("powerup")
            body.trigger_power_up()
            scene.consume_network_item(self)
        else:
            AudioManager.play_sound("powerup")
            body.trigger_power_up()
            queue_free()

func _on_expire():
    if not is_inside_tree():
        return
    var scene = get_tree().current_scene
    if scene.has_method("is_network_game") and scene.is_network_game():
        if scene.has_method("is_host") and scene.is_host():
            scene.consume_network_item(self)
    else:
        queue_free()
