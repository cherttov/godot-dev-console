extends Node

enum ToggleKey {
	QUOTE_LEFT,
	TAB,
	F1,
	F2,
	F3,
	F4,
	F5
}

var _console: DevConsoleInternal = null
var _console_ready := false
var _pending_calls: Array[Callable] = []

# Onready
func _ready() -> void:
	# Don't complete initialization if debug_only in release
	if ProjectSettings.get_setting("dev_console/configuration/debug_only", true) and not OS.is_debug_build(): return
	
	_console = DevConsoleInternal.new()
	_console.ready.connect(func():
		_console_ready = true
		for call in _pending_calls: call.call()
		_pending_calls.clear()
	, CONNECT_ONE_SHOT)
	
	add_child(_console)

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
# Runtime 
var visible := false:
	set(value):
		visible = value
		if _console_ready: _console.visible = value
		else: _pending_calls.append(func(): _console.visible = value)

# Configuration
var title_label := ProjectSettings.get_setting("dev_console/configuration/title_label", "CONSOLE"):
	set(value):
		title_label = value
		if _console_ready: _console.set_title_label(value)
		else: _pending_calls.append(func(): _console.set_title_label(value))

var use_default_commands := ProjectSettings.get_setting("dev_console/configuration/use_default_commands", true):
	set(value):
		use_default_commands = value
		if _console_ready: _console.set_use_default_commands(value)
		else: _pending_calls.append(func(): _console.set_use_default_commands(value))

var use_command_history := ProjectSettings.get_setting("dev_console/configuration/use_command_history", true):
	set(value):
		use_command_history = value
		if _console_ready: _console.set_use_command_history(value)
		else: _pending_calls.append(func(): _console.set_use_command_history(value))

var view_default_commands := ProjectSettings.get_setting("dev_console/configuration/view_default_commands", true)

var keep_size_after_closing := ProjectSettings.get_setting("dev_console/configuration/keep_size_after_closing", false)

var keep_position_after_closing := ProjectSettings.get_setting("dev_console/configuration/keep_position_after_closing", false)

var keep_topmost := ProjectSettings.get_setting("dev_console/configuration/keep_topmost", true):
	set(value):
		keep_topmost = value
		if _console_ready: _console.set_keep_topmost(value)
		else: _pending_calls.append(func(): _console.set_keep_topmost(value))

var toggle_keybind: ToggleKey = ProjectSettings.get_setting("dev_console/configuration/toggle_keybind", ToggleKey.QUOTE_LEFT):
	set(value):
		toggle_keybind = value
		if _console_ready: _console.set_toggle_keybind(value)
		else: _pending_calls.append(func(): _console.set_toggle_keybind(value))

var close_on_escape := ProjectSettings.get_setting("dev_console/configuration/close_on_escape", true):
	set(value):
		close_on_escape = value
		if _console_ready: _console.set_close_on_escape(value)
		else: _pending_calls.append(func(): _console.set_close_on_escape(value))

# Theme
var alpha: float = ProjectSettings.get_setting("dev_console/theme/console_transparency", 0.9):
	set(value):
		alpha = clampf(value, 0.5, 1.0)
		if _console_ready: _console.set_alpha(alpha)
		else: _pending_calls.append(func(): _console.set_alpha(alpha))

var header_background: Color = ProjectSettings.get_setting("dev_console/theme/header_background", Color(0.204, 0.204, 0.204, 1.0)):
	set(value):
		header_background = value
		if _console_ready: _console.set_header_background(value)
		else: _pending_calls.append(func(): _console.set_header_background(value))

var output_background: Color = ProjectSettings.get_setting("dev_console/theme/output_background", Color(0.137, 0.137, 0.137, 1.0)):
	set(value):
		output_background = value
		if _console_ready: _console.set_output_background(value)
		else: _pending_calls.append(func(): _console.set_output_background(value))

var selection_highlight: Color = ProjectSettings.get_setting("dev_console/theme/selection_highlight", Color(0.204, 0.204, 0.204, 0.878)):
	set(value):
		selection_highlight = value
		if _console_ready: _console.set_selection_highlight(value)
		else: _pending_calls.append(func(): _console.set_selection_highlight(value))

var input_background: Color = ProjectSettings.get_setting("dev_console/theme/input_background", Color(0.114, 0.114, 0.114, 1.0)):
	set(value):
		input_background = value
		if _console_ready: _console.set_input_background(value)
		else: _pending_calls.append(func(): _console.set_input_background(value))
