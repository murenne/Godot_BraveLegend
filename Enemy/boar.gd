extends enemy

enum State 
{
	IDLE,
	WALK,
	RUN,
}

@onready var wall_chekcker: RayCast2D = $Graphics/WallChekcker
@onready var floor_chekcker: RayCast2D = $Graphics/FloorChekcker
@onready var player_chekcker: RayCast2D = $Graphics/PlayerChekcker
@onready var calm_down_timer: Timer = $CalmDownTimer


func tick_physics(state: State,delta: float)->void:
	match state:
		State.IDLE:
			move(0.0,delta)
		State.WALK:
			move(max_speed / 3, delta)
		State.RUN:
			if wall_chekcker.is_colliding() or not floor_chekcker.is_colliding():
				direction *=-1
			move(max_speed, delta)
			if player_chekcker.is_colliding():
				calm_down_timer.start()

func get_next_state(state: State) -> State:
	if player_chekcker.is_colliding():
		return State.RUN
	
	match state:
		State.IDLE:
			if state_machine.state_time > 2:
				return State.WALK
		
		State.WALK:
			if wall_chekcker.is_colliding() or not floor_chekcker.is_colliding():
				return State.IDLE
				
		State.RUN:
			if calm_down_timer.is_stopped():
				return State.WALK
	
	return state
	
func transition_state(from: State,to: State) -> void:
	
	print("[%s] %s => %s" % [
		Engine.get_physics_frames(),
		State.keys()[from] if from != -1 else "<start>",
		State.keys()[to],
	])
	
	match to:
		State.IDLE:
			animation_player.play("idle")
			if wall_chekcker.is_colliding():
				direction *= -1
			
		State.WALK:
			animation_player.play("walk")
			if not floor_chekcker.is_colliding():
				direction *= -1
				floor_chekcker.force_raycast_update()
			
		State.RUN:
			animation_player.play("run")
			
			
			
			
			
			
