extends CharacterBody2D

enum State { NORMAL, DASH, HURT, PARRY, ULT }
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

@onready var attack_pivot: Node2D = $AttackPivot
@onready var attack_shape: CollisionPolygon2D = $AttackPivot/AttackHitbox/CollisionPolygon2D
@onready var attack_hitbox: Area2D = $AttackPivot/AttackHitbox
@export var attack_data: AttackData

var attack_hit_list: Array[Area2D] = []

var attack_startup: float = 0.05
var attack_active: float = 0.10
var attack_recovery: float = 0.10

var attack_timer: float = 0.0
var attack_cooldown_time: float = 0.1
var attack_cooldown_timer: float = 0.0
var attacking: bool = false
var attack_direction: Vector2 = Vector2.RIGHT

@onready var ult_pivot: Node2D = $UltimatePivot
@onready var ult_shape: CollisionShape2D = $UltimatePivot/UltimateHitbox/CollisionShape2D2
@onready var ult_hitbox: Area2D = $UltimatePivot/UltimateHitbox
@export var ult_data: AttackData

var ult_hit_list: Array[Area2D] = []

var ult_startup: float = 0.5
var ult_active: float = 1.0
var ult_recovery: float = 0.5

var ult_timer: float = 0.0
var ult_cooldown_time: float = 0.1
var ult_cooldown_timer: float = 0.0
var ult_attacking: bool = false
var ult_direction: Vector2 = Vector2.RIGHT

@export var attack_aim_with_mouse: bool = true
@export var dash_aim_with_mouse: bool = false

var hitstopping: bool = false

@export var max_health: int = 5
var health: int = 5

var i_time: float = 1.0
var i_timer: float = 0.0

var hurt_time: float = 0.25
var hurt_timer: float = 0.0

@export var counter_data: AttackData

var parry_window: float = 0.2
var parry_recovery: float = 0.3
var parry_cooldown_time: float = 1.0
var parry_cooldown_timer: float = 0.0
var parry_timer: float = 0.0
var parry_i_time: float = 0.4


func _ready():
	Engine.time_scale = 1.0
	add_to_group("player")
	health = max_health
	$Hurtbox.hit_received.connect(_on_hurtbox_hit)
	
	attack_shape.disabled = true
	attack_shape.visible = false
	if attack_data == null:
		attack_data = AttackData.new()
		
	if counter_data == null:
		counter_data = attack_data	

func _physics_process(delta: float) -> void:
	update_timers(delta)
	
	match state:
		State.NORMAL:
			normal_state(delta)
		State.DASH:
			dash_state(delta)
		State.HURT:
			hurt_state(delta)
		State.PARRY:
			parry_state(delta)

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
	attack_cooldown_timer = max(attack_cooldown_timer - delta, 0.0)
	parry_cooldown_timer = max(parry_cooldown_timer - delta, 0.0)
	i_timer = max(i_timer - delta, 0.0)
	
	var tint := Color.WHITE #replace later with animations
	if state == State.PARRY:
		tint = Color(0.5, 0.8, 1.0) if parry_timer < parry_window else Color(0.7, 0.7, 0.7)
	if i_timer > 0.0:
		tint.a = 0.4 if int(i_timer * 20.0) % 2 == 0 else 1.0
	modulate = tint

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
		cancel_attack()
		
		var input = get_aim(dash_aim_with_mouse)
		
		if input != Vector2.ZERO:
			dash_direction = Vector2.from_angle(snappedf(input.angle(), PI / 4.0)) #45
			dash_direction = Vector2(roundi(dash_direction.x), roundi(dash_direction.y)).normalized()
			if dash_direction.x != 0: #if not up or down basicaly
				facing = int(signf(dash_direction.x))
		else:
			dash_direction = Vector2(facing, 0)
		return
	
	if Input.is_action_just_pressed("attack") and not attacking and attack_cooldown_timer <= 0.0:
		start_attack()
		
	if attacking:
		update_attack(delta)
		
	if Input.is_action_just_pressed("parry") and parry_cooldown_timer <= 0.0 and not attacking:
		state = State.PARRY
		parry_timer = 0.0
		return

