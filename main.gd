extends Node2D

signal testing_signal;
signal testing_numero_dos(mess: String);

func _ready() -> void:
	DevConsole.add_command("print", print)

func print(...args) -> String:
	var result: String = "";
	for word in args:
		result += str(word) + " ";
	return result;
