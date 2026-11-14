extends CharacterBody2D

enum States { IDLE, ROLL, JUMP, SLAM, CHARGE, STUN }
var state: States = States.IDLE

var movespeed: float = 100.0

var jump_peak: float = 150.0
var ascent_time: float = 0.4
var descent_time: float = 0.35
var jump_velocity = ((2 * jump_peak) / ascent_time) * -1
var ascent_gravity = ((-2 * jump_peak) / (ascent_time * ascent_time)) * -1
var descent_gravity = ((-2 * jump_peak) / (descent_time * descent_time)) * -1

var max_health: int = 20.0
var health: int 
var facing: int = -1
var player: Node2D
var d
var state_timer: float = 0.0

@export var contact_attack : AttackData

func _ready() -> void:
	health = max_health
	state = States.IDLE
	$Hurtbox.hit_received.connect(_on_hit)
	player = get_tree().get_first_node_in_group("player")
	if contact_attack == null:
		contact_attack = AttackData.new()


func get_parried(attack: AttackData, direction: Vector2):
	$ContactHitbox.disabled = true
	modulate = Color(0.3, 0.5, 1.0)
	state = States.STUN
	_on_hit(attack, direction, null)

func _physics_process(delta: float) -> void:
	
	velocity.y += (descent_gravity) * delta
	
	d = player.global_position.x - global_position.x
	
	print(d)
	
	match state:
		States.IDLE:
			state_timer -= delta
			if player == null:
				return
			if (d) != 0.0:
				facing = int(signf(d))
			
			print('idle')
			
			velocity.x = facing * movespeed
			
			if abs(d) < 150 and state_timer <= 0:
				var c = randi_range(0, 3)
				if c == 0:
					state_timer = 0.2
					state = States.CHARGE
				elif c == 1:
					velocity.y = jump_velocity
					state = States.SLAM
					state_timer = 0.2
			if abs(d) > 300 and state_timer <= 0:
				state_timer = 2.0
				state = States.ROLL
		States.ROLL:
			
			velocity.x = facing * 300
			
			state_timer -= delta
			print(state_timer)
			
			if state_timer <= 0.0:
				state = States.IDLE
		States.SLAM:
			velocity.x = facing * movespeed
			
			if is_on_floor():
				state = States.IDLE
		States.CHARGE:
			
			velocity.x = facing * 400
			
			state_timer -= delta
			
			print(state_timer)
			
			print('charge')
			
			if state_timer <= 0.0:
				state_timer = 1.0
				state = States.IDLE
				
			
		States.STUN:
			await get_tree().create_timer(2.0).timeout
			state = States.IDLE
			
	velocity.x = move_toward(velocity.x, 0.0, 2000 * delta)
	
			
	move_and_slide()
	check_contact()

func check_contact() -> void:
	for area in $ContactHitbox.get_overlapping_areas():
		if area is Hurtbox:
			var push = (area.global_position - global_position).normalized()
			area.receive_hit(contact_attack, push, self)

func _on_hit(attack: AttackData, direction: Vector2, _source: Node) -> void:
	health -= attack.damage
	print("enemy hit! health: ", health)
	
	velocity.x = direction.x * attack.knockback
	
	if health <= 0:
		get_tree().change_scene_to_file("res://win.tscn")
		return
	flash()

func flash() -> void:
	modulate = Color(3, 3, 3)
	await get_tree().create_timer(0.08, true, false, true).timeout
	modulate = Color.WHITE
