extends CanvasLayer

# Commands dictionary
var commands: Dictionary[String, Callable];

# Console root
@onready var console_viewport: Control = $Control;

# For console dragging
var dragging: bool = false;
var drag_offset: Vector2 = Vector2.ZERO;

# Custom user properties
@export var console_title_label: String = "CONSOLE";
@export var console_toggle_keybind: Key = KEY_QUOTELEFT;
@export var console_use_default_commands: bool = true;

# --------- Init ---------
func _ready() -> void:
	# Bind keybinds
	_ensure_keybinds();
	
	# Some clearing
	self.visible = false;
	%Input.release_focus();
	%Input.clear();
	commands = {};
	
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
	if event.is_action_pressed("dev_console_toggle") and !%Input.has_focus():
		visible = !visible;
		
		if visible:
			%Input.grab_focus();
			%Input.clear();
		else:
			%Input.release_focus();
		
		get_viewport().set_input_as_handled();

# --------- Command adding ---------
func add_command(command_name: String, callback: Callable) -> void:
	commands[command_name] = callback;

# --------- Input submitted ---------
func _on_input_submitted(input: String) -> void:
	var clean_input: String = input.strip_edges();
	if clean_input.is_empty():
		%Input.clear();
		return;
	
	var parts: PackedStringArray = clean_input.split(" ");
	var command_name: String = parts[0].strip_edges();
	parts.remove_at(0);
	
	_output_input(clean_input);
	
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

# --------- Keybinds mapping ---------
func _ensure_keybinds() -> void:
	if !InputMap.has_action("dev_console_toggle"):
		InputMap.add_action("dev_console_toggle");
		
		var event_key: InputEventKey = InputEventKey.new();
		event_key.physical_keycode = console_toggle_keybind;
		InputMap.action_add_event("dev_console_toggle", event_key);
