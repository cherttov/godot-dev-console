extends CanvasLayer

# Commands dictionary
var commands: Dictionary[String, Callable];
var command_history: Array[String];
var history_index: int = -1;

# Console root
@onready var console_viewport: Control = $Control;

# For console dragging
var dragging: bool = false;
var drag_offset: Vector2 = Vector2.ZERO;

# Custom user properties
@export var console_title_label: String = "CONSOLE";
@export var console_toggle_keybind: Key = KEY_QUOTELEFT;
@export var console_use_default_commands: bool = true;
@export var console_use_history: bool = true;

# --------- Init ---------
func _ready() -> void:
	# Bind keybinds
	_ensure_keybinds();
	
	# Some clearing
	self.visible = false;
	%Input.release_focus();
	%Input.clear();
	commands = {};
	command_history = [];
	
	# Load default commands
	if console_use_default_commands:
		_load_default_commands();
	
	# Set label
	%TitleLabel.text = console_title_label;
	
	# Set size
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size;
	var x: float = viewport_size.x / 100 * 50;
	var y: float = viewport_size.y / 100 * 50;
	console_viewport.custom_minimum_size = Vector2(x, y);

# --------- Input ---------
func _input(event: InputEvent) -> void:
	# Toggle console
	if event.is_action_pressed("dev_console_toggle"):
		visible = !visible;
		console_viewport.position = Vector2(0.0, 0.0);
		
		if visible:
			%Input.grab_focus();
			%Input.clear();
		else:
			%Input.release_focus();
		
		get_viewport().set_input_as_handled();
	
	# Arrow up/down (history)
	if visible and console_use_history and !command_history.is_empty():
		if event.is_action_pressed("dev_console_arrow_up"):
			_navigate_history(1);
		elif event.is_action_pressed("dev_console_arrow_down"):
			_navigate_history(-1);

# --------- Command adding ---------
func add_command(command_name: String, callback: Callable) -> void:
	commands[command_name] = callback;

# --------- Input submitted ---------
func _on_input_submitted(input: String) -> void:
	var clean_input: String = input.strip_edges();
	if clean_input.is_empty():
		%Input.clear();
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

# --------- Close button ---------
func _on_close_button_pressed() -> void:
	_close_console();

# --------- Default commands ---------
func _load_default_commands() -> void:
	add_command("close", _close_console);
	add_command("help", _help_command);
	add_command("cls", _clear_output);

func _close_console() -> void:
	visible = false;
	%Input.release_focus();

func _help_command() -> void:
	var command_list: String = "";
	
	for command in commands.keys():
		command_list = command_list + command + "\n";
		
	command_list.trim_suffix("\n");
	_output_callback(command_list);

func _clear_output() -> void:
	%Output.clear();

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

# --------- Move console window ---------
func _on_panel_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed;
			drag_offset = console_viewport.get_global_mouse_position() - console_viewport.position;
	elif event is InputEventMouseMotion and dragging:
		console_viewport.position = console_viewport.get_global_mouse_position() - drag_offset;

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
		%Input.caret_column = command.length();

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