func get_aim(use_mouse: bool) -> Vector2:
	if use_mouse:
		var to_mouse := get_global_mouse_position() - attack_pivot.global_position
		if to_mouse.length() < 10.0:
			return Vector2.ZERO
		return to_mouse
	return Input.get_vector("left", "right", "up", "down")

func start_attack() -> void:
	attacking = true
	attack_timer = 0.0
	attack_hit_list.clear()
	
	var input = get_aim(attack_aim_with_mouse)
	
	if input == Vector2.ZERO:
		attack_direction = Vector2(facing, 0)
	else:
		attack_direction = Vector2.from_angle(snappedf(input.angle(), PI / 4.0))
	
	attack_direction = Vector2(roundi(attack_direction.x), roundi(attack_direction.y)).normalized()
	
	if is_on_floor() and attack_direction.y > 0.0:
		attack_direction = Vector2(facing if attack_direction.x == 0.0 else int(signf(attack_direction.x)), 0)
	
	attack_pivot.rotation = attack_direction.angle()
	
	if attack_direction.x != 0.0:
		facing = int(signf(attack_direction.x))
	
	print("attack: startup: ", attack_direction)

func update_attack(delta: float):
	
	attack_timer += delta
	var was_active = not attack_shape.disabled
	var is_active = attack_timer >= attack_startup and attack_timer < (attack_startup + attack_active)
	
	attack_shape.disabled = not is_active
	attack_shape.visible = is_active
	
	if is_active:
		for area in attack_hitbox.get_overlapping_areas():
			if area in attack_hit_list:
				continue
			attack_hit_list.append(area)
			if area is Hurtbox:
				area.receive_hit(attack_data, attack_direction, self)
				hitstop(attack_data.hitstop)
				if area.pogoable and attack_direction.y > 0.0:
					velocity.y = pogo_velocity
					can_cut_jump = false
					can_dash = true
					coyote_timer = 0.0
	
	if is_active and not was_active:
		#print("active: active")
		pass
	elif was_active and not is_active:
		#print("active: recovery")
		pass
	
	if attack_timer >= (attack_startup + attack_active + attack_recovery):
		attack_cooldown_timer = attack_cooldown_time
		cancel_attack()
		#print("active: done")
	
func cancel_attack() -> void:
	attacking = false
	attack_shape.disabled = true

func dash_state(delta: float):
	velocity = dash_direction * dash_speed
	dash_timer -= delta
	if dash_timer <= 0.0:
		state = State.NORMAL
		dash_cooldown_timer = dash_cooldown_time
		velocity.x = clampf(velocity.x, -max_speed, max_speed)
		velocity.y = clampf(velocity.y, -max_speed * 0.5, max_speed)

func parry_state(delta: float):
	parry_timer += delta
	velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)
	velocity.y = move_toward(velocity.x, 0.0, deceleration * delta)
	
	if parry_timer >= parry_window + parry_recovery:
		state = State.NORMAL
		parry_cooldown_timer = parry_cooldown_time

func successful_parry(source: Node, dmg: float):
	print("parry!")
	i_timer = parry_i_time
	can_dash = true
	hitstop(counter_data.hitstop)
	
	counter_data.damage = dmg * 1.5
	
	if source != null and source.has_method("get_parried"):
		var to_source = (source.global_position - global_position).normalized()
		source.get_parried(counter_data, to_source)
	
	state = State.NORMAL


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
		
	if attack.parriable and state == State.PARRY and parry_timer < parry_window:
		successful_parry(source, attack.damage)
		return
	
	health -= attack.damage
	print("player hit! health: ", health)
	
	if health <= 0:
		die()
		return
	
	i_timer = i_time
	hurt_timer = hurt_time
	state = State.HURT
	cancel_attack()
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

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_hit"):
		_on_hurtbox_hit(attack_data, Vector2(-facing, 0), self)
