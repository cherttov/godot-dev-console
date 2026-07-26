@tool
extends EditorPlugin

const AUTOLOAD_NAME := "DevConsole"
const AUTOLOAD_PATH := "res://addons/dev-console/script/dev-console.gd"
var PLUGIN_SETTINGS := {
	"dev_console/configuration/title_label": { "default": "CONSOLE" },
	"dev_console/configuration/use_default_commands": { "default": true },
	"dev_console/configuration/view_default_commands": { "default": true },
	"dev_console/configuration/use_command_history": { "default": true },
	"dev_console/configuration/keep_size_after_closing": { "default": false },
	"dev_console/configuration/keep_position_after_closing": { "default": false },
	"dev_console/configuration/keep_topmost": { "default": true },
	"dev_console/configuration/debug_only": { "default": true },
	"dev_console/configuration/close_on_escape": { "default": true },
	"dev_console/configuration/toggle_keybind": { 
		"default": 0, # QuoteLeft
		"info": { "type": TYPE_INT, "hint": PROPERTY_HINT_ENUM, "hint_string": "QuoteLeft,Tab,F1,F2,F3,F4,F5" } 
	},
	"dev_console/theme/console_transparency": { 
		"default": 0.9, 
		"info": { "type": TYPE_FLOAT, "hint": PROPERTY_HINT_RANGE, "hint_string": "0.5,1.0,0.1" } 
	},
	"dev_console/theme/header_background": {
		"default": Color(0.204, 0.204, 0.204, 1.0),
		"info": { "type": TYPE_COLOR }
	},
	"dev_console/theme/output_background": {
		"default": Color(0.137, 0.137, 0.137, 1.0),
		"info": { "type": TYPE_COLOR }
	},
	"dev_console/theme/selection_highlight": {
		"default": Color(0.204, 0.204, 0.204, 0.878),
		"info": { "type": TYPE_COLOR }
	},
	"dev_console/theme/input_background": {
		"default": Color(0.114, 0.114, 0.114, 1.0),
		"info": { "type": TYPE_COLOR }
	}
}

# ----------- Enable/Disable + On godot startup -----------
func _enter_tree() -> void:
	for path in PLUGIN_SETTINGS:
		var data: Dictionary = PLUGIN_SETTINGS[path]
		var default_val = data["default"]
		
		# Create setting
		if not ProjectSettings.has_setting(path):
			ProjectSettings.set_setting(path, default_val)
		ProjectSettings.set_initial_value(path, default_val)
		
		# Apply custom property hints
		if data.has("info"):
			var info: Dictionary = data["info"]
			info["name"] = path
			ProjectSettings.add_property_info(info)

func _enable_plugin() -> void:
	add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)

func _disable_plugin():
	remove_autoload_singleton(AUTOLOAD_NAME)
	for path in PLUGIN_SETTINGS:
		if ProjectSettings.has_setting(path):
			ProjectSettings.clear(path)
	ProjectSettings.save()
