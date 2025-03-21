@tool
extends PathFollow3D
class_name RailWagon3D

@export_range(0.0, 10e10, 1e-6, "suffix:kg") var mass_kg = 123000.0
@export_range(0.0, 10e10, 1e-6, "suffix:N") var weight_N = 0.0:
	get:
		return mass_kg * ACC_GRAVITY
	set(value):
		weight_N = value
		mass_kg = value / ACC_GRAVITY
@export_range(0.0, 10e10, 1e-6, "suffix:hp") var power_output_hp = 6350.0
@export_range(0.0, 10e10, 1e-6, "suffix:kN") var starting_tractive_effort = 322000.0
@export_range(0.0, 1.0, 1e-6) var power_efficiency = 0.8
@export_range(0.0, 1.0, 1e-6) var brake_efficiency = 0.8
@export_range(0.0, 10e10, 1e-6, "suffix:kN") var braking_force_max = 270000.0

@export var prev_coach: RailWagon3D
@export var next_coach: RailWagon3D

const HP_TO_KW = 1.341
const KW_TO_W = 1000
const ACC_GRAVITY = 9.81
const rho = 1.225 # (Air density)
const Cd = 1.2 # (0.8-1.2) (Coefficient of drag)
const Crr = 0.002 # (0.001-0.002) Coefficient of rolling friction
const HALF = 0.5

const C1 = 600
const C2 = 0.1

@export_range(0.0, 10e10, 1e-6, "suffix:m") var frontal_area = 13.4118 # (w*h)

var throttle = 0.0
var velocity = 0.0000001
var brake = 0.0

var effective_force = 0.0

func _ready():
	if Engine.is_editor_hint():
		return
	Engine.set_physics_ticks_per_second(240)

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	#print("Coach print", name)
	var long_forces = _update_longitudinal(delta)
	#var coup_forces = _update_coupling_forces(delta)
	effective_force += long_forces
	#var acceleration = effective_force / mass_kg
	#DebugLog.debug("Acceleration ms-1", acceleration, name)
	#DebugLog.debug("Longi Forces kN", long_forces / 1000, name)
	#velocity += acceleration * delta
	#velocity = max(velocity, 1e-5)
	
	(func ():
		var acceleration = effective_force / mass_kg
		DebugLog.debug("Acceleration ms-1", acceleration, name)
		DebugLog.debug("Longi Forces kN", long_forces / 1000, name)
		velocity += acceleration * delta
		velocity = max(velocity, 1e-5)
		progress += velocity * delta
		effective_force = 0
		#print("Force is reset")
	).call_deferred()

#func _update_coupling_forces(delta: float) -> float:
	#var force = 0.0
#
	#var k = 500_000.0  # Reduced spring constant (N/m)
	#var c = 1_000.0    # Reduced damping coefficient (N·s/m)
	#var rest_length = 5.0  # Rest length of the coupler (m)
	#
	## Calculate forces from the previous coach
	#if prev_coach:
		#var disp_vec = (prev_coach.global_position - global_position)
		#var displacement = disp_vec.dot(disp_vec.normalized()) - rest_length
		#var relative_velocity = prev_coach.velocity - velocity
		#DebugLog.debug("Prev Disp m", displacement, name)
		#DebugLog.debug("Prev Rel Vel ms-1", relative_velocity, name)
		#force -= -k * displacement - c * relative_velocity
	#
	## Calculate forces from the next coach
	#if next_coach:
		#var disp_vec = global_position - next_coach.global_position
		#var displacement = (disp_vec).dot(disp_vec.normalized()) - rest_length
		#var relative_velocity = velocity - next_coach.velocity
		#DebugLog.debug("Next Disp m", displacement, name)
		#DebugLog.debug("Next Rel Vel ms-1", relative_velocity, name)
		#force += -k * displacement - c * relative_velocity
#
	## Clamp velocity to prevent runaway values
	##velocity = clamp(velocity, -100.0, 100.0)  # Adjust limits as needed
	#
	### Update position (progress)
	##progress += velocity * delta
	##
	## Debugging
	##DebugLog.debug("Net Force: ", force, name)
	#DebugLog.debug("Velocity: ", velocity, name)
	#return force

