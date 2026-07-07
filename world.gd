extends Node2D

@onready var geometry: TileMapLayer = $Node2D/Geometry
@onready var camera_2d: Camera2D = $Player/Camera2D

func _ready() -> void:
	
	var used := geometry.get_used_rect().grow(-1) # 获得边界往里面一格.grow(-1)
	var tile_size := geometry.tile_set.tile_size # 获得每个tile的尺寸
	
	# 设置四个角的最大值，position是左上，end是右下
	camera_2d.limit_top = used.position.y * tile_size.y
	camera_2d.limit_right = used.end.x * tile_size.x
	camera_2d.limit_bottom = used.end.y * tile_size.y
	camera_2d.limit_left = used.position.x * tile_size.x
	
	# 防止最开始的时候相机移动会有延迟
	camera_2d.reset_smoothing()
