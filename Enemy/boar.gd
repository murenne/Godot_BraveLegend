extends enemy

enum State 
{
	IDLE,
	WALK,
	RUN,
	HURT,
	DYING
}
const KNOCKBACK_AMOUNT := 500

var pending_damage: Damage

@onready var wall_chekcker: RayCast2D = $Graphics/WallChekcker
@onready var floor_chekcker: RayCast2D = $Graphics/FloorChekcker
@onready var player_chekcker: RayCast2D = $Graphics/PlayerChekcker
@onready var calm_down_timer: Timer = $CalmDownTimer

func can_see_player()->bool:
	
	if not player_chekcker.is_colliding():
		return false
		
	return player_chekcker.get_collider() is Player

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
			if can_see_player():
				calm_down_timer.start()
		State.HURT:
			move(0.0,delta)
		State.DYING:
			move(0.0,delta)
			

func get_next_state(state: State) -> int:
	if stats.health == 0:
		return state_machine.KEEP_CURRENT if state == State.DYING else State.DYING
		
	if pending_damage :
		return State.HURT
	
	match state:
		State.IDLE:
			if can_see_player():
				return State.RUN
			if state_machine.state_time > 2:
				return State.WALK
		
		State.WALK:
			if can_see_player():
				return State.RUN
			if wall_chekcker.is_colliding() or not floor_chekcker.is_colliding():
				return State.IDLE
				
		State.RUN:
			if not can_see_player() and calm_down_timer.is_stopped():
				return State.WALK
				
		State.HURT:
			if not animation_player.is_playing():
				return State.RUN
	
	return state_machine.KEEP_CURRENT
	
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
			
		State.HURT:
			animation_player.play("hit")
			stats.health -= pending_damage.amount
			var dir := pending_damage.source.global_position.direction_to(global_position)
			velocity = dir * KNOCKBACK_AMOUNT
			
			if dir.x > 0:
				direction = Direction.LEFT
			else:
				direction = Direction.RIGHT
				
			pending_damage = null
			
		State.DYING:
			animation_player.play("die")
			
		
func _on_hurt_box_hurt(hitBox: HitBox) -> void:
	pending_damage = Damage.new()
	pending_damage.amount = 1
	pending_damage.source = hitBox.owner