func _update_longitudinal(delta: float) -> float:
	var effective_power = (power_output_hp / HP_TO_KW) * power_efficiency * throttle * KW_TO_W
	var engine_force: float
	if is_zero_approx(velocity):
		# Static case: use maximum tractive effort at rest
		engine_force = starting_tractive_effort * throttle
	else:
		# Dynamic case: power-limited tractive effort
		engine_force = min(effective_power / abs(velocity), starting_tractive_effort)
	var braking_force: float
	var is_stationary = is_zero_approx(velocity)
	if is_stationary:
		braking_force = braking_force_max * brake_efficiency * brake * signf(velocity)
	else:
		braking_force = braking_force_max * brake_efficiency * brake * signf(velocity)
	
	var rolling_resistance = Crr * mass_kg * ACC_GRAVITY * signf(velocity) * int(!is_zero_approx(velocity))
	var drag_resistance = HALF * rho * Cd * frontal_area * velocity
	var grade_resistance = sin(get_height_gradient()) * weight_N
	var track_radius = get_radius_of_curvature()
	var curve_resistance: float
	if is_inf(track_radius):
		curve_resistance = 0
	else:
		curve_resistance = 600 / track_radius
	
	var resistive_forces = rolling_resistance + drag_resistance + braking_force + grade_resistance + curve_resistance
	
	var total_force = engine_force - resistive_forces
	
	if !is_zero_approx(power_efficiency):
		DebugLog.debug("Velocity ms-1", velocity, name)
		DebugLog.debug("Velocity kmph", velocity * 3.6, name)
		#DebugLog.debug("Acceleration ms-2", acceleration, name)
		DebugLog.debug("Throttle", throttle, name)
		DebugLog.debug("Brake", brake, name)
		DebugLog.debug("Engine Power kN", effective_power / 1000, name)
		DebugLog.debug("Effective Engine Force kN", engine_force / 1000, name)
		DebugLog.debug("Total Force kN", total_force / 1000, name)
		DebugLog.debug("Brake Force kN", braking_force / 1000, name)
		DebugLog.debug("Drag Resistance kN", drag_resistance / 1000, name)
		DebugLog.debug("Roll Resistance kN", rolling_resistance / 1000, name)
		DebugLog.debug("Height Angle rad", get_height_gradient(), name)
		DebugLog.debug("Radius of Curvature m", track_radius, name)
		DebugLog.debug("Curvature resistance kN", curve_resistance / 1000, name)
	return total_force


func is_zero_approx_cmp(x: float, cmp: float) -> bool:
	return abs(x) < cmp 

func get_height_gradient(delta: float = 5e-01):
	var path = get_parent() as Path3D
	var curve = path.curve as Curve3D
	
	var p0 = curve.sample_baked(progress - delta, true)
	var p1 = curve.sample_baked(progress, true)
	var p2 = curve.sample_baked(progress + delta, true)
	
	var height_difference = ((p1-p0).y + (p2-p1).y) / 2
	return atan2(height_difference, delta)
	
func get_radius_of_curvature() -> float:
	var path = get_parent() as Path3D
	if !path:
		return INF
	
	var curve = path.curve
	if !curve or curve.point_count < 2:
		return INF  # Need at least 2 points for a curve
	
	var t = progress
	var delta = 0.1  # Small offset for numerical differentiation
	
	# Protect against sampling outside curve bounds
	var t0 = clamp(t - delta, 0.0, curve.get_baked_length())
	var t1 = clamp(t, 0.0, curve.get_baked_length())
	var t2 = clamp(t + delta, 0.0, curve.get_baked_length())
	
	# Get sample points
	var p0 = curve.sample_baked(t0)
	var p1 = curve.sample_baked(t1)
	var p2 = curve.sample_baked(t2)
	
	# First derivative (velocity vector)
	var v = (p2 - p0) / (2 * delta)
	
	# Second derivative (acceleration vector)
	var a = (p2 - 2 * p1 + p0) / (delta * delta)
	
	# Protect against division by zero
	if v.length() < 0.0001:
		return INF  # Straight line or zero velocity
	
	# Calculate curvature using proper formula: |v × a| / |v|³
	var cross_product = v.cross(a)
	var curvature = cross_product.length() / pow(v.length(), 3)
	
	# Protect against invalid curvature
	if is_nan(curvature) || curvature < 0.000001:
		return INF
	
	return 1.0 / curvature

func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return

	if event is InputEventKey:
		if event.keycode == KEY_A and event.pressed:
			throttle += 0.1
			throttle = clamp(throttle, 0.0, 1.0)
		elif event.keycode == KEY_D and event.pressed:
			throttle -= 0.1
			throttle = clamp(throttle, 0.0, 1.0)
		
		if event.keycode == KEY_SEMICOLON and event.pressed:
			brake += 0.1
			brake = clamp(brake, 0.0, 1.0)
		elif event.keycode == KEY_APOSTROPHE and event.pressed:
			brake -= 0.1
			brake = clamp(brake, 0.0, 1.0)
			
