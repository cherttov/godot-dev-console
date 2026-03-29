extends CanvasLayer

# Window sizes
var default_window_size: Vector2;
var minimum_window_size: Vector2 = Vector2(200, 150);
var current_resizing_size: Vector2 = Vector2.ZERO;

# Commands dictionary
var commands: Dictionary[String, Callable];
var signals: Dictionary[String, Dictionary];
var command_history: Array[String];
var history_index: int = -1;

# Console root
@onready var console_viewport: Control = $Control;

# For console dragging
var dragging: bool = false;
var drag_offset: Vector2 = Vector2.ZERO;

# For console resizing
var is_resizing: bool = false;

# Custom user properties
var settings_path: String = "dev_console/configuration/";
@onready var console_title_label: String = ProjectSettings.get_setting(settings_path + "title_label");
@onready var console_use_default_commands: bool = ProjectSettings.get_setting(settings_path + "use_default_commands");
@onready var console_use_history: bool = ProjectSettings.get_setting(settings_path + "use_command_history");
@onready var console_background_transparency: float = ProjectSettings.get_setting(settings_path + "background_transparency");
@onready var console_view_default_commands: bool = ProjectSettings.get_setting(settings_path + "view_default_commands");
@onready var console_keep_size_after_closing: bool = ProjectSettings.get_setting(settings_path + "keep_size_after_closing");
@onready var console_keep_position_after_closing: bool = ProjectSettings.get_setting(settings_path + "keep_position_after_closing");
@onready var console_keep_topmost: bool = ProjectSettings.get_setting(settings_path + "keep_topmost");
@onready var console_debug_only: bool = ProjectSettings.get_setting(settings_path + "debug_only");
@export var console_toggle_keybind: Key = KEY_QUOTELEFT;

# --------- Init ---------
func _ready() -> void:
	if console_debug_only and not OS.is_debug_build():
		self.queue_free();
		return;
	
	# Bind keybinds
	_ensure_keybinds();
	
	# Some clearing
	self.visible = false;
	%Input.release_focus();
	%Input.clear();
	commands = {};
	signals = {};
	command_history = [];
	
	# Connecting signals
	if !%CloseButton.pressed.is_connected(_on_close_button_pressed):
		%CloseButton.pressed.connect(_on_close_button_pressed);
	if !%Input.text_submitted.is_connected(_on_input_submitted):
		%Input.text_submitted.connect(_on_input_submitted);
	if !$Control/VBoxContainer/Panel.gui_input.is_connected(_on_panel_gui_input):
		$Control/VBoxContainer/Panel.gui_input.connect(_on_panel_gui_input);
	if !%ResizeAnchor.gui_input.is_connected(_on_anchor_gui_input):
		%ResizeAnchor.gui_input.connect(_on_anchor_gui_input);
	if !%ResizeAnchor.mouse_entered.is_connected(_on_anchor_mouse_entered):
		%ResizeAnchor.mouse_entered.connect(_on_anchor_mouse_entered);
	if !%ResizeAnchor.mouse_exited.is_connected(_on_anchor_mouse_exited):
		%ResizeAnchor.mouse_exited.connect(_on_anchor_mouse_exited);
	
	# Load default commands
	if console_use_default_commands:
		_load_default_commands();
	
	# Set label
	%TitleLabel.text = console_title_label;
	
	# Set transparency
	$Control.modulate.a = console_background_transparency;
	%ResizeAnchor.self_modulate.a = 0.7;
	
	# Set rendering layer
	if console_keep_topmost:
		self.layer = RenderingServer.CANVAS_LAYER_MAX;
	
	# Disable focus
	%CloseButton.focus_mode = Control.FOCUS_NONE;
	%Output.focus_mode = Control.FOCUS_NONE;
	
	# Set size
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size;
	var x: float = viewport_size.x / 100 * 50;
	var y: float = viewport_size.y / 100 * 50;
	console_viewport.custom_minimum_size = minimum_window_size;
	default_window_size = Vector2(x, y);
	console_viewport.size = default_window_size;

