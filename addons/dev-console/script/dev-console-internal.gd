class_name DevConsoleInternal
extends CanvasLayer

# UI References
var control: Control
var header_panel: Panel
var title_label: Label
var close_btn: Button
var output_rtl: RichTextLabel
var input_line: LineEdit
var resize_anchor: Panel

# Window sizes
var default_window_size := Vector2.ZERO
var minimum_window_size := Vector2(200, 150)
var current_resizing_size := Vector2.ZERO

# Commands dictionary
const DEF_COMMANDS := ["help", "cls", "set_alpha", "get_alpha", "quit"]
var commands: Dictionary[String, Callable] = {}
var signals: Dictionary[String, Dictionary] = {} # { "signal": Signal, "callback": Callable }
var command_history: Array[String] = []
var history_index := -1

# For console dragging
var dragging := false
var drag_offset := Vector2.ZERO

# For console resizing
var is_resizing := false

# Cached config (initial values pulled from DevConsole in _ready)
const TOGGLE_KEYS := {
	DevConsole.ToggleKey.QUOTE_LEFT: KEY_QUOTELEFT,
	DevConsole.ToggleKey.TAB: KEY_TAB,
	DevConsole.ToggleKey.F1: KEY_F1,
	DevConsole.ToggleKey.F2: KEY_F2,
	DevConsole.ToggleKey.F3: KEY_F3,
	DevConsole.ToggleKey.F4: KEY_F4,
	DevConsole.ToggleKey.F5: KEY_F5
}
var c_title_label := "CONSOLE"
var c_use_def_cmds := true
var c_use_command_history := true
var c_view_def_cmds := true
var c_keep_size_after_closing := false
var c_keep_position_after_closing := false
var c_keep_topmost := true
var c_toggle_keybind: int = DevConsole.ToggleKey.QUOTE_LEFT
var c_close_on_escape := true

# Cached theme
var c_header_bg: Color = Color(0.204, 0.204, 0.204, 1.0)
var c_output_bg: Color = Color(0.137, 0.137, 0.137, 1.0)
var c_selection_highlight: Color = Color(0.204, 0.204, 0.204, 0.878)
var c_input_bg: Color = Color(0.114, 0.114, 0.114, 1.0)

var sb_header_bg: StyleBoxFlat
var sb_output_bg: StyleBoxFlat
var sb_input_bg: StyleBoxFlat

# --------- Init ---------
func _ready() -> void:
	# Generate UI
	_generate_ui()
	
	# Pull initial config from the singleton
	set_title_label(DevConsole.title_label)
	set_use_default_commands(DevConsole.use_default_commands)
	set_use_command_history(DevConsole.use_command_history)
	set_view_default_commands(DevConsole.view_default_commands)
	set_keep_size_after_closing(DevConsole.keep_size_after_closing)
	set_keep_position_after_closing(DevConsole.keep_position_after_closing)
	set_keep_topmost(DevConsole.keep_topmost)
	set_toggle_keybind(DevConsole.toggle_keybind)
	set_close_on_escape(DevConsole.close_on_escape)
	
	# Pull initial theme from the singleton
	set_alpha(DevConsole.alpha)
	set_header_background(DevConsole.header_background)
	set_output_background(DevConsole.output_background)
	set_selection_highlight(DevConsole.selection_highlight)
	set_input_background(DevConsole.input_background)
	
	# Some clearing
	visible = false
	input_line.release_focus()
	input_line.clear()
	
	# Connecting signals
	visibility_changed.connect(_on_visibility_changed)
	close_btn.pressed.connect(func(): visible = false)
	input_line.text_submitted.connect(_on_input_submitted)
	header_panel.gui_input.connect(_on_panel_gui_input)
	resize_anchor.gui_input.connect(_on_anchor_gui_input)
	resize_anchor.mouse_entered.connect(func(): resize_anchor.self_modulate.a = 1.0)
	resize_anchor.mouse_exited.connect(func(): resize_anchor.self_modulate.a = 0.7)
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	
	# Some more setup for UI
	resize_anchor.self_modulate.a = 0.7
	close_btn.focus_mode = Control.FOCUS_NONE
	output_rtl.focus_mode = Control.FOCUS_NONE
	output_rtl.scroll_following = true
	
	# Set size
	control.custom_minimum_size = minimum_window_size
	default_window_size = _compute_default_window_size()
	control.size = default_window_size

