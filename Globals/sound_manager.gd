extends Node

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

	for child in node.get_children():
		setup_ui_sound(child)
