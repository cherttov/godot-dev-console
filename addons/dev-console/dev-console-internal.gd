class_name DevConsoleInternal
extends CanvasLayer

# Window sizes
var default_window_size := Vector2.ZERO
var minimum_window_size := Vector2(200, 150)
var current_resizing_size := Vector2.ZERO

# Commands dictionary
const DEF_COMMANDS := ["close", "help", "cls", "set_alpha", "get_alpha", "quit"]
var commands: Dictionary[String, Callable] = {}
var signals: Dictionary[String, Dictionary] = {} # { "signal": Signal, "callback": Callable }
var command_history: Array[String] = []
var history_index := -1

# Console root
@onready var console_viewport := $Control

# For console dragging
var dragging := false
var drag_offset := Vector2.ZERO

# For console resizing
var is_resizing := false

# Cached config (initial values pulled from DevConsole in _ready)
const TOGGLE_KEYS := {
	"QuoteLeft": KEY_QUOTELEFT, "Tab": KEY_TAB,
	"F1": KEY_F1, "F2": KEY_F2, "F3": KEY_F3, "F4": KEY_F4, "F5": KEY_F5
}
var c_title_label := "CONSOLE"
var c_use_def_cmds := true
var c_use_command_history := true
var c_view_def_cmds := true
var c_keep_size_after_closing := false
var c_keep_position_after_closing := false
var c_keep_topmost := true
var c_toggle_keybind := "QuoteLeft"
var c_close_on_escape := true

# --------- Init ---------
func _ready() -> void:
	# Pull initial config from the singleton
	set_title_label(DevConsole.title_label)
	set_alpha(DevConsole.alpha)
	set_use_default_commands(DevConsole.use_default_commands)
	set_use_command_history(DevConsole.use_command_history)
	set_view_default_commands(DevConsole.view_default_commands)
	set_keep_size_after_closing(DevConsole.keep_size_after_closing)
	set_keep_position_after_closing(DevConsole.keep_position_after_closing)
	set_keep_topmost(DevConsole.keep_topmost)
	set_toggle_keybind(DevConsole.toggle_keybind)
	set_close_on_escape(DevConsole.close_on_escape)
	
	# Some clearing
	visible = false
	%Input.release_focus()
	%Input.clear()
	
	# Connecting signals
	%CloseButton.pressed.connect(_on_close_button_pressed)
	%Input.text_submitted.connect(_on_input_submitted)
	$Control/VBoxContainer/Panel.gui_input.connect(_on_panel_gui_input)
	%ResizeAnchor.gui_input.connect(_on_anchor_gui_input)
	%ResizeAnchor.mouse_entered.connect(func(): %ResizeAnchor.self_modulate.a = 1.0)
	%ResizeAnchor.mouse_exited.connect(func(): %ResizeAnchor.self_modulate.a = 0.7)
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	
	# Some more setup for UI
	%ResizeAnchor.self_modulate.a = 0.7
	%CloseButton.focus_mode = Control.FOCUS_NONE
	%Output.focus_mode = Control.FOCUS_NONE
	%Output.scroll_following = true
	
	# Set size
	console_viewport.custom_minimum_size = minimum_window_size
	default_window_size = _compute_default_window_size()
	console_viewport.size = default_window_size

# --------- Input ---------
func _input(event: InputEvent) -> void:
	# Toggle console
	if event.is_action_pressed("dev_console_toggle"):
		toggle_console()
		get_viewport().set_input_as_handled()
		return
	
	# Return if hidden
	if not visible: return
	
	# Arrow up/down (history)
	if c_use_command_history and !command_history.is_empty():
		if event.is_action_pressed("dev_console_arrow_up"):
			_navigate_history(1)
		elif event.is_action_pressed("dev_console_arrow_down"):
			_navigate_history(-1)

	# Close on Escape (ESC)
	if c_close_on_escape and event.is_action_pressed("dev_console_escape"):
		hide_console()
		get_viewport().set_input_as_handled()
		return

	if is_resizing:
		_resize_console_window(event)
		return
	
	# This while testing had no impact on input
	#if %Input.has_focus():
		#if event is InputEventKey and not event.is_echo():
			#if event.as_text().length() == 1:
				#pass
	#else:
		#if event is InputEventKey or event is InputEventMouseButton:
			#get_viewport().set_input_as_handled()

# --------- Command & Signal Registration ---------
func add_command(command_name: String, callback: Callable) -> void:
	commands[command_name] = callback

func add_signal(signal_name: String, target_signal: Signal) -> void:
	if signals.has(signal_name): delete_signal(signal_name)
	
	var callable: Callable = func(...args): _output_signal(signal_name, args)
	signals[signal_name] = {
		"signal": target_signal,
		"callable": callable
	}
	target_signal.connect(callable)

