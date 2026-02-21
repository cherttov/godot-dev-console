@tool
extends EditorPlugin

const AUTOLOAD_NAME: String = "DevConsole";
const AUTOLOAD_PATH: String = "res://addons/dev-console/dev-console.tscn";

func _enter_tree() -> void:
	add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH);

func _exit_tree():
	remove_autoload_singleton(AUTOLOAD_NAME);
