extends Control

@onready var resume_btn: Button = $VBoxContainer/Actions/HBoxContainer/ResumeBTN

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	hide()
	SoundManager.setup_ui_sound(self)
	
	visibility_changed.connect(func ():
		get_tree().paused = visible
	)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		hide()
		get_window().set_input_as_handled()

func  show_pause() -> void: 
	show()
	resume_btn.grab_focus()

func _on_resume_btn_pressed() -> void:
	hide()


func _on_quit_btn_pressed() -> void:
	Game.back_to_title()