func delete_command(command_name: String) -> void:
	if commands.has(command_name):
		commands.erase(command_name)
	else:
		push_warning("Command not found: " + command_name)

func delete_signal(signal_name: String) -> void:
	if signals.has(signal_name):
		var sig = signals[signal_name]
		if sig["signal"].is_connected(sig["callable"]):
			sig["signal"].disconnect(sig["callable"])
		signals.erase(signal_name)
	else:
		push_warning("Signal not found: " + signal_name)

# --------- Command & Signal Registry Getters ---------
func has_command(command_name: String) -> bool: return commands.has(command_name)
func has_signal_connected(signal_name: String) -> bool: return signals.has(signal_name)
func get_commands() -> Dictionary[String, Callable]: return commands.duplicate()
func get_signals() -> Dictionary[String, Dictionary]: return signals.duplicate()

# --------- Input processing ---------
func _on_input_submitted(input: String) -> void:
	var clean_input: String = input.strip_edges()
	if clean_input.is_empty():
		_focus_input(true)
		return
	
	# Command history
	if command_history.is_empty() or command_history.back() != clean_input:
		command_history.append(clean_input)
	history_index = -1
	
	# Splitting input
	var parts: PackedStringArray = clean_input.split(" ", false)
	var command_name: String = parts[0].strip_edges()
	parts.remove_at(0)
	
	# Outputting input
	output_input(clean_input)
	
	# Calling callback & outputting result
	if commands.has(command_name):
		var target: Callable = commands[command_name]
		
		# Check if args passed match the function args
		if parts.size() != target.get_argument_count():
			output_warning(
				"WARNING: " + command_name 
				+ " expects " + str(parts.size())
				+ " arguments, but received " + str(target.get_argument_count())
			)
		
		# Call & output callback/result
		var result := target.callv(parts)
		if result != null: output_callback(str(result))
	else:
		output_error("ERROR: Unknown command " + command_name)
	
	_focus_input(true)

# --------- Visibility & Opacity ---------
func show_console() -> void:
	if visible: return
	visible = true
	
	if !c_keep_position_after_closing: console_viewport.position = Vector2(0.0, 0.0)
	if !c_keep_size_after_closing: console_viewport.size = default_window_size
	
	_focus_input(true)

func hide_console() -> void:
	if not visible: return
	visible = false
	%Input.release_focus()

func toggle_console() -> void:
	if visible: hide_console()
	else: show_console()

func is_visible() -> bool: return visible
func _on_close_button_pressed() -> void: hide_console()

# --------- Default commands ---------
func _load_def_commands() -> void:
	add_command("help", _help_command)
	add_command("cls", clear_output)
	add_command("set_alpha", func(val: String) -> void: set_alpha(val.to_float()))
	add_command("get_alpha", get_alpha)
	add_command("close", hide_console)
	add_command("quit", _quit_program)

func _unload_def_commands() -> void:
	for cmd in DEF_COMMANDS:
		commands.erase(cmd)

func _help_command() -> void:
	var list := []
	for cmd in commands.keys():
		if !c_view_def_cmds and cmd in DEF_COMMANDS: continue
		list.append(cmd)
	output_callback("\n".join(list))

func _quit_program() -> void:
	get_tree().quit()

# --------- Output ---------
func _append_formatted(text: String, format: String) -> void:
	var clean := text.replace("[", "[lb]")
	%Output.append_text(format % clean + ("" if clean.ends_with("\n") else "\n"))

func output_input(text: String) -> void: _append_formatted(text, "[font_size=14][color=gray] > %s[/color][/font_size]")
func output_error(text: String) -> void: _append_formatted(text, "[color=red]%s[/color]")
func output_warning(text: String) -> void: _append_formatted(text, "[color=orange]%s[/color]")
func output_callback(text: String) -> void: _append_formatted(text, "%s")
func _output_signal(name: String, args: Array) -> void:
	var arg_text := ", ".join(args.map(func(a): return str(a)))
	%Output.append_text("[font_size=14][color=cyan] > Signal emitted: " + name.replace("[", "[lb]") + "[/color][/font_size]\n")
	%Output.append_text(arg_text.replace("[", "[lb]") + "\n")

func clear_output() -> void: %Output.clear()

# --------- Movement & Resizing ---------
func _on_panel_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.pressed
		if visible and dragging: _focus_input()
		drag_offset = console_viewport.get_global_mouse_position() - console_viewport.position
	elif event is InputEventMouseMotion and dragging:
		var new_position: Vector2 = console_viewport.get_global_mouse_position() - drag_offset
		console_viewport.position = _clamp_pos(new_position, console_viewport.size)

