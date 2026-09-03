extends CharacterBody2D
class_name Paddle

const SPEED = 400.0

@export var is_player_2: bool = false
@export var is_ai: bool = false
@export var ai_speed_multiplier: float = 0.8

var ball_node: Node2D = null

# Parry Mechanics
var parry_timer: float = 0.0
var parry_duration: float = 0.35
@onready var color_rect = $ColorRect
var original_color: Color = Color.WHITE

var start_x: float = 0.0

func _ready():
	start_x = global_position.x
	if is_ai:
		ball_node = get_tree().get_first_node_in_group("ball")
	if color_rect:
		original_color = color_rect.color

func is_parrying() -> bool:
	return parry_timer > 0.0

func break_paddle():
	# Visual break effect: shrink paddle temporarily
	scale.y = 0.5
	if color_rect:
		color_rect.color = Color.RED
	if has_node("BreakParticles"):
		$BreakParticles.emitting = true
	get_tree().create_timer(3.0).timeout.connect(reset_paddle)

func reset_paddle():
	scale.y = 1.0
	if color_rect:
		color_rect.color = original_color

func _physics_process(delta):
	var direction = 0.0
	
	# Parry timer countdown
	if parry_timer > 0.0:
		parry_timer -= delta
		if parry_timer <= 0.0:
			if color_rect:
				color_rect.color = original_color

	
	if is_ai and ball_node:
		# Simple AI tracking
		var diff = ball_node.global_position.y - global_position.y
		if abs(diff) > 10:
			direction = sign(diff) * ai_speed_multiplier
	else:
		# Player Input
		if is_player_2:
			if Input.is_action_pressed("p2_up"):
				direction -= 1
			if Input.is_action_pressed("p2_down"):
				direction += 1
			if Input.is_action_just_pressed("p2_parry") and parry_timer <= 0.0:
				activate_parry()
		else:
			if Input.is_action_pressed("p1_up"):
				direction -= 1
			if Input.is_action_pressed("p1_down"):
				direction += 1
			if Input.is_action_just_pressed("p1_parry") and parry_timer <= 0.0:
				activate_parry()

	velocity.y = direction * SPEED
	move_and_slide()
	
	# Clamp position to screen bounds and lock X axis to prevent physics pushing
	global_position.x = start_x
	global_position.y = clamp(global_position.y, 60, get_viewport_rect().size.y - 60)

func activate_parry():
	parry_timer = parry_duration
	if color_rect:
		# Blue color with white flash (using high value for glow)
		color_rect.color = Color(0.5, 0.8, 2.0, 1)
