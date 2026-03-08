# Godot Developer Console #
Godot addon that adds an in-game developer console to run and output in-game commands.
## Configuration ##
By openning the dev-console scene in `addons/dev-console/dev-console.tscn` and selecting the root `CanvasLayer` node you can edit the parameters in the `Inspector` tab. Upon downloading the addon activate, it in the Godot plugin menu.
|Parameter                        |Value Type           |
|---------------------------------|---------------------|
|`Console Window Title`           | String              |
|`Console Toggle Keybind`         | Key                 |
|`Console Default Commands`       | Boolean             |
|`Console Use History`            | Boolean             |
|`Console Background Transparency`| Float _(0.5 to 1.0)_|
## Usage ##
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
## Example ##
<img width="576" height="324" alt="example_1" src="https://github.com/user-attachments/assets/cc00eae9-dd3b-4944-a648-6f50c1eddd57" />
