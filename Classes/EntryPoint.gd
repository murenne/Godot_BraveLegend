class_name EntryPoint
extends Marker2D

@export var direction := Player.Direction.RIGHT

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	add_to_group("entry_points")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
