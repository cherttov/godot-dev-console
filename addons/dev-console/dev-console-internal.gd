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

# Custom user settings
const CFG := "dev_console/configuration/"
const THM := "dev_console/theme/"
@onready var c_title_label := ProjectSettings.get_setting(CFG + "title_label", "CONSOLE")
@onready var c_use_def_commands := ProjectSettings.get_setting(CFG + "use_default_commands", true)
@onready var c_use_history := ProjectSettings.get_setting(CFG + "use_command_history", true)
@onready var c_view_def_commands := ProjectSettings.get_setting(CFG + "view_default_commands", true)
@onready var c_keep_size_after_closing := ProjectSettings.get_setting(CFG + "keep_size_after_closing", false)
@onready var c_keep_position_after_closing := ProjectSettings.get_setting(CFG + "keep_position_after_closing", false)
@onready var c_keep_topmost := ProjectSettings.get_setting(CFG + "keep_topmost", true)
@onready var c_toggle_keybind := ProjectSettings.get_setting(CFG + "toggle_keybind", "QuoteLeft")
@onready var c_close_on_escape := ProjectSettings.get_setting(CFG + "close_on_escape", true)
@onready var c_background_transparency := ProjectSettings.get_setting(THM + "background_transparency", 0.9)

# --------- Init ---------
func _ready() -> void:
	# Bind keybinds
	_ensure_keybinds()
	
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
	
	# Load default commands
	if c_use_def_commands: _load_default_commands()
	
	# Set label & transparency
	%TitleLabel.text = c_title_label
	$Control.modulate.a = c_background_transparency
	%ResizeAnchor.self_modulate.a = 0.7
	
	# Set rendering layer & disable focus
	if c_keep_topmost: layer = RenderingServer.CANVAS_LAYER_MAX
	%CloseButton.focus_mode = Control.FOCUS_NONE
	%Output.focus_mode = Control.FOCUS_NONE
	
	%Output.scroll_following = true;
	
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
	if c_use_history and !command_history.is_empty():
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

func get_alpha() -> float: return float($Control.modulate.a)
func set_alpha(value: String) -> void: $Control.modulate.a = clampf(value.to_float(), 0.5, 1.0)
func is_visible() -> bool: return visible
func _on_close_button_pressed() -> void: hide_console()

# --------- Default commands ---------
func _load_default_commands() -> void:
	add_command("help", _help_command)
	add_command("cls", clear_output)
	add_command("set_alpha", set_alpha)
	add_command("get_alpha", get_alpha)
	add_command("close", hide_console)
	add_command("quit", _quit_program)

func _help_command() -> void:
	var list := []
	for cmd in commands.keys():
		if !c_view_def_commands and cmd in DEF_COMMANDS: continue
		list.append(cmd)
	output_callback("\n".join(list))

func clear_output() -> void:
	%Output.clear()

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
	%Output.append_text("[font_size=14][color=cyan] > Signal emitted: " + name.replace("[", "[lb]") + "[/color][/font_size]\n");
	%Output.append_text(arg_text.replace("[", "[lb]") + "\n");

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

func _ensure_keybinds() -> void:
	var toggle_keys := { 
		"QuoteLeft": KEY_QUOTELEFT, 
		"Tab": KEY_TAB, 
		"F1": KEY_F1,
		"F2": KEY_F2,
		"F3": KEY_F3,
		"F4": KEY_F4,
		"F5": KEY_F5
	}
	_add_keybind("dev_console_toggle", toggle_keys.get(c_toggle_keybind, KEY_QUOTELEFT))
	
	if c_use_history:
		_add_keybind("dev_console_arrow_up", KEY_UP)
		_add_keybind("dev_console_arrow_down", KEY_DOWN)
	if c_close_on_escape:
		_add_keybind("dev_console_escape", KEY_ESCAPE)

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
