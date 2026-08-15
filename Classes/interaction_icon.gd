extends AnimatedSprite2D

const STICK_DEADZONE := 0.3
const MOUSE_DEADZONE := 16

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if Input.get_connected_joypads():
		show_joypad_icon(0)
	else:
		play("Keyboard")

func _input(event: InputEvent) -> void:
	
	if(
		event is InputEventJoypadButton or 
		(event is InputEventJoypadMotion and abs(event.axis_value) > STICK_DEADZONE )
	):
		show_joypad_icon(event.device)
		
	if(
		event is InputEventKey or 
		event is InputEventMouseButton or
		(event is InputEventMouseMotion and event.velocity.length() > MOUSE_DEADZONE)
	):
		play("Keyboard")

func show_joypad_icon(device:int) -> void:
	var joypad_name := Input.get_joy_name(device)
	
	if "Nitendo" in joypad_name:
		#play("Nintendo")
		play("Xbox")
	elif "DualShock" in joypad_name or "PS" in joypad_name:
		#play("PlayStation")
		play("Xbox")
	else:
		play("Xbox")
