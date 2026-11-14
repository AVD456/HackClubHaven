extends CharacterBody2D

enum State { NORMAL, DASH, HURT }
var state: State = State.NORMAL

var max_speed: float = 200.0;
var acceleration: float = 1500.0;
var deceleration: float = 2000.0;
var h_direction: float = 1;
var facing: int = 1;

var jump_peak: float = 50.0
var ascent_time: float = 0.4
var descent_time: float = 0.35
var jump_velocity = ((2 * jump_peak) / ascent_time) * -1
var ascent_gravity = ((-2 * jump_peak) / (ascent_time * ascent_time)) * -1
var descent_gravity = ((-2 * jump_peak) / (descent_time * descent_time)) * -1

var can_jump: bool = false 
var can_cut_jump: bool = false
var jump_cutoff: float = 0.5
var cutoff_weight: float = 0.4

var pogo_velocity: float = -450.0

var jump_buffer_time: float = 0.075 #three frames
var jump_buffer_timer: float = 0.0
var coyote_time: float = 0.1
var coyote_timer: float = 0.0

var dash_cooldown_time: float = 0.2
var dash_cooldown_timer: float = 0.0
var dash_time: float = 0.10
var dash_timer: float = 0.0

var dash_speed: float = 450.0
var dash_direction: Vector2 = Vector2.ZERO
var can_dash: bool = false

@export var dash_aim_with_mouse: bool = false

var hitstopping: bool = false

@export var max_health: int = 5
var health: int = 5

var i_time: float = 1.0
var i_timer: float = 0.0

var hurt_time: float = 0.25
var hurt_timer: float = 0.0

@export var counter_data: AttackData


func _ready():
	Engine.time_scale = 1.0
	add_to_group("player")
	health = max_health
	$Hurtbox.hit_received.connect(_on_hurtbox_hit)


func _physics_process(delta: float) -> void:
	update_timers(delta)
	
	match state:
		State.NORMAL:
			normal_state(delta)
		State.DASH:
			dash_state(delta)
		State.HURT:
			hurt_state(delta)


	move_and_slide()

func update_timers(delta: float):
	if is_on_floor():
		coyote_timer = coyote_time
	else:
		coyote_timer = max(coyote_timer - delta, 0.0)
	
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer_time
	else:
		jump_buffer_timer = max(jump_buffer_timer - delta, 0.0)
	
	dash_cooldown_timer = max(dash_cooldown_timer - delta, 0.0)
	i_timer = max(i_timer - delta, 0.0)
	

func normal_state(delta: float):
	h_direction = Input.get_axis("left", "right")
	
	if h_direction != 0.0:
		facing = int(signf(h_direction))
		velocity.x = move_toward(velocity.x, h_direction * max_speed, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)
	
	if coyote_timer > 0.0 and jump_buffer_timer > 0.0:
		velocity.y = jump_velocity
		jump_buffer_timer = 0.0
		coyote_timer = 0.0
		can_cut_jump = true
	
	if can_cut_jump and not Input.is_action_pressed("jump"):
		if velocity.y < (jump_velocity * jump_cutoff):
			velocity.y *= 0.5
			
	velocity.y += (ascent_gravity if velocity.y < 0 else descent_gravity) * delta

	if is_on_floor():
		can_dash = true
		
	if Input.is_action_just_pressed("dash") and can_dash and dash_cooldown_timer <= 0.0:
		state = State.DASH
		can_dash = false
		dash_timer = dash_time
		coyote_timer = 0.0
		
		var input = get_aim(dash_aim_with_mouse)
		
		if input != Vector2.ZERO:
			dash_direction = Vector2.from_angle(snappedf(input.angle(), PI / 4.0)) #45
			dash_direction = Vector2(roundi(dash_direction.x), roundi(dash_direction.y)).normalized()
			if dash_direction.x != 0: #if not up or down basicaly
				facing = int(signf(dash_direction.x))
		else:
			dash_direction = Vector2(facing, 0)
		return
	

func get_aim(use_mouse: bool) -> Vector2:
	if use_mouse:
		var to_mouse := get_global_mouse_position() - global_position
		if to_mouse.length() < 10.0:
			return Vector2.ZERO
		return to_mouse
	return Input.get_vector("left", "right", "up", "down")

func dash_state(delta: float):
	velocity = dash_direction * dash_speed
	dash_timer -= delta
	if dash_timer <= 0.0:
		state = State.NORMAL
		dash_cooldown_timer = dash_cooldown_time
		velocity.x = clampf(velocity.x, -max_speed, max_speed)
		velocity.y = clampf(velocity.y, -max_speed * 0.5, max_speed)


func hitstop(duration: float) -> void:
	if hitstopping or duration <= 0.0:
		return
	hitstopping = true
	Engine.time_scale = 0.05
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0
	hitstopping = false

func _on_hurtbox_hit(attack: AttackData, direction: Vector2, source: Node) -> void:
	if i_timer > 0.0:
		return
	
	health -= attack.damage
	print("player hit! health: ", health)
	
	if health <= 0:
		die()
		return
	
	i_timer = i_time
	hurt_timer = hurt_time
	state = State.HURT
	hitstop(attack.hitstop)
	
	knockback(direction, attack.knockback)
	
func knockback(direction: Vector2, knockback: float):
	var knockback_x := signf(direction.x) if direction.x != 0.0 else float(-facing)
	velocity = Vector2(knockback_x, -0.6).normalized() * knockback * 3

func hurt_state(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, deceleration * 0.5 * delta)
	velocity.y += (ascent_gravity if velocity.y < 0 else descent_gravity) * delta
	
	hurt_timer -= delta
	if hurt_timer <= 0.0:
		state = State.NORMAL

func die() -> void:
	Engine.time_scale = 1.0
	visible = false
	get_tree().call_deferred("reload_current_scene")
