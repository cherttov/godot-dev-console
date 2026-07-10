@tool
extends EditorPlugin

const AUTOLOAD_NAME: String = "DevConsole";
const AUTOLOAD_PATH: String = "res://addons/dev-console/dev-console.gd";
const CONFIG_PATH: String = "dev_console/configuration/";
const THEME_PATH: String = "dev_console/theme/";

# ----------- Enable/Disable + On godot startup -----------
func _enter_tree() -> void:
	_setup_project_settings();

func _enable_plugin() -> void:
	add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH);

func _disable_plugin():
	remove_autoload_singleton(AUTOLOAD_NAME);
	_clear_project_settings();

# ----------- HELPERS -----------
func _setup_project_settings() -> void:
	# --------- CONFIGURATION SETTINGS ---------
	if !ProjectSettings.has_setting(CONFIG_PATH + "title_label"):
		ProjectSettings.set_setting(CONFIG_PATH + "title_label", "CONSOLE");
	ProjectSettings.set_initial_value(CONFIG_PATH + "title_label", "CONSOLE");
	
	if !ProjectSettings.has_setting(CONFIG_PATH + "use_default_commands"):
		ProjectSettings.set_setting(CONFIG_PATH + "use_default_commands", true);
	ProjectSettings.set_initial_value(CONFIG_PATH + "use_default_commands", true);
	
	if !ProjectSettings.has_setting(CONFIG_PATH + "view_default_commands"):
		ProjectSettings.set_setting(CONFIG_PATH + "view_default_commands", true);
	ProjectSettings.set_initial_value(CONFIG_PATH + "view_default_commands", true);
	
	if !ProjectSettings.has_setting(CONFIG_PATH + "use_command_history"):
		ProjectSettings.set_setting(CONFIG_PATH + "use_command_history", true);
	ProjectSettings.set_initial_value(CONFIG_PATH + "use_command_history", true);
	
	if !ProjectSettings.has_setting(CONFIG_PATH + "keep_size_after_closing"):
		ProjectSettings.set_setting(CONFIG_PATH + "keep_size_after_closing", false);
	ProjectSettings.set_initial_value(CONFIG_PATH + "keep_size_after_closing", false);
	
	if !ProjectSettings.has_setting(CONFIG_PATH + "keep_position_after_closing"):
		ProjectSettings.set_setting(CONFIG_PATH + "keep_position_after_closing", false);
	ProjectSettings.set_initial_value(CONFIG_PATH + "keep_position_after_closing", false);
	
	if !ProjectSettings.has_setting(CONFIG_PATH + "keep_topmost"):
		ProjectSettings.set_setting(CONFIG_PATH + "keep_topmost", true);
	ProjectSettings.set_initial_value(CONFIG_PATH + "keep_topmost", true);
	
	if !ProjectSettings.has_setting(CONFIG_PATH + "debug_only"):
		ProjectSettings.set_setting(CONFIG_PATH + "debug_only", true);
	ProjectSettings.set_initial_value(CONFIG_PATH + "debug_only", true);
	
	var toggle_keybind_hint: String = "QuoteLeft,Tab,F1,F2,F3,F4,F5";
	if !ProjectSettings.has_setting(CONFIG_PATH + "toggle_keybind"):
		ProjectSettings.set_setting(CONFIG_PATH + "toggle_keybind", "QuoteLeft");
	ProjectSettings.add_property_info({
		"name": CONFIG_PATH + "toggle_keybind",
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": toggle_keybind_hint
	});
	ProjectSettings.set_initial_value(CONFIG_PATH + "toggle_keybind", "QuoteLeft");
	
	
	if !ProjectSettings.has_setting(CONFIG_PATH + "close_on_escape"):
		ProjectSettings.set_setting(CONFIG_PATH + "close_on_escape", true);
	ProjectSettings.set_initial_value(CONFIG_PATH + "close_on_escape", true);
	
	# --------- THEME SETTINGS ---------
	if !ProjectSettings.has_setting(THEME_PATH + "background_transparency"):
		ProjectSettings.set_setting(THEME_PATH + "background_transparency", 0.9);
	ProjectSettings.add_property_info({
		"name": THEME_PATH + "background_transparency",
		"type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "0.5,1.0,0.1"
	});
	ProjectSettings.set_initial_value(THEME_PATH + "background_transparency", 0.9);

func _clear_project_settings() -> void:
	var settings_to_clear: Array[String] = [
		CONFIG_PATH + "title_label",
		CONFIG_PATH + "view_default_commands",
		CONFIG_PATH + "use_default_commands",
		CONFIG_PATH + "use_command_history",
		CONFIG_PATH + "keep_size_after_closing",
		CONFIG_PATH + "keep_position_after_closing",
		CONFIG_PATH + "keep_topmost",
		CONFIG_PATH + "debug_only",
		CONFIG_PATH + "toggle_keybind",
		CONFIG_PATH + "close_on_escape",
		THEME_PATH + "background_transparency"
	];
	
	for setting: String in settings_to_clear:
		if ProjectSettings.has_setting(setting):
			ProjectSettings.clear(setting);
	
	ProjectSettings.save();
