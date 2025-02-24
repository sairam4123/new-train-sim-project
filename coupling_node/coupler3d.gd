extends Node3D

@export var wagon_a: RailWagon3D
@export var wagon_b: RailWagon3D
@export_range(0.0, 10e10, 10e-6, "suffix:m") var rest_length: float = 5.0
@export_range(0.0, 10e10, 10e-6, "suffix:m") var spring_coeff: float = 500_000.0
@export_range(0.0, 10e10, 10e-6, "suffix:m") var damping_coeff: float = 1_000.0

var coupling_force = 0.0

func _physics_process(delta: float) -> void:
	var position_a = wagon_a.global_position
	var position_b = wagon_b.global_position
	var disp = (position_b - position_a).length() - rest_length
	var vel_a = wagon_a.velocity
	var vel_b = wagon_b.velocity
	var rel_vel = vel_b - vel_a
	DebugLog.debug("Rel Vel", rel_vel * 1000, name)
	DebugLog.debug("Disp", disp * 1000, name)
	coupling_force = -spring_coeff * disp + -damping_coeff * rel_vel
	wagon_a.effective_force += -coupling_force
	wagon_b.effective_force += coupling_force
	DebugLog.debug("Coupling Force", coupling_force, name)