# --------- Input ---------
func _input(event: InputEvent) -> void:
	# Toggle console
	if event.is_action_pressed("dev_console_toggle"):
		visible = not visible
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
		visible = false
		get_viewport().set_input_as_handled()
		return

	if is_resizing:
		_resize_console_window(event)
		return

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
	if not commands.erase(command_name):
		push_warning("Command not found: " + command_name)

func delete_signal(signal_name: String) -> void:
	var sig := signals.get(signal_name)
	if sig:
		if sig["signal"].is_connected(sig["callable"]): sig["signal"].disconnect(sig["callable"])
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
	var command_name: String = parts[0]
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
func _on_visibility_changed() -> void:
	if visible:
		if !c_keep_position_after_closing: control.position = Vector2(0.0, 0.0)
		if !c_keep_size_after_closing: control.size = default_window_size
		_focus_input(true)
	else:
		input_line.release_focus()

# --------- Default commands ---------
func _load_def_commands() -> void:
	add_command("help", _help_command)
	add_command("cls", clear_output)
	add_command("set_alpha", func(val: String) -> void: set_alpha(val.to_float()))
	add_command("get_alpha", get_alpha)
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
	output_rtl.append_text(format % clean + ("" if clean.ends_with("\n") else "\n"))

func output_input(text: String) -> void: _append_formatted(text, "[font_size=14][color=gray] > %s[/color][/font_size]")
func output_error(text: String) -> void: _append_formatted(text, "[color=red]%s[/color]")
func output_warning(text: String) -> void: _append_formatted(text, "[color=orange]%s[/color]")
func output_callback(text: String) -> void: _append_formatted(text, "%s")
func _output_signal(name: String, args: Array) -> void:
	var arg_text := ", ".join(args.map(func(a): return str(a)))
	output_rtl.append_text("[font_size=14][color=cyan] > Signal emitted: " + name.replace("[", "[lb]") + "[/color][/font_size]\n")
	output_rtl.append_text(arg_text.replace("[", "[lb]") + "\n")

func clear_output() -> void: output_rtl.clear()

# --------- Movement & Resizing ---------
func _on_panel_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.pressed
		if visible and dragging: _focus_input()
		drag_offset = control.get_global_mouse_position() - control.position
	elif event is InputEventMouseMotion and dragging:
		var new_position: Vector2 = control.get_global_mouse_position() - drag_offset
		control.position = _clamp_pos(new_position, control.size)

func _on_anchor_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		is_resizing = event.pressed
		if visible and is_resizing:
			current_resizing_size = control.size
			drag_offset = get_viewport().get_mouse_position()
			_focus_input()

