class_name Teleporter
extends Interactable

@export_file("*.tscn") var path: String
@export var entry_point: String
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func interact()->void:
	super() #执行父类的同名方法
	#get_tree().change_scene_to_file(path)
	# 没法在这个修改玩家位置
	
	Game.change_scene(path,entry_point)
