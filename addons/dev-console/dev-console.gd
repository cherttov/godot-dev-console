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
# Adders
func add_command(command_name: String, callback: Callable) -> void:
	if _internal_console:
		_internal_console.add_command(command_name, callback);

func add_signal(signal_name: String, target_signal: Signal) -> void:
	if _internal_console:
		_internal_console.add_signal(signal_name, target_signal);

# Deleters
func delete_command(command_name: String) -> void:
	if _internal_console:
		_internal_console.delete_command(command_name);

func delete_signal(signal_name: String) -> void:
	if _internal_console:
		_internal_console.delete_signal(signal_name);

# Has checks
func has_command(command_name: String) -> bool:
	if _internal_console:
		return _internal_console.has_command(command_name);
	else:
		return false;

func has_signal_connected(signal_name: String) -> bool:
	if _internal_console:
		return _internal_console.has_signal_connected(signal_name);
	else:
		return false;

# Getters
func get_commands() -> Dictionary[String, Callable]:
	if _internal_console:
		return _internal_console.commands;
	else:
		return { };

func get_signals() -> Dictionary[String, Dictionary]:
	if _internal_console:
		return _internal_console.signals;
	else:
		return { };

# Visibility
func is_visible() -> bool:
	if _internal_console:
		return _internal_console.visible;
	else:
		return false;

# Printers
func print_line(text: String) -> void:
	if _internal_console:
		_internal_console.print_line(text);

func print_error(text: String) -> void:
	if _internal_console:
		_internal_console.print_error(text);

func print_warning(text: String) -> void:
	if _internal_console:
		_internal_console.print_warning(text);

# Clearers
func clear_output() -> void:
	if _internal_console:
		_internal_console.clear_output();
