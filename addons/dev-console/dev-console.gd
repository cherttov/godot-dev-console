extends Node;

# Console scene & node refs
const CONSOLE_SCENE: PackedScene = preload("dev-console.tscn");
var _internal_console: DevConsoleInternal = null;
var _console_ready: bool = false;
var _pending_calls: Array[Callable] = [];

# Onready
func _ready() -> void:
	# Don't complete initialization if debug_only in release
	var console_debug_only: bool = ProjectSettings.get_setting("dev_console/configuration/debug_only", true);
	if console_debug_only and not OS.is_debug_build():
		return;
	
	_internal_console = CONSOLE_SCENE.instantiate();
	_internal_console.ready.connect(_on_internal_console_ready, CONNECT_ONE_SHOT);
	
	get_tree().root.add_child.call_deferred(_internal_console);

func _on_internal_console_ready():
	_console_ready = true;
	for call in _pending_calls:
		call.call();
	_pending_calls.clear();

# ------ PUBLIC METHODS ------
# Adders
func add_command(command_name: String, callback: Callable) -> void:
	if _console_ready:
		_internal_console.add_command(command_name, callback);
	else:
		_pending_calls.append(add_command.bind(command_name, callback))

func add_signal(signal_name: String, target_signal: Signal) -> void:
	if _console_ready:
		_internal_console.add_signal(signal_name, target_signal);
	else:
		_pending_calls.append(add_signal.bind(signal_name, target_signal))

# Deleters
func delete_command(command_name: String) -> void:
	if _console_ready:
		_internal_console.delete_command(command_name);
	else:
		_pending_calls.append(delete_command.bind(command_name));

func delete_signal(signal_name: String) -> void:
	if _console_ready:
		_internal_console.delete_signal(signal_name);
	else:
		_pending_calls.append(delete_signal.bind(signal_name));

# Has checks
func has_command(command_name: String) -> bool:
	if _console_ready:
		return _internal_console.has_command(command_name);
	return false;

func has_signal_connected(signal_name: String) -> bool:
	if _console_ready:
		return _internal_console.has_signal_connected(signal_name);
	return false;

# Getters
func get_commands() -> Dictionary[String, Callable]:
	if _console_ready:
		return _internal_console.commands;
	return { };

func get_signals() -> Dictionary[String, Dictionary]:
	if _console_ready:
		return _internal_console.signals;
	return { };

# Visibility
func show() -> void:
	if _console_ready:
		_internal_console.show_console();
	else:
		_pending_calls.append(show);

func hide() -> void:
	if _console_ready:
		_internal_console.hide_console();
	else:
		_pending_calls.append(hide);

func toggle_visibility() -> void:
	if _console_ready:
		_internal_console.toggle_console();
	else:
		_pending_calls.append(toggle_visibility);

func is_visible() -> bool:
	if _console_ready:
		return _internal_console.visible;
	return false;

# Opacity
func set_alpha(value: float) -> void:
	if _console_ready:
		_internal_console.set_alpha(str(value));
	else:
		_pending_calls.append(set_alpha.bind(value));

func get_alpha() -> float:
	if _console_ready:
		return _internal_console.get_alpha();
	else:
		return 0.0;

# Printers
func print_line(text: String) -> void:
	if _console_ready:
		_internal_console.print_line(text);
	else:
		_pending_calls.append(print_line.bind(text));

func print_error(text: String) -> void:
	if _console_ready:
		_internal_console.print_error(text);
	else:
		_pending_calls.append(print_error.bind(text));

func print_warning(text: String) -> void:
	if _console_ready:
		_internal_console.print_warning(text);
	else:
		_pending_calls.append(print_warning.bind(text));

# Clearers
func clear_output() -> void:
	if _console_ready:
		_internal_console.clear_output();
	else:
		_pending_calls.append(clear_output);
