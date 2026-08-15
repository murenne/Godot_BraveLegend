extends World

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_boar_died() -> void:
	await get_tree().create_timer(1).timeout
	Game.change_scene("res://UI/game_end_screen.tscn",{
		duration = 1,
	})