func _on_anchor_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		is_resizing = event.pressed
		if visible and is_resizing:
			current_resizing_size = console_viewport.size
			drag_offset = get_viewport().get_mouse_position()
			_focus_input()

func _resize_console_window(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var diff: Vector2 = get_viewport().get_mouse_position() - drag_offset
		console_viewport.size = _clamp_size(current_resizing_size + diff, console_viewport.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		is_resizing = false
		get_viewport().set_input_as_handled()

func _on_viewport_size_changed() -> void:
	default_window_size = _compute_default_window_size()
	console_viewport.size = _clamp_size(console_viewport.size, console_viewport.position)
	console_viewport.position = _clamp_pos(console_viewport.position, console_viewport.size)

# --------- Property Setters/Getters ---------
func set_title_label(value: String) -> void:
	c_title_label = value
	if is_node_ready(): %TitleLabel.text = c_title_label
func get_title_label() -> String: return c_title_label

func set_use_default_commands(value: bool) -> void:
	c_use_def_cmds = value
	_unload_def_commands()
	if value: _load_def_commands()
func get_use_default_commands() -> bool: return c_use_def_cmds

func set_use_command_history(value: bool) -> void:
	c_use_command_history = value
	if InputMap.has_action("dev_console_arrow_up"): InputMap.action_erase_events("dev_console_arrow_up")
	if InputMap.has_action("dev_console_arrow_down"): InputMap.action_erase_events("dev_console_arrow_down")
	if value:
		_add_keybind("dev_console_arrow_up", KEY_UP)
		_add_keybind("dev_console_arrow_down", KEY_DOWN)
	else:
		command_history.clear()
		history_index = -1
func get_use_command_history() -> bool: return c_use_command_history

func set_view_default_commands(value: bool) -> void: c_view_def_cmds = value
func get_view_default_commands() -> bool: return c_view_def_cmds

func set_keep_size_after_closing(value: bool) -> void: c_keep_size_after_closing = value
func get_keep_size_after_closing() -> bool: return c_keep_size_after_closing

func set_keep_position_after_closing(value: bool) -> void: c_keep_position_after_closing = value
func get_keep_position_after_closing() -> bool: return c_keep_position_after_closing

func set_keep_topmost(value: bool) -> void:
	c_keep_topmost = value
	layer = RenderingServer.CANVAS_LAYER_MAX if value else 0
func get_keep_topmost() -> bool: return c_keep_topmost

func set_toggle_keybind(value: String) -> void:
	c_toggle_keybind = value
	if InputMap.has_action("dev_console_toggle"): InputMap.action_erase_events("dev_console_toggle")
	_add_keybind("dev_console_toggle", TOGGLE_KEYS.get(value, KEY_QUOTELEFT))
func get_toggle_keybind() -> String: return c_toggle_keybind

func set_close_on_escape(value: bool) -> void:
	c_close_on_escape = value
	if InputMap.has_action("dev_console_escape"): InputMap.action_erase_events("dev_console_escape")
	if value: _add_keybind("dev_console_escape", KEY_ESCAPE)
func get_close_on_escape() -> bool: return c_close_on_escape

func set_alpha(value: float) -> void:
	$Control.modulate.a = clampf(value, 0.5, 1.0)
func get_alpha() -> float: return float($Control.modulate.a)

# --------- Helpers ---------
func _focus_input(clear: bool = false) -> void:
	if clear: %Input.clear()
	%Input.grab_focus()
	%Input.caret_column = %Input.text.length()

func _navigate_history(direction: int) -> void:
	history_index += direction
	if history_index >= command_history.size() or history_index < 0:
		history_index = -1
		_focus_input(true)
		return
	%Input.text = command_history[(command_history.size() - 1) - history_index]
	_focus_input()
	get_viewport().set_input_as_handled()

func _add_keybind(action: String, keycode: Key) -> void:
	if !InputMap.has_action(action): InputMap.add_action(action)
	var event_key := InputEventKey.new()
	event_key.physical_keycode = keycode
	InputMap.action_add_event(action, event_key)

func _clamp_size(size: Vector2, position: Vector2) -> Vector2:
	var viewport_size := get_viewport().get_visible_rect().size
	var max_size := (viewport_size - position).max(minimum_window_size)
	return size.clamp(minimum_window_size, max_size)

func _clamp_pos(position: Vector2, size: Vector2) -> Vector2:
	var viewport_size := get_viewport().get_visible_rect().size
	var max_pos := (viewport_size - size).max(Vector2.ZERO)
	return position.clamp(Vector2.ZERO, max_pos)

func _compute_default_window_size() -> Vector2:
	return get_viewport().get_visible_rect().size * 0.5
