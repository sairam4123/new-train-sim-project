extends PathFollow3D
class_name RailWagon3D

@export_range(0.0, 10e10, 1e-6, "suffix:kg") var mass_kg = 22000.0
@export_range(0.0, 10e10, 1e-6, "suffix:hp") var power_output_hp = 6500.0
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

var frontal_area = 13.4118 # (w*h)

var throttle = 0.0
var velocity = 0.0000001
var brake = 0.0

var effective_force = 0.0

func _ready():
	Engine.set_physics_ticks_per_second(240)

func _physics_process(delta: float) -> void:
	var long_forces = _update_longitudinal(delta)
	var coup_forces = _update_coupling_forces(delta)
	var net_forces = long_forces + coup_forces
	var acceleration = net_forces / mass_kg
	velocity += acceleration * delta
	velocity = max(velocity, 1e-4)
	progress += velocity * delta

func _update_coupling_forces(delta: float) -> float:
	var force = 0.0
	
	var k = 500_000.0  # Reduced spring constant (N/m)aad
	var c = 1_000.0    # Reduced damping coefficient (N·s/m)
	var rest_length = 5.0  # Rest length of the coupler (m)
	
	# Calculate forces from the previous coach
	if prev_coach:
		var displacement = (prev_coach.global_position - global_position).length() - rest_length
		var relative_velocity = velocity - prev_coach.velocity
		force -= -k * displacement - c * relative_velocity
	
	# Calculate forces from the next coach
	if next_coach:
		var displacement = (global_position - next_coach.global_position).length() - rest_length
		var relative_velocity = next_coach.velocity - velocity
		force += -k * displacement - c * relative_velocity
		
	
	# Clamp velocity to prevent runaway values
	#velocity = clamp(velocity, -100.0, 100.0)  # Adjust limits as needed
	
	## Update position (progress)
	#progress += velocity * delta
	#
	# Debugging
	DebugLog.debug("Net Force: ", force, name)
	DebugLog.debug("Velocity: ", velocity, name)
	return force

func _update_longitudinal(delta: float) -> float:
	var weight = mass_kg * 9.81
	var effective_power = (power_output_hp / 1.341) * power_efficiency * throttle * 1000
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
	
	var rolling_resistance = 0.002 * mass_kg * 9.81 * signf(velocity) * int(!is_zero_approx(velocity))
	var drag_resistance = 0.5 * 1.225 * 1.2 * 13.4118 * velocity
	var grade_resistance = sin(get_height_gradient()) * weight
	var radius_track = get_radius_of_curvature()
	var curve_resistance: float
	if is_inf(radius_track):
		curve_resistance = 0
	else:
		curve_resistance = 600 / radius_track
	
	var resistive_forces = rolling_resistance + drag_resistance + braking_force + grade_resistance + curve_resistance
	
	var total_force = engine_force - resistive_forces
	effective_force = total_force
	
	var acceleration = total_force / mass_kg
	
	
	if !is_zero_approx(power_efficiency):
		DebugLog.debug("Velocity ms-1", velocity, name)
		DebugLog.debug("Velocity kmph", velocity * 3.6, name)
		DebugLog.debug("Acceleration ms-2", acceleration, name)
		DebugLog.debug("Throttle", throttle, name)
		DebugLog.debug("Brake", brake, name)
		DebugLog.debug("Engine Power kN", effective_power / 1000, name)
		DebugLog.debug("Effective Engine Force kN", engine_force / 1000, name)
		DebugLog.debug("Total Force kN", total_force / 1000, name)
		DebugLog.debug("Brake Force kN", braking_force / 1000, name)
		DebugLog.debug("Drag Resistance kN", drag_resistance / 1000, name)
		DebugLog.debug("Roll Resistance kN", rolling_resistance / 1000, name)
		DebugLog.debug("Height Angle rad", get_height_gradient(), name)
		DebugLog.debug("Radius of Curvature m", radius_track, name)
		DebugLog.debug("Curvature resistance kN", curve_resistance / 1000, name)
	return effective_force


func is_zero_approx_cmp(x: float, cmp: float) -> bool:
	return abs(x) < cmp 

func get_height_gradient(delta: float = 1e-02):
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
			
