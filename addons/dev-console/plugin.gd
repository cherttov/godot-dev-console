@tool
extends EditorPlugin

const AUTOLOAD_NAME: String = "DevConsole";
const AUTOLOAD_PATH: String = "res://addons/dev-console/dev-console.tscn";

func _enable_plugin() -> void:
	add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH);
	
	# Configuration add settings
	if !ProjectSettings.has_setting("dev_console/console_title_label"):
		ProjectSettings.set_setting("dev_console/console_title_label", "CONSOLE");
	
	if !ProjectSettings.has_setting("dev_console/console_use_default_commands"):
		ProjectSettings.set_setting("dev_console/console_use_default_commands", true);
	
	if !ProjectSettings.has_setting("dev_console/console_use_command_history"):
		ProjectSettings.set_setting("dev_console/console_use_command_history", true);
	
	if !ProjectSettings.has_setting("dev_console/console_background_transparency"):
		ProjectSettings.set_setting("dev_console/console_background_transparency", 0.9);
	ProjectSettings.add_property_info({
		"name": "dev_console/console_background_transparency",
		"type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "0.5,1.0,0.1"
	});
	
	ProjectSettings.save();

func _disable_plugin():
	remove_autoload_singleton(AUTOLOAD_NAME);
	
	# Configuration delete settings
	if ProjectSettings.has_setting("dev_console/console_title_label"):
		ProjectSettings.clear("dev_console/console_title_label");
	
	if ProjectSettings.has_setting("dev_console/console_use_default_commands"):
		ProjectSettings.clear("dev_console/console_use_default_commands");
	
	if ProjectSettings.has_setting("dev_console/console_use_command_history"):
		ProjectSettings.clear("dev_console/console_use_command_history");
	
	if ProjectSettings.has_setting("dev_console/console_background_transparency"):
		ProjectSettings.clear("dev_console/console_background_transparency");
	
	ProjectSettings.save();
