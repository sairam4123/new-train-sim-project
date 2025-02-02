extends Node
var _internal_text = ""

func add_text(text: String):
	_internal_text += text + "\n"

func debug(var_name: String, var_value: Variant, node_name: String = ""):
	match typeof(var_value):
		TYPE_BOOL:
			add_text("%s %s %s" % [node_name, var_name, var_value])
		TYPE_STRING:
			add_text("%s %s %s" % [node_name, var_name, var_value])
		TYPE_FLOAT:
			add_text("%s %s %.2f" % [node_name, var_name, var_value])
		TYPE_INT:
			add_text("%s %s %d" % [node_name, var_name, var_value])
	
