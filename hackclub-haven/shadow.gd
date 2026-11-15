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

var max_health: int = 50.0
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
	$ContactHitbox/CollisionShape2D.disabled = true
	modulate = Color(0.3, 0.5, 1.0)
	state = States.STUN
	_on_hit(attack, direction, null)

func _physics_process(delta: float) -> void:
	
	velocity.y += (descent_gravity) * delta
	
	d = player.global_position.x - global_position.x
	
	if state != States.ROLL:
		$CollisionShape2D.shape = preload("res://cylinder.tres")
		$ContactHitbox/CollisionShape2D.shape = preload("res://cylinder.tres")
	else:
		$CollisionShape2D.shape = preload("res://circle.tres")
		$ContactHitbox/CollisionShape2D.shape = preload("res://circle.tres")
	match state:
		States.IDLE:
			$AnimatedSprite2D.play("default")
			state_timer += delta
			if player == null:
				return
			if (d) != 0.0:
				facing = int(signf(d))

			$AnimatedSprite2D.flip_h = false if facing == 1 else true
			
			velocity.x = facing * movespeed
			
			if abs(d) < 150 and state_timer >= 1:
				var c = randi_range(0, 3)
				if c == 0:
					state_timer = 0.0
					state = States.CHARGE

				elif c == 1:
					state = States.SLAM
					state_timer = 0.0

			if abs(d) > 100 and state_timer <= 0:
				state_timer = 0.0
				state = States.ROLL

		States.ROLL:
			$AudioStreamPlayer2D.play()
			$AnimatedSprite2D.play("roll")
			state_timer += delta
			if is_on_wall():
				facing *= -1

			if state_timer > 0.1:
				velocity.x = facing * 300
			if state_timer >= 2.0:
				state = States.IDLE
				state_timer = 0.0
		States.SLAM:
			$AnimatedSprite2D.play("pounce")
			
			
			
			state_timer += delta
			if state_timer > 0.5 and is_on_floor():
				velocity.y = jump_velocity
			if state_timer > 0.5:
				velocity.x = d * 2
			
			if is_on_floor() and state_timer > 0.6:
				state = States.IDLE
				state_timer = 0.0
		States.CHARGE:
			$AnimatedSprite2D.play("default")
			$AnimatedSprite2D.stop()
			
			$AudioStreamPlayer2D.play()
			
			if state_timer > 0.3:
				velocity.x = facing * 400
			
			state_timer += delta
			
			if state_timer >= 0.7:
				state_timer = 0.0
				state = States.IDLE
				
			
		States.STUN:
			$AudioStreamPlayer2D.play()
			
			await get_tree().create_timer(1.0).timeout
			state = States.IDLE
			state_timer = 0.0
			$ContactHitbox/CollisionShape2D.disabled = false
			modulate = Color(1.0, 1.0, 1.0)
			
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
