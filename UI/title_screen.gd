extends Control

@onready var new_game_btn: Button = $VBoxContainer/NewGameBTN
@onready var v_box_container: VBoxContainer = $VBoxContainer
@onready var load_game_btn: Button = $VBoxContainer/LoadGameBTN

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	new_game_btn.grab_focus()
	load_game_btn.disabled = not Game.has_save()
	
	# 这里直接把 hover 设置成和 focus 一样的texture会更简单
	for button: Button in v_box_container.get_children():
		button.mouse_entered.connect(func():
			if not button.disabled:
				button.grab_focus()
		)
		
	SoundManager.setup_ui_sound(v_box_container)
	SoundManager.play_bgm(preload("uid://cniikp8dcxo8i"))
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_new_game_btn_pressed() -> void:
	Game.new_game()


func _on_load_game_btn_pressed() -> void:
	Game.load_game()


func _on_exit_game_btn_pressed() -> void:
	get_tree().quit()
