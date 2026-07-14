extends Node

const CONSOLE_SCENE: PackedScene = preload("dev-console.tscn")
var _console: DevConsoleInternal = null
var _console_ready := false
var _pending_calls: Array[Callable] = []

# Onready
func _ready() -> void:
	# Don't complete initialization if debug_only in release
	if ProjectSettings.get_setting("dev_console/configuration/debug_only", true) and not OS.is_debug_build(): return
	
	_console = CONSOLE_SCENE.instantiate()
	_console.ready.connect(func():
		_console_ready = true
		
		if _console.has_command("set_alpha"):
			_console.add_command("set_alpha", func(val: String) -> void:
				alpha = val.to_float()
			)
		
		for call in _pending_calls: call.call()
		_pending_calls.clear()
	, CONNECT_ONE_SHOT)
	
	get_tree().root.add_child.call_deferred(_console)

# --------- PUBLIC METHODS ---------
# Command & Signal Registration
func add_command(command_name: String, callback: Callable) -> void:
	if _console_ready: _console.add_command(command_name, callback)
	else: _pending_calls.append(add_command.bind(command_name, callback))

func add_signal(signal_name: String, target_signal: Signal) -> void:
	if _console_ready: _console.add_signal(signal_name, target_signal)
	else: _pending_calls.append(add_signal.bind(signal_name, target_signal))

func delete_command(command_name: String) -> void:
	if _console_ready: _console.delete_command(command_name)
	else: _pending_calls.append(delete_command.bind(command_name))

func delete_signal(signal_name: String) -> void:
	if _console_ready: _console.delete_signal(signal_name)
	else: _pending_calls.append(delete_signal.bind(signal_name))

# Command & Signal Registry Getters
func has_command(command_name: String) -> bool:
	if _console_ready: return _console.has_command(command_name)
	return false

func has_signal_connected(signal_name: String) -> bool:
	if _console_ready: return _console.has_signal_connected(signal_name)
	return false

func get_commands() -> Dictionary[String, Callable]:
	if _console_ready: return _console.get_commands()
	return { }

func get_signals() -> Dictionary[String, Dictionary]:
	if _console_ready: return _console.get_signals()
	return { }

# Visibility & Opacity
func show() -> void:
	if _console_ready: _console.show_console()
	else: _pending_calls.append(show)

func hide() -> void:
	if _console_ready: _console.hide_console()
	else: _pending_calls.append(hide)

func toggle_visibility() -> void:
	if _console_ready: _console.toggle_console()
	else: _pending_calls.append(toggle_visibility)

func is_visible() -> bool:
	if _console_ready: return _console.is_visible()
	return false

# Output
func print_line(text: String) -> void:
	if _console_ready: _console.output_callback(text)
	else: _pending_calls.append(print_line.bind(text))

func print_error(text: String) -> void:
	if _console_ready: _console.output_error(text)
	else: _pending_calls.append(print_error.bind(text))

func print_warning(text: String) -> void:
	if _console_ready: _console.output_warning(text)
	else: _pending_calls.append(print_warning.bind(text))

func clear_output() -> void:
	if _console_ready: _console.clear_output()
	else: _pending_calls.append(clear_output)

# --------- PROPERTIES ---------
var alpha: float = 0.9:
	set(value):
		alpha = clampf(value, 0.5, 1.0)
		if _console_ready: _console.set_alpha(str(value))
		else: _pending_calls.append(func(): _console.set_alpha(str(value)))
	get:
		if _console_ready: return _console.get_alpha()
		return alpha