# --------- Input ---------
func _input(event: InputEvent) -> void:
	# Toggle console
	if event.is_action_pressed("dev_console_toggle"):
		self.visible = !self.visible;
		if !console_keep_position_after_closing:
			console_viewport.position = Vector2(0.0, 0.0);
		if !console_keep_size_after_closing:
			console_viewport.size = default_window_size;
		
		if self.visible:
			%Input.grab_focus();
			%Input.clear();
			%Input.caret_column = %Input.text.length();
		else:
			%Input.release_focus();
		
		get_viewport().set_input_as_handled();
	
	# Arrow up/down (history)
	if self.visible and console_use_history and !command_history.is_empty():
		if event.is_action_pressed("dev_console_arrow_up"):
			_navigate_history(1);
			get_viewport().set_input_as_handled();
		elif event.is_action_pressed("dev_console_arrow_down"):
			_navigate_history(-1);
			get_viewport().set_input_as_handled();

func _process(delta: float) -> void:
	_resize_console_window();

# --------- Command adding ---------
func add_command(command_name: String, callback: Callable) -> void:
	commands[command_name] = callback;

func add_signal(signal_name: String, target_signal: Signal) -> void:
	var callable = func(...args): _output_signal(signal_name, args);
	signals[signal_name] = {
		"signal": target_signal,
		"callable": callable
	};
	target_signal.connect(callable);

# --------- Command deleting ---------
func delete_command(command_name: String) -> void:
	if commands.has(command_name):
		commands.erase(command_name);
	else:
		push_warning("Command not found: " + command_name);

func delete_signal(signal_name: String) -> void:
	if signals.has(signal_name):
		var target_signal = signals[signal_name]["signal"];
		var callable = signals[signal_name]["callable"];
		
		if target_signal.is_connected(callable):
			target_signal.disconnect(callable);
		
		signals.erase(signal_name);
	else:
		push_warning("Signal not found: " + signal_name);

# --------- Getters ---------
func has_command(command_name: String) -> bool:
	return commands.has(command_name);

func has_signal_connected(signal_name: String) -> bool:
	return signals.has(signal_name);

func get_commands() -> Dictionary[String, Callable]:
	return commands;

func get_signals() -> Dictionary[String, Dictionary]:
	return signals;

# --------- Input submitted ---------
func _on_input_submitted(input: String) -> void:
	var clean_input: String = input.strip_edges();
	if clean_input.is_empty():
		%Input.clear();
		%Input.grab_focus();
		%Input.caret_column = %Input.text.length();
		return;
	
	# Command history
	if command_history.is_empty() or command_history.back() != clean_input:
		command_history.append(clean_input);
	history_index = -1
	
	# Splitting input
	var parts: PackedStringArray = clean_input.split(" ");
	var command_name: String = parts[0].strip_edges();
	parts.remove_at(0);
	
	# Outputting input
	_output_input(clean_input);
	
	# Calling callback & outputting result
	if commands.has(command_name):
		var result: Variant = commands[command_name].callv(parts);
		
		if result != null:
			_output_callback(str(result));
	else:
		_output_error("Unknown command.");
	
	%Input.clear();
	%Input.grab_focus();
	%Input.caret_column = %Input.text.length();

# --------- Close button ---------
func _on_close_button_pressed() -> void:
	_close_console();

# --------- Default commands ---------
func _load_default_commands() -> void:
	add_command("close", _close_console);
	add_command("help", _help_command);
	add_command("cls", _clear_output);
	add_command("set_alpha", _set_transparency);

func _close_console() -> void:
	visible = false;
	%Input.release_focus();

func _help_command() -> void:
	var command_list: String = "";
	
	for command in commands.keys():
		if !console_view_default_commands and command in ["close", "help", "cls", "set_alpha"]:
			continue;
		command_list = command_list + command + "\n";
		
	command_list.trim_suffix("\n");
	_output_callback(command_list);

