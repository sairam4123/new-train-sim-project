extends Node3D

@export var wagon_a: RailWagon3D
@export var wagon_b: RailWagon3D
@export_range(0.0, 10e10, 10e-6, "suffix:m") var rest_length: float = 5.0
@export_range(0.0, 10e10, 10e-6, "suffix:m") var spring_coeff: float = 70_000.0
@export_range(0.0, 10e10, 10e-6, "suffix:m") var damping_coeff: float = 16_000.0

var coupling_force = 0.0

func _physics_process(delta: float) -> void:
	
	var mass_a = wagon_a.mass_kg
	var mass_b = wagon_b.mass_kg
	var total_mass = mass_a + mass_b
	
	var position_a = wagon_a.global_position
	var position_b = wagon_b.global_position
	var disp = (position_b - position_a).length() - rest_length
	var vel_a = wagon_a.velocity
	var vel_b = wagon_b.velocity
	var rel_vel = vel_b - vel_a
	DebugLog.debug("Rel Vel", rel_vel * 1000, name)
	DebugLog.debug("Disp", disp * 1000, name)
	coupling_force = -spring_coeff * disp + -damping_coeff * rel_vel
	coupling_force = clamp(coupling_force, -500_000, 500_000)
	
	var force_a = coupling_force * (mass_b / total_mass)
	var force_b = coupling_force * (mass_a / total_mass)
	
	wagon_a.effective_force += force_a
	wagon_b.effective_force += -force_b
	#print("Coupling force added")
	DebugLog.debug("Coupling Force", coupling_force / 1000, name)
	DebugLog.debug("Force on Wagon A", force_a, name)
	DebugLog.debug("Force on Wagon B", force_b, name)
