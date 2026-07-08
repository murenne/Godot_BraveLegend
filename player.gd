extends CharacterBody2D

enum State
{
	IDLE,
	RUNNING,
	JUMPING,
	FALLING,
	LANDING,
}

const GROUND_STATES := [State.IDLE, State.RUNNING, State.LANDING]
const RUN_SPEED := 160.0
const FLOOR_ACCELERATION := RUN_SPEED / 0.2
const AIR_ACCELERATION := RUN_SPEED / 0.02
const JUMP_VELOCITY := -350.0

var default_gravity := ProjectSettings.get("physics/2d/default_gravity") as float
var is_first_tick := false


@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var coyote_timer: Timer = $CoyoteTimer
@onready var jump_request_timer: Timer = $JumpRequestTimer

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("jump"):
		jump_request_timer.start()
	if event.is_action_released("jump") and velocity.y < JUMP_VELOCITY / 2:
		velocity.y = JUMP_VELOCITY / 2

func tick_physics(state: State, delta: float) -> void:
	
	match  state:
		State.IDLE:
			move(default_gravity, delta)
				
		State.RUNNING:
			move(default_gravity, delta)

		State.JUMPING:
			move(0.0 if is_first_tick else default_gravity, delta)
				
		State.FALLING:
			move(default_gravity, delta)
			
		State.LANDING:
			stand(delta)
	
	is_first_tick = false

func move(gravity: float, delta:float)->void:
	var direction := Input.get_axis("move_left","move_right")
	
	var acceleration := FLOOR_ACCELERATION if is_on_floor() else AIR_ACCELERATION
	velocity.x = move_toward(velocity.x, direction * RUN_SPEED, acceleration * delta) 
	velocity.y += gravity * delta
	
	if not is_zero_approx(direction):
		sprite_2d.flip_h = direction < 0
	
	move_and_slide()
			

func stand(delta: float)-> void:
	var acceleration := FLOOR_ACCELERATION if is_on_floor() else AIR_ACCELERATION
	velocity.x = move_toward(velocity.x, 0.0, acceleration * delta) 
	velocity.y += default_gravity * delta
	
	move_and_slide()


func get_next_state(state : State) -> State :
	
	var can_jump := is_on_floor() or coyote_timer.time_left > 0
	var should_jump := is_on_floor() and jump_request_timer.time_left > 0
	if should_jump :
		return State.JUMPING
		
	var direction := Input.get_axis("move_left","move_right")
	var is_still := is_zero_approx(direction) and is_zero_approx(velocity.x)
	
	match  state:
		State.IDLE:
			if not is_on_floor():
				return State.FALLING
			if not is_still:
				return State.RUNNING
				
		State.RUNNING:
			if is_still:
				return State.IDLE

		State.JUMPING:
			if velocity.y >= 0:
				return State.FALLING
				
		State.FALLING:
			if is_on_floor():
				return State.LANDING if is_still else State.RUNNING
				
		State.LANDING:
			if not animation_player.is_playing():
				return State.IDLE

	return state
	
func transition_state(from: State,to: State) -> void:
	if from not in GROUND_STATES:
		coyote_timer.stop()

	match  to:
		State.IDLE:
			animation_player.play("idle")
			
		State.RUNNING:
			animation_player.play("running")
			
		State.JUMPING:
			animation_player.play("jump")
			velocity.y = JUMP_VELOCITY
			coyote_timer.stop()
			jump_request_timer.stop()
			
		State.FALLING:
			animation_player.play("falling")
			if from in GROUND_STATES:
				coyote_timer.start()
				
		State.LANDING:
			animation_player.play("landing")
			
	
	is_first_tick = true
	