func _resize_console_window(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var diff: Vector2 = get_viewport().get_mouse_position() - drag_offset
		control.size = _clamp_size(current_resizing_size + diff, control.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		is_resizing = false
		get_viewport().set_input_as_handled()

func _on_viewport_size_changed() -> void:
	default_window_size = _compute_default_window_size()
	control.size = _clamp_size(control.size, control.position)
	control.position = _clamp_pos(control.position, control.size)

# --------- Property Setters/Getters ---------
func set_title_label(value: String) -> void:
	c_title_label = value
	if is_node_ready(): title_label.text = c_title_label
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

func set_toggle_keybind(value: int) -> void:
	c_toggle_keybind = value
	if InputMap.has_action("dev_console_toggle"): InputMap.action_erase_events("dev_console_toggle")
	_add_keybind("dev_console_toggle", TOGGLE_KEYS.get(value, KEY_QUOTELEFT))
func get_toggle_keybind() -> int: return c_toggle_keybind

func set_close_on_escape(value: bool) -> void:
	c_close_on_escape = value
	if InputMap.has_action("dev_console_escape"): InputMap.action_erase_events("dev_console_escape")
	if value: _add_keybind("dev_console_escape", KEY_ESCAPE)
func get_close_on_escape() -> bool: return c_close_on_escape

func set_alpha(value: float) -> void:
	control.modulate.a = clampf(value, 0.5, 1.0)
func get_alpha() -> float: return float(control.modulate.a)

func set_header_background(value: Color) -> void:
	c_header_bg = value
	if sb_header_bg: sb_header_bg.bg_color = value
func get_header_background() -> Color: return c_header_bg

func set_output_background(value: Color) -> void:
	c_output_bg = value
	if sb_output_bg: sb_output_bg.bg_color = value
func get_output_background() -> Color: return c_output_bg

func set_selection_highlight(value: Color) -> void:
	c_selection_highlight = value
	if is_instance_valid(control):
		control.theme.set_color("selection_color", "LineEdit", value)
		control.theme.set_color("selection_color", "RichTextLabel", value)
func get_selection_highlight() -> Color: return c_selection_highlight

func set_input_background(value: Color) -> void:
	c_input_bg = value
	if sb_input_bg: sb_input_bg.bg_color = value
func get_input_background() -> Color: return c_input_bg

# --------- Helpers ---------
func _focus_input(clear: bool = false) -> void:
	if clear: input_line.clear()
	input_line.grab_focus()
	input_line.caret_column = input_line.text.length()

func _navigate_history(direction: int) -> void:
	history_index += direction
	if history_index >= command_history.size() or history_index < 0:
		history_index = -1
		_focus_input(true)
		return
	input_line.text = command_history[(command_history.size() - 1) - history_index]
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

# --------- UI Setup ---------
func _generate_ui() -> void:
	# Main control
	control = Control.new()
	control.name = "Control"
	control.size = Vector2(600, 300)
	control.theme = _generate_theme()
	add_child(control)
	
	# Main vertical box
	var vbox := VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 0)
	control.add_child(vbox)
	
	# Header panel
	header_panel = Panel.new()
	header_panel.name = "Panel"
	header_panel.theme_type_variation = &"HeaderPanel"
	header_panel.custom_minimum_size = Vector2(0, 26)
	vbox.add_child(header_panel)
	
	# Header horizontal box
	var hbox := HBoxContainer.new()
	hbox.name = "HBoxContainer"
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	header_panel.add_child(hbox)
	
	# Title margin container
	var title_margin := MarginContainer.new()
	title_margin.name = "MarginContainer"
	title_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_margin.add_theme_constant_override("margin_left", 6)
	hbox.add_child(title_margin)
	
	# Title Label
	title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.unique_name_in_owner = true
	title_label.text = "CONSOLE"
	title_label.add_theme_font_size_override("font_size", 12)
	title_margin.add_child(title_label)
	
	# Close button
	close_btn = Button.new()
	close_btn.name = "CloseButton"
	close_btn.unique_name_in_owner = true
	close_btn.custom_minimum_size = Vector2(26, 0)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_END | Control.SIZE_EXPAND
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.text = "✕"
	close_btn.expand_icon = true
	close_btn.add_theme_font_size_override("font_size", 16)
	hbox.add_child(close_btn)
	
	# Output Background Panel
	var output_bg_panel := Panel.new()
	output_bg_panel.name = "OutputBgPanel"
	output_bg_panel.theme_type_variation = &"BackgroundPanel"
	output_bg_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(output_bg_panel)
	
	# Output MarginContainer
	var output_margin := MarginContainer.new()
	output_margin.name = "MarginContainer"
	output_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	output_margin.add_theme_constant_override("margin_left", 3)
	output_margin.add_theme_constant_override("margin_right", 3)
	output_bg_panel.add_child(output_margin)

	# Output RichTextLabel
	output_rtl = RichTextLabel.new()
	output_rtl.name = "Output"
	output_rtl.unique_name_in_owner = true
	output_rtl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	output_rtl.focus_mode = Control.FOCUS_ALL
	output_rtl.bbcode_enabled = true
	output_rtl.scroll_following = true
	output_rtl.selection_enabled = true
	output_margin.add_child(output_rtl)

	# Input LineEdit 
	input_line = LineEdit.new()
	input_line.name = "Input"
	input_line.unique_name_in_owner = true
	input_line.size_flags_vertical = Control.SIZE_SHRINK_END
	input_line.keep_editing_on_text_submit = true
	input_line.virtual_keyboard_enabled = false
	vbox.add_child(input_line)

	# Resize Anchor
	resize_anchor = Panel.new()
	resize_anchor.name = "ResizeAnchor"
	resize_anchor.unique_name_in_owner = true
	resize_anchor.custom_minimum_size = Vector2(10, 10)
	resize_anchor.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	resize_anchor.offset_left = -8
	resize_anchor.offset_top = -8
	resize_anchor.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	resize_anchor.grow_vertical = Control.GROW_DIRECTION_BEGIN
	resize_anchor.mouse_default_cursor_shape = Control.CURSOR_FDIAGSIZE
	resize_anchor.self_modulate = Color(1, 1, 1, 0.7)
	var sb_anchor := StyleBoxFlat.new()
	sb_anchor.bg_color = Color(0, 0, 0, 0)
	sb_anchor.border_width_right = 2
	sb_anchor.border_width_bottom = 2
	resize_anchor.add_theme_stylebox_override("panel", sb_anchor)
	control.add_child(resize_anchor)

func _generate_theme() -> Theme:
	var theme := Theme.new()
	
	# BackgroundPanel Style (Custom Type Variation of Panel)
	theme.add_type("BackgroundPanel")
	theme.set_type_variation("BackgroundPanel", "Panel")
	sb_output_bg = StyleBoxFlat.new()
	sb_output_bg.bg_color = c_output_bg
	theme.set_stylebox("panel", "BackgroundPanel", sb_output_bg)
	
	# HeaderPanel Style (Custom Type Variation of Panel)
	theme.add_type("HeaderPanel")
	theme.set_type_variation("HeaderPanel", "Panel")
	sb_header_bg = StyleBoxFlat.new()
	sb_header_bg.bg_color = c_header_bg
	theme.set_stylebox("panel", "HeaderPanel", sb_header_bg)
	
	# Button Style
	var sb_btn_normal := StyleBoxFlat.new()
	sb_btn_normal.content_margin_left = 2.0
	sb_btn_normal.content_margin_top = 2.0
	sb_btn_normal.content_margin_right = 0.0
	sb_btn_normal.content_margin_bottom = 0.0
	sb_btn_normal.bg_color = Color(0.6, 0.6, 0.6, 0.0)
	theme.set_stylebox("normal", "Button", sb_btn_normal)
	
	var sb_btn_hover := sb_btn_normal.duplicate()
	sb_btn_hover.bg_color = Color(1.0, 1.0, 1.0, 0.094)
	theme.set_stylebox("hover", "Button", sb_btn_hover)
	
	var sb_btn_pressed := sb_btn_normal.duplicate()
	sb_btn_pressed.bg_color = Color(1.0, 1.0, 1.0, 0.047)
	theme.set_stylebox("pressed", "Button", sb_btn_pressed)
	
	# LineEdit Style
	theme.set_color("selection_color", "LineEdit", c_selection_highlight)
	sb_input_bg = StyleBoxFlat.new()
	sb_input_bg.bg_color = c_input_bg
	theme.set_stylebox("focus", "LineEdit", sb_input_bg)
	theme.set_stylebox("normal", "LineEdit", sb_input_bg)
	
	# RichTextLabel Style
	theme.set_color("selection_color", "RichTextLabel", c_selection_highlight)
	theme.set_constant("paragraph_separation", "RichTextLabel", -2)
	var sb_rtl_normal := StyleBoxEmpty.new()
	sb_rtl_normal.content_margin_bottom = 2.0
	theme.set_stylebox("normal", "RichTextLabel", sb_rtl_normal)
	
	return theme
