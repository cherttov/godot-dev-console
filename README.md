# Godot Developer Console #
Godot addon that adds an in-game developer console to run and output in-game commands.

> **Note:** All of the documentation below is written based on the newest [Release](https://github.com/cherttov/godot-dev-console/releases/latest)

## Installation ##
1. Download the [latest release](https://github.com/cherttov/godot-dev-console/releases/latest) from the repository.
2. Extract the `addons/dev-console` folder into your Godot project's `addons` directory.
3. Enable the plugin in your Project Settings and restart the Godot Engine.

## Configuration ##
After installation turn `ON` and `OFF` the plugin (if the plugin is already `OFF`, just turn it `ON`), this ensures the configuration settings load properly.
> **Note:** Before updating or deleting the asset, turn it `OFF` in the **ProjectSettings > Plugins**

By openning the `ProjectSettings` **(Project > Project Settings > General)** and scrolling down you can find the `DevConsole/Configuration` tab.  

There will be the following parameters:
|Parameter                        |Value Type           |
|---------------------------------|---------------------|
|`Window Title`                   | String              |
|`Default Commands`               | Boolean             |
|`View Default Commands`          | Boolean             |
|`Use History`                    | Boolean             |
|`Keep Size After Closing`        | Boolean             |
|`Keep Position After Closing`    | Boolean             |
|`Keep Topmost`                   | Boolean             |
|`Debug Only`                     | Boolean             |
|`Toggle Keybind`                 | String              |
|`Close On Escape`                | Boolean             |
|-                                |-                    |
|`Background Transparency`        | Float *(0.5 to 1.0)*|

> **Note:** To reset the settings just turn `OFF` and `ON` the plugin

By default the keybind for openning/closing the console is `KEY_QUOTELEFT`.

## Usage (GDScript) ##
Do not use the `DevConsoleInternal` class, intead use the `DevConsole` singleton as shown below

### Adding commands ###
**IMPORTANT:** All the parameters passed into a command must be [strings](https://docs.godotengine.org/en/stable/classes/class_string.html).  
If you need other types, you must parse them manually inside your function (e.g. `int(amount)`)

In order to use, add commands with reference to a coresponding function in `_ready` function like this:
```gdscript
func _ready() -> void:
  # Register the command "print" to call the _print function
  DevConsole.add_command("print", _print);

# Print function that takes any amount of String and returns them
func _print(first_word: String, ...others) -> String:
  var output: String = first_word;
  for word in others:
    output += " " + word;
  return output;
```
> **Note:** By returning a string you pass an output to the console, which will be displayed in it.  
(Anything other than String will be converted to String)

### Adding signals ###
Add a signal for console to listen to like this:
```gdscript
# Declare signal that emits a String
signal test(text: String);

func _ready() -> void:
  # Register the signal named "test" that passes the signal 'test' as the second parameter
  DevConsole.add_signal("test", test);

# Let's emit the signal on 'ESC" clicked
func _input(event: InputEvent) -> void:
  if event.is_action_pressed("ui_cancel"):
    emit_signal("test", "Hello World!");
```
> **Note:** If a signal has parameters (like in the example), they are shown as a regular output in the OutputBox once the signal is emitted.

### Using lambdas ###
Here is my personal example of how to use lambdas with `DevConsole`
- Documentation regarding Godot/GDScript [Lambdas](https://docs.godotengine.org/en/latest/tutorials/scripting/gdscript/gdscript_basics.html#lambda-functions)
```gdscript
DevConsole.add_command("sync_stats", func() -> String:
  return "RPCs sent: %d, Last size: %d bytes" % [
    network_manager.sync_manager.rpc_count,
    network_manager.sync_manager.last_rpc_size
  ];
);
```
> **Note:** While passing parameters to a lambda function, you must pass everything as a **String** (e.g. `str(id = 5)`)

### Other functions ###
```gdscript
DevConsole.get_commands(); # returns Dictionary[String, Callable]
DevConsole.get_signals(); # returns Dictionary[String, Dictionary[String, Variant]]

DevConsole.delete_command("print");
DevConsole.delete_signal("test");

DevConsole.has_command("print"); # returns bool
DevConsole.has_signal_connected("test"); # returs bool

DevConsole.print_line("Hello World!"); # Outputs to console white text
DevConsole.print_warning("Hello, World?"); # Outputs to console orange text
DevConsole.print_error("Goodbye World!"); # Outputs to console red text

DevConsole.clear_output(); # Clears the console

DevConsole.show(); # Opens the console in player
DevConsole.hide(); # Closes the console in player
DevConsole.toggle(); # Opens/closes the console in player based on previous state
DevConsole.is_visible(); # returns bool

DevConsole.set_alpha(0.5) # Sets the console opacity to float value (0.5 to 1.0)
DevConsole.get_alpha(); # returns float
```

## Usage (C#) ##
Read the `GDscript` usage first, as this section of **README.md** doesn't go deep into the logic of `DevConsole` methods

### Adding commands ###
- Documentation regarding Godot/C# [Callables](https://docs.godotengine.org/en/stable/classes/class_callable.html#)

```csharp
public partial class Main : Node
{
  public override void _Ready()
  {
    DevConsole.AddCommand("heal", Callable.From<string, string>(Heal));
  }

  // It is recommended to make all parameters a 'string' to avoid unexpected behavior
  private string Heal(string amount)
  {
    int parsedAmount = (int)amount;
    return $"Healed player for {parsedAmount} HP!";
  }
}
```
> **Note:** DevConsole doesn't support "...args" (params) in C#

### Adding signals ###
- Documentation regarding Godot/C# [Signals](https://docs.godotengine.org/en/stable/tutorials/scripting/c_sharp/c_sharp_signals.html)

```csharp
public partial class Main : Node
{
  [Signal]
  public delegate void TestSignalEventHandler(string message);
  
  public override void _Ready()
  {
    DevConsole.AddSignal("test_signal", new Signal(this, SignalName.TestSignal));
  }

  public override void _Input(InputEvent @event)
  {
    if (@event.IsActionPressed("ui_accept")
    {
      EmitSignal(SignalName.TestSignal, "Hello World!");
    }
  }
}
```

### Other functions ###
Almost identical to GDScript functions, but use `CamelCase` instead of `snake_case`

## Requirements ##
**Language:** GDScript/C#  
**Minimum version:** Godot 4.6.x  
**Maximum version:** Godot 4.x.x  

## AI Usage ##
AI was used to refactor the code, improve overall code structure and test edge cases.

## License ##
Distributed under the MIT License. See [LICENSE](https://github.com/cherttov/godot-dev-console/blob/main/LICENSE) for more information.

## Example output ##
<img width="694" height="403" alt="example_1" src="https://github.com/cherttov/godot-dev-console/blob/main/example_1.png" />   


*Open to suggestions for improvement. For suggestions, issues, or bugs, please use the [Issues](https://github.com/cherttov/godot-dev-console/issues) tab*
