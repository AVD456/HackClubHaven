extends Node2D

@export var contact_attack: AttackData

var health: float = INF
var knockback_velocity: Vector2 = Vector2.ZERO
var knockback_friction: float = 1500.0

@onready var contact_hitbox: Area2D = $ContactHitbox

func _ready() -> void:
	$Hurtbox.hit_received.connect(_on_hit)
	
func _physics_process(delta: float) -> void:
	for area in contact_hitbox.get_overlapping_areas():
		if area is Hurtbox:
			var push := (area.global_position - global_position).normalized()
			area.receive_hit(contact_attack, push, self)

func _on_hit(attack: AttackData, direction: Vector2, _source: Node) -> void:
	health -= attack.damage
	print("dummy hit!", "  from direction: ", direction)
	#knockback animations here DONT FORGET
	flash()


func check_contact() -> void:
	for area in contact_hitbox.get_overlapping_areas():
		if area is Hurtbox:
			var push := (area.global_position - global_position).normalized()
			area.receive_hit(contact_attack, push, self)


func flash():
	modulate = Color(3, 3, 3)  # brighter than white
	await get_tree().create_timer(0.08, true, false, true).timeout
	modulate = Color.WHITE
	
