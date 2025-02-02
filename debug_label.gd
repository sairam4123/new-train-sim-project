extends Label

func _physics_process(delta: float) -> void:
	text = DebugLog._internal_text
	DebugLog._internal_text = ""
