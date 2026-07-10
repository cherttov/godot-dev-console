using Godot;
using Godot.Collections;

public static class DevConsole
{
	private static Node _gdConsole;

	// Console init method
	private static Node GetConsole()
	{
		if (_gdConsole != null && GodotObject.IsInstanceValid(_gdConsole))
		{
			return _gdConsole;
		}

		if (Engine.GetMainLoop() is SceneTree tree)
		{
			_gdConsole = tree.Root.GetNode<Node>("DevConsole");

			if (_gdConsole == null)
			{
				GD.PushError("Failed to find DevConsole autoload. Check project settings.");
			}
		}

		return _gdConsole;
	}

	// Adders
	public static void AddCommand(string commandName, Callable callback)
	{
		GetConsole()?.Call("add_command", commandName, callback);
	}

	public static void AddSignal(string signalName, Signal targetSignal)
	{
		GetConsole()?.Call("add_signal", signalName, targetSignal);
	}

	// Deleters
	public static void DeleteCommand(string commandName)
	{
		GetConsole()?.Call("delete_command", commandName);
	}

	public static void DeleteSignal(string signalName)
	{
		GetConsole()?.Call("delete_signal", signalName);
	}

	// Has checks
	public static bool HasCommand(string commandName)
	{
		var console = GetConsole();
		if (console == null) { return false; }
		return console.Call("has_command", commandName).AsBool();
	}

	public static bool HasSignalConnected(string signalName)
	{
		var console = GetConsole();
		if (console == null) { return false; }
		return console.Call("has_signal_connected", signalName).AsBool();
	}

	// Getters
	public static Dictionary<string, Callable> GetCommands()
	{
		var console = GetConsole();
		if (console == null) { return new Dictionary<string, Callable>(); }
		return console.Call("get_commands").AsGodotDictionary<string, Callable>();
	}

	public static Dictionary<string, Dictionary<string, Variant>> GetSignals()
	{
		var console = GetConsole();
		if (console == null) { return new Dictionary<string, Dictionary<string, Variant>>(); }
		return console.Call("get_signals").AsGodotDictionary<string, Dictionary<string, Variant>>();
	}

	// Visibility
	public static void Show() 
	{
		GetConsole()?.Call("show");
	}

	public static void Hide() 
	{
		GetConsole()?.Call("hide");
	}

	public static void ToggleVisibility() 
	{
		GetConsole()?.Call("toggle_visibility");
	}

	public static bool IsVisible() 
	{
		var console = GetConsole();
		if (console == null) { return false; }
		return console.Call("is_visible").AsBool();
	}

	// Opacity
	public static void SetAlpha(float value) 
	{
		GetConsole()?.Call("set_alpha", value);
	}

	public static float GetAlpha() 
	{
		var console = GetConsole();
		if (console == null) { return 0f; }
		return console.Call("get_alpha").AsSingle();
	}

	// Printers
	public static void PrintLine(string text) 
	{
		GetConsole()?.Call("print_line", text);
	}

	public static void PrintError(string text) 
	{
		GetConsole()?.Call("print_error", text);
	}

	public static void PrintWarning(string text) 
	{
		GetConsole()?.Call("print_warning", text);
	}

	// Clearers
	public static void ClearOutput() 
	{
		GetConsole()?.Call("clear_output");
	}
}
