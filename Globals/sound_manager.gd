extends Node

enum Bus{ MASTER, SFX, BGM }

@onready var sfx: Node = $SFX
@onready var bgm_player: AudioStreamPlayer = $BGMPlayer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


func play_sfx(name: String) -> void:
	var player:=sfx.get_node(name) as AudioStreamPlayer
	if not player:
		return
	player.play()

func play_bgm(stream: AudioStream) -> void:
	if bgm_player.stream == stream and bgm_player.playing:
		return
	bgm_player.stream = stream	
	bgm_player.play()

func setup_ui_sound(node: Node) -> void:
	var button := node as Button
	if button:
		button.pressed.connect(play_sfx.bind("UIPressedAudio"))
		button.focus_entered.connect(play_sfx.bind("UIFocusedAudio"))

	#for button: Button in v_box_container.get_children():
		button.mouse_entered.connect(func():
			if not button.disabled:
				button.grab_focus()
		)
		
	var slider := node as Slider
	if slider:
		slider.value_changed.connect(play_sfx.bind("UIPressedAudio").unbind(1))
		slider.focus_entered.connect(play_sfx.bind("UIFocusedAudio"))
		slider.mouse_entered.connect(slider.grab_focus)
		
	for child in node.get_children():
		setup_ui_sound(child)
		
func get_volume(bus_index: int) -> float:
	var db := AudioServer.get_bus_volume_db(bus_index)
	return db_to_linear(db)
	
func  set_volume(bus_index: int, v: float) -> void:
	var db := linear_to_db(v)
	AudioServer.set_bus_volume_db(bus_index, db)
	
