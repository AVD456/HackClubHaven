class_name Hurtbox
extends Area2D

@export var pogoable: bool = true

signal hit_received(attack: AttackData, direction: Vector2, source: Node)

func receive_hit(attack: AttackData, direction: Vector2, source: Node) -> void:
	hit_received.emit(attack, direction, source)
