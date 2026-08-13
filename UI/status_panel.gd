extends HBoxContainer

@export var stats: Stats

@onready var health_bar: TextureProgressBar = $VBoxContainer/HealthBar
@onready var eased_health_bar: TextureProgressBar = $VBoxContainer/HealthBar/EasedHealthBar
@onready var energy_bar: TextureProgressBar = $VBoxContainer/EnergyBar


func _ready() -> void:
	if not stats:
		stats = Game.player_stats
	
	stats.health_changed.connect(update_health)
	update_health(true)
	
	stats.energy_changed.connect(update_energy)
	update_energy()

func update_health(skip_anim := false) -> void:
	var percentage := stats.health / float(stats.max_health) # 整数除整数还是整数
	health_bar.value = percentage
	
	# 补间动画
	if skip_anim:
		eased_health_bar.value = percentage
	else:
		create_tween().tween_property(eased_health_bar,"value", percentage, 0.8)
	
func update_energy() -> void:
	var percentage := stats.energy / stats.max_energy # 整数除整数还是整数
	energy_bar.value = percentage
