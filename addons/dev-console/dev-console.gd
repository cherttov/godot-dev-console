extends Node;

# Console scene & node refs
const CONSOLE_SCENE: PackedScene = preload("dev-console.tscn");
var _internal_console: DevConsoleInternal = null;

# Onready
func _ready() -> void:
	# Don't complete initialization if debug_only in release
	var console_debug_only: bool = ProjectSettings.get_setting("dev_console/configuration/debug_only", true);
	if console_debug_only and not OS.is_debug_build():
		return;
	
	_internal_console = CONSOLE_SCENE.instantiate();
	
	get_tree().root.add_child(_internal_console);

# ------ PUBLIC METHODS ------
func add_command(command_name: String, callback: Callable) -> void:
	_internal_console.add_command(command_name, callback);

func add_signal(signal_name: String, target_signal: Signal) -> void:
	_internal_console.add_signal(signal_name, target_signal);

func delete_command(command_name: String) -> void:
	_internal_console.delete_command(command_name);

func delete_signal(signal_name: String) -> void:
	_internal_console.delete_signal(signal_name);

func has_command(command_name: String) -> bool:
	return _internal_console.has_command(command_name);

func has_signal_connected(signal_name: String) -> bool:
	return _internal_console.has_signal_connected(signal_name);

func get_commands() -> Dictionary[String, Callable]:
	return _internal_console.commands;

func get_signals() -> Dictionary[String, Dictionary]:
	return _internal_console.signals;
