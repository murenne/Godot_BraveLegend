class_name HitBox
extends Area2D

signal hit(hurtBox)

func _init() -> void:
	area_entered.connect(_on_area_enteted)

func _on_area_enteted(hurtBox:HurtBox) -> void:
	print("[Hit] %s => %s" % [owner.name, hurtBox.owner.name])
	hit.emit(hurtBox)
	hurtBox.hurt.emit(self)
	
