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

    #region Public methods
    // Command & Signal Registration
    public static void AddCommand(string commandName, Callable callback)
	{
		GetConsole()?.Call("add_command", commandName, callback);
	}

	public static void AddSignal(string signalName, Signal targetSignal)
	{
		GetConsole()?.Call("add_signal", signalName, targetSignal);
	}

	public static void DeleteCommand(string commandName)
	{
		GetConsole()?.Call("delete_command", commandName);
	}

	public static void DeleteSignal(string signalName)
	{
		GetConsole()?.Call("delete_signal", signalName);
	}

    // Command & Signal Registry Getters
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

    // Visibility & Opacity
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

	// Output
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

	public static void ClearOutput() 
	{
		GetConsole()?.Call("clear_output");
	}
	#endregion

	#region Properties
	public static string TitleLabel
	{
		get
		{
			var console = GetConsole();
			if (console != null) { return console.Get("title_label").AsString(); }
			return "CONSOLE";
		}
		set
		{
			GetConsole()?.Set("title_label", value);
		}
	}

	public static bool UseDefaultCommands
	{
		get
		{
            var console = GetConsole();
            if (console != null) { return console.Get("use_default_commands").AsBool(); }
            return true;
        }
		set
		{
			GetConsole()?.Set("use_default_commands", value);
		}
	}

    public static bool UseCommandHistory
    {
        get
        {
            var console = GetConsole();
            if (console != null) { return console.Get("use_command_history").AsBool(); }
            return true;
        }
        set
        {
            GetConsole()?.Set("use_command_history", value);
        }
    }

    public static bool ViewDefaultCommands
    {
        get
        {
            var console = GetConsole();
            if (console != null) { return console.Get("view_default_commands").AsBool(); }
            return true;
        }
        set
        {
            GetConsole()?.Set("view_default_commands", value);
        }
    }

    public static bool KeepSizeAfterClosing
    {
        get
        {
            var console = GetConsole();
            if (console != null) { return console.Get("keep_size_after_closing").AsBool(); }
            return false;
        }
        set
        {
            GetConsole()?.Set("keep_size_after_closing", value);
        }
    }

    public static bool KeepPositionAfterClosing
    {
        get
        {
            var console = GetConsole();
            if (console != null) { return console.Get("keep_position_after_closing").AsBool(); }
            return false;
        }
        set
        {
            GetConsole()?.Set("keep_position_after_closing", value);
        }
    }

    public static bool KeepTopmost
    {
        get
        {
            var console = GetConsole();
            if (console != null) { return console.Get("keep_topmost").AsBool(); }
            return true;
        }
        set
        {
            GetConsole()?.Set("keep_topmost", value);
        }
    }

    public static string ToggleKeybind
    {
        get
        {
            var console = GetConsole();
            if (console != null) { return console.Get("toggle_keybind").AsString(); }
            return "QuoteLeft";
        }
        set
        {
            GetConsole()?.Set("toggle_keybind", value);
        }
    }

    public static bool CloseOnEscape
    {
        get
        {
            var console = GetConsole();
            if (console != null) { return console.Get("close_on_escape").AsBool(); }
            return true;
        }
        set
        {
            GetConsole()?.Set("close_on_escape", value);
        }
    }

    public static float Alpha
	{
		get
		{
			var console = GetConsole();
			if (console != null) { return console.Get("alpha").AsSingle(); }
			return 0.9f;
		}
		set
		{
			GetConsole()?.Set("alpha", value);
		}
	}
	#endregion
}
