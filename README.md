# Godot Developer Console #
Godot addon that adds an in-game developer console to run and output in-game commands.
## Configuration ##
After installation turn `ON` and `OFF` the plugin (if the plugin is already `OFF`, just turn it `ON`), this ensures the configuration settings load properly.

By openning the `ProjectSettings` **(Project > Project Settings > General)** and scrolling down you can find the `Dev Console` tab.  
There will be the following parameters:
|Parameter                        |Value Type           |
|---------------------------------|---------------------|
|`Console Window Title`           | String              |
|`Console Default Commands`       | Boolean             |
|`Console Use History`            | Boolean             |
|`Console Background Transparency`| Float _(0.5 to 1.0)_|

By default the keybind for openning/closing the console is `KEY_QUOTELEFT`. 

To rebind the key, navigate to `res://addons/dev-console` directory, open (double-click) the `dev-console.tscn` scene, click once on the root `CanvasLayer` node (DevConsole),  
By default on the right side of the screen there will be an `Inspector` tab, at the top there is a `Console Toggle Keybind` parameter with a drop down menu of all the [Keys](https://docs.godotengine.org/en/4.6/classes/class_@globalscope.html#enum-globalscope-key) available.
## Usage ##
### Adding commands ###
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
> **Note:** By returning a string you pass an output to the console, which will be displayed in it. (Anything other than String will be converted to String)

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
> **Note:** Signal doesn't have to return any value, but if it does, it is shown as a regular output in the OutputBox once the signal is emitted.

## Example output ##
<img width="640" height="360" alt="example_1" src="https://github.com/user-attachments/assets/105d0f49-1eeb-431f-95c0-8eb4e93faceb" />

