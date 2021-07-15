extends KinematicBody2D

enum {IDLE, WALK, JUMP, WALLCLING}
var state
onready var _animation_player = $AnimationPlayer

# variables related to gravity and movement speed
# tweak them to your desire
var walk_speed = 200	# left/right movement speed
var jump_speed = -500	# jump force
var gravity = 1200		# force of gravity
var wall_speed = 150	# speed to slide down walls
var terminal_y = 750	# maximum falling speed due to gravity
var wallkicktime = 8.0/60.0	# time to force player away from wall after a wall jump

# variables related to physics processing and inpurt handling
var velocity = Vector2()
var movement = 0
var jumpreq=false
var wasonfloor = false
var wasonwall = false
var lockwallcling = 0
var wallkick = 0
var wjumpused = false

# can the player double jump?
func canwjump():
	return true

# can the player wall cling and wall jump
func canwallgrab():
	return true

# Called when the node enters the scene tree for the first time.
func _ready():
	change_state(IDLE)

func _input(event):
	if event.is_action_pressed("jump"):
		jumpreq=true
	
func change_state(new_state):
	match new_state:
		IDLE:
			_animation_player.play("idle")
			_animation_player.advance(0)
		WALK:
			_animation_player.play("walk")
			_animation_player.advance(0)
		JUMP:
			_animation_player.play("jump")
			_animation_player.advance(0)
		WALLCLING:
			_animation_player.play("idle")
			_animation_player.advance(0)
	state = new_state

func can_jump():
	if wasonfloor or (wasonwall and lockwallcling <= 0.0):
		wjumpused = false
		return true
	if canwjump() == true:
		if not wjumpused:
			wjumpused = true
			return true


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta):
	if true: # false if forced movement, always true for out purposes
		
		# left/right input polling
		if Input.is_action_pressed("ui_right"):
			movement = 1
			if state == IDLE:
				change_state(WALK)
		elif Input.is_action_pressed("ui_left"):
			movement = -1
			if state == IDLE:
				change_state(WALK)
		else:
			movement = 0
			if wasonfloor:
				change_state(IDLE)
			
		# a bit of forced movement when kicking off a wall
		if wallkick != 0 and lockwallcling > 0.0:
			movement = wallkick
			
		# set sprite facing direction
		if movement > 0:
			$Sprite.flip_h = false
		elif movement < 0:
			$Sprite.flip_h = true
	else:
		# handle other forms of forced movement below (hitstun, etc)
		pass
		
	# jump request parsing:
	if jumpreq:
		if can_jump():
			velocity.y = jump_speed
			if state == WALLCLING:
				# set forced movement for wall jumping here
				wallkick = -movement
			else:
				# reset forced movement for wall kickoff
				wallkick = 0
			# go to jump sprite
			change_state(JUMP)
			# lock out wall cling for a bit to prevent jumping
			# and immediately greabbing the wall
			# also controls time of forced wall kickoff movement
			lockwallcling = wallkicktime
		# reset input polling vars
		jumpreq=false
		
	# jump reset, if jump is released, stop ascending
	# allows player to perform shorter jumps by tapping button,
	# longer jumps by holding button
	if !Input.is_action_pressed("jump") and velocity.y < 0:
		velocity.y = 0
		
	# set our X axis velocity based on input or forced movement
	velocity.x = movement * walk_speed
	
	# set our Y axis velocity
	# if holding a wall, used a fixed speed to slide down it
	if wasonwall && lockwallcling < 0.0:
		velocity.y = wall_speed
		change_state(WALLCLING)
	else:
	# otherwise, gravity takes over
		velocity.y += gravity * delta
		
	# set a terminal velocity, past which gravity cannot add speed
	if velocity.y > terminal_y:
		velocity.y = terminal_y
		
	# allow Godot ending physics to process:
	velocity = move_and_slide(velocity, Vector2(0, -1))
	
	# based on physics process, determine if we hit the floor:
	wasonfloor=is_on_floor()
	if wasonfloor:
		# reset vars related to vall jumping
		wallkick = 0
		lockwallcling = 0.0
		# reset animation to idle
		if state == JUMP:
			change_state(IDLE)

	# also based on physics results, see if we hit a wall
	wasonwall=is_on_wall()
	
	# if we can't wall grab, pretend we didn't hit a wall
	if !canwallgrab():
		wasonwall = false
	
	# finally, count down on the wall cling lockout and
	# wall kick forced movement timer
	if lockwallcling > 0.0:
		lockwallcling -= delta
