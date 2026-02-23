# Godot Developer Console #
Godot addon that adds an in-game developer console to run and output in-game commands.
## Configuration ##
By openning the dev-console scene in `addons/dev-console/dev-console.tscn` and selecting the root `CanvasLayer` node you can edit the parameters in the `Inspector` tab. Upon downloading the addon activate, it in the Godot plugin menu.
|Parameter                 |Value Type|
|--------------------------|----------|
|`Console Window Title`    | String   |
|`Console Toggle Keybind`  | Key      |
|`Console Default Commands`| Boolean  |
|`Console Use History`     | Boolean  |
## Usage ##
In order to use, add commands with reference to a coresponding function in `_ready` function like this:
```gdscript
func _ready() -> void:
  # Register the command "test" to call the _test function
  DevConsole.add_command("test", _test);

func _test() -> String:
  return "Hello world!";
```
> **Note:** By returning a string you pass an output to the console, which will be displayed in it.
