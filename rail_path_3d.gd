@tool
extends Path3D

@export var auto_tangents_enabled: bool = false:
	set(value):
		auto_tangents_enabled = value
		if !is_inside_tree():
			return
		_update()

@export var auto_tangents_scale: float = 0.5:
	set(value):
		auto_tangents_scale = value
		if !is_inside_tree():
			return
		_update()

var _baked_curvature: Array[float] = []
@export var bake_curvature: bool = false: 
	set(value):
		bake_curvature = value
		if !is_inside_tree():
			return
		_update()

var _curve_updated = false

func _update():
	if _curve_updated:
		return
	_curve_updated = true
	# Reset the tangents
	for i in range(curve.point_count):
		curve.set_point_in(i, Vector3(0, 0, 0))  
		curve.set_point_out(i, Vector3(0, 0, 0))
	
	if auto_tangents_enabled:
		_smooth_curve()
	
	if bake_curvature:
		_bake_curvature()
	
	_curve_updated = false

func _bake_curvature(): 
	if !curve or curve.point_count < 2:
		return INF  # Need at least 2 points for a curve
	
	for pos in curve.get_baked_points():
		var t = curve.get_closest_offset(pos)
		# Protect against sampling outside curve bounds
		var t0 = clamp(t - curve.bake_interval, 0.0, curve.get_baked_length())
		var t1 = clamp(t, 0.0, curve.get_baked_length())
		var t2 = clamp(t + curve.bake_interval, 0.0, curve.get_baked_length())
		
		# Get sample points
		var p0 = curve.sample_baked(t0)
		var p1 = curve.sample_baked(t1)
		var p2 = curve.sample_baked(t2)
		
		# First derivative (velocity vector)
		var v = (p2 - p0) / (2 * curve.bake_interval)
		
		# Second derivative (acceleration vector)
		var a = (p2 - 2 * p1 + p0) / (curve.bake_interval * curve.bake_interval)
		
		# Protect against division by zero
		if v.length() < 0.0001:
			_baked_curvature.append(INF)
			break
			
		
		# Calculate curvature using proper formula: |v × a| / |v|³
		var cross_product = v.cross(a)
		var curvature = cross_product.length() / pow(v.length(), 3)
		
		# Protect against invalid curvature
		if is_nan(curvature) || curvature < 0.000001:
			_baked_curvature.append(INF)
	
		_baked_curvature.append(1.0 / curvature)

		

func _smooth_curve() -> void:
	# Process all points
	for i in range(curve.point_count):
		var prev_pos: Vector3
		var curr_pos: Vector3 = curve.get_point_position(i)
		var next_pos: Vector3
		
		# Handle loop wrapping for previous and next points
		if curve.closed:
			prev_pos = curve.get_point_position((i - 1 + curve.point_count) % curve.point_count)
			next_pos = curve.get_point_position((i + 1) % curve.point_count)
		else:
			prev_pos = curve.get_point_position(i - 1) if i > 0 else curr_pos
			next_pos = curve.get_point_position(i + 1) if i < curve.point_count - 1 else curr_pos
		
		# Catmull-Rom tangent calculation using three points
		var tangent: Vector3 = (next_pos - prev_pos) * auto_tangents_scale
		
		# Apply tangents
		curve.set_point_in(i, -tangent)  # In tangent (reverse direction)
		curve.set_point_out(i, tangent)  # Out tangent

func _ready():
	curve_changed.connect(_update)