func _clear_output() -> void:
	%Output.clear();

func _set_transparency(value: String) -> void:
	$Control.modulate.a = clampf(value.to_float(), 0.5, 1.0);

# --------- Output ---------
func _output_input(text: String) -> void:
	%Output.append_text("[font_size=14][color=gray] > " + text + "[/color][/font_size]\n");

func _output_error(text: String) -> void:
	%Output.append_text("[color=red]" + text + "[/color]\n");

func _output_callback(text: String) -> void:
	if text.ends_with("\n"):
		%Output.append_text(text);
	else:
		%Output.append_text(text + "\n");

func _output_signal(name: String, args: Array) -> void:
	var arg_text: String = ", ".join(args.map(func(a): return str(a)));
	%Output.append_text("[font_size=14][color=cyan] > Signal emitted: " + name + "[/color][/font_size]\n");
	%Output.append_text(arg_text + "\n");

# --------- Move console window ---------
func _on_panel_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed;
			if visible and dragging:
				%Input.grab_focus();
				%Input.caret_column = %Input.text.length();
			drag_offset = console_viewport.get_global_mouse_position() - console_viewport.position;
	elif event is InputEventMouseMotion and dragging:
		console_viewport.position = console_viewport.get_global_mouse_position() - drag_offset;

# --------- Resize console window ---------
func _on_anchor_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			is_resizing = event.pressed;
			if visible and is_resizing:
				current_resizing_size = console_viewport.size;
				drag_offset = self.get_viewport().get_mouse_position();
				
				%Input.grab_focus();
				%Input.caret_column = %Input.text.length();

func _on_anchor_mouse_entered() -> void:
	%ResizeAnchor.self_modulate.a = 1.0;

func _on_anchor_mouse_exited() -> void:
	%ResizeAnchor.self_modulate.a = 0.7;

func _resize_console_window() -> void:
	if is_resizing:
		if !self.visible:
			is_resizing = false;
		
		var mouse_pos: Vector2 = get_viewport().get_mouse_position();
		var diff: Vector2 = mouse_pos - drag_offset;
		
		var target_size: Vector2 = current_resizing_size + diff;
		console_viewport.size = target_size;
	
	if is_resizing and !Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		is_resizing = false;

# --------- Command history ---------
func _navigate_history(direction: int) -> void:
	history_index += direction;
	
	if history_index >= command_history.size():
		history_index = -1;
		%Input.clear();
	elif history_index < 0:
		history_index = 0;
	
	if history_index != -1:
		var command = command_history[(command_history.size() - 1) - history_index];
		%Input.text = command
		%Input.caret_column = %Input.text.length();
	
	%Input.grab_focus();
	%Input.caret_column = %Input.text.length();

# --------- Keybinds mapping ---------
func _ensure_keybinds() -> void:
	if !InputMap.has_action("dev_console_toggle"):
		InputMap.add_action("dev_console_toggle");
		
		var event_key: InputEventKey = InputEventKey.new();
		event_key.physical_keycode = console_toggle_keybind;
		InputMap.action_add_event("dev_console_toggle", event_key);
	
	if console_use_history:
		# Arrow up
		if !InputMap.has_action("dev_console_arrow_up"):
			InputMap.add_action("dev_console_arrow_up");
			
			var event_key: InputEventKey = InputEventKey.new();
			event_key.physical_keycode = KEY_UP;
			InputMap.action_add_event("dev_console_arrow_up", event_key);
		
		# Arrow down
		if !InputMap.has_action("dev_console_arrow_down"):
			InputMap.add_action("dev_console_arrow_down");
			
			var event_key: InputEventKey = InputEventKey.new();
			event_key.physical_keycode = KEY_DOWN;
			InputMap.action_add_event("dev_console_arrow_down", event_key);
