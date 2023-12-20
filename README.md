# Dijkstra Algorithm for Godot

![](assets/icon.png)


## What it does

Howdy!

This is a GDExtension project for the Godot game engine that introduces a DijkstraMap pathfinding node; it provides a much needed versatility currently absent from the built-in AStar pathfinding. Its main feature is the ability to populate an entire graph with the shortest paths leading toward one or more origin point(s). The total lengths of these paths and directions can then be easily looked up for any point in the graph.

Common use cases include: pre-computing pathfinding for tower-defense games, RTS games and roguelikes; listing available moves for turn-based games; and aiding in movement-related AI behaviour. You can find more examples in [this amazing article](http://www.roguebasin.com/index.php?title=Dijkstra_Maps_Visualized).

This library is written in the Rust programming language and performance should be comparable to C/C++ (approximately 10-20x faster than GDScript).

Note that the [API](./addons/dijkstra-map/doc/index.md) is now stable! Some features may be added over time.


## Installing

Note: when installing pre-compiled libraries, we support

- On linux: Ubuntu 20.04 or higher
- On macos: The latest macOS version (11 at the time of writing)
- On windows: Windows 10 or higher (presumably)

### Method 1: From the Asset Store (Recommended)

This will work for linux x64, macos x86 and windows x64 for godot 3.5.1 (for another godot version you'll probably have to use the second method):
1. In the godot editor, go to the `AssetLib` tab

    ![](assets/godot-outline-assetlib.png)

    And search for `Dijkstra Map Pathfinding`

2. Download and install the files

    ![](assets/assetlib-dijkstra_map_pathfinding-download.png)
    ![](assets/assetlib-dijkstra_map_pathfinding-install.png)

    This will install the files in `res://addons/dijkstra-map`.

### Method 2: from Github

**Note**: on linux x64, macos x86 or windows x64, you may skip steps 2-3 and use the pre-compiled libraries in `addons/dijkstra-map/dijkstra_map_library/bin/<os-name>`. They may be slightly outdated though.

1. Clone this repository.
2. Follow the gdext (Rust bindings for Godot 4) setup steps [here](https://godot-rust.github.io/book/intro/setup.html#rust).
   * Install [rustup](https://rustup.rs/) for the Rust toolchain.
3. Run `cargo build --release`. This will build the library in `target/release` (for example, on windows: `target/release/dijkstra_map_gd.dll`).
    
	Note that this might take some time as it compiles all the dependencies for the first time.

    Copy the resulting library to `addons/dijkstra-map/dijkstra_map_library/bin/<os-name>`.
4. Copy the `addons/dijkstra-map` directory into your project's `res://addons` directory.
5. Add your binary file path into the `res://addons/dijkstra-map/dijkstra_map/DijkstraMap.gdextension` file. This file tells Godot which binary to use for which system. For more info see the [GDExtension C++ example in Godot's documentation](https://docs.godotengine.org/en/stable/tutorials/scripting/gdextension/gdextension_cpp_example.html).


## Examples

There are 3 example scenes in the github repository:
* `addons/dijkstra-map/visualization_demo/visualization.tscn`

    Also available through the [asset store installation](#method-1-from-the-asset-store-recommended). Includes C# code. 
* `project_examples/turn_based_example/turn_based_example.tscn`

    The `knight` node contains export variables that can be tweaked.
* `project_examples/shared_movement_example/shared_movement_example.tscn`

Each example scene's scripts contain heavily commented code.

**Note**: The visualization example includes a C# alternate implementation that requires the .NET-enabled version of Godot to run. See [Godot C# Basics](https://docs.godotengine.org/en/stable/tutorials/scripting/c_sharp/c_sharp_basics.html) for information on how to set this up. `visualization.tscn` includes an option to toggle usage of the C# version of the script, which should be functionally identical to the GDScript version.

You can also look at the unit tests in `tests/unit/*` for examples of using the DijkstraMap API.


## Features && How-To's

#### Basic Behavior

In your Godot project, you start by creating a new DijkstraMap Node.
* First you need to specify the graph by adding points (vertices) and connections between them (edges). Unlike the built-in AStar node, DijkstraMap does not track point positions (it only ever refers to them by their ID) and the costs of the connections need to be explicitly specified. It is the developer's responsibility to keep track of the points' positions. You can add points manually with the `add_point()` and `connect_points()` methods or automatically with `add_*_grid()` methods (`add_square_grid()` or `add_hexagonal_grid()`).

* Once you've done that, you can enable or disable any points you want from the pathfinding by passing their ids to `enable_point()` or `disable_point()` (points are enabled by default).

* You then have to call `recalculate()` method with appropriate arguments: by default you only have to pass an id or a PackedInt32Array of ids of the origin point(s). This method will calculate the shortest paths from the origin point(s) to every point in the graph.

* You can then access the information using various methods. Most notably `get_cost_map()` and `get_direction_map()` which each return a dictionary, with keys of point IDs, and values of the length of the shortest path from that point or the ID of the next point along the path.

* It is also possible to get a list of all points whose paths' lengths are within a given range, using the `get_all_points_with_cost_between()` method.

* You can get the full shortest path from a given point using `get_shortest_path_from_point()` method. 

#### More Recalculate Flags

`recalculate()` method has various optional arguments that modify its behavior. It is possible to:

* Switch intended direction of movement (useful when connections are not bidirectional).

* Set maximum allowed cost for paths and/or termination points, both of which terminate the algorithm early (useful to save CPU cycles).

* Set initial costs for the input points (useful to "weigh" the origin/destination points).

* Set weights for different terrain types.

Please see the [documentation](./addons/dijkstra-map/doc/index.md) for a full explanation.

#### The Usefulness of Terrain

Points in the DijkstraMap have an optional terrain ID parameter. This feature makes it possible to re-use the same DijkstraMap node for units with different movement restrictions, without having to duplicate the entire DijkstraMap and manually modify all connection costs.

For example, let's say you have 3 unit types in your game: Footsoldier (which moves the same speed regardless of terrain), Cavalry (which moves half the speed through forests) and Wagon (which can only move on roads). First you decide on integer IDs you will use for different terrain types, for example:
```
enum Terrain {
    OTHER = -1 # Note: default terrain ID -1 is hard-coded in the DijkstraMap, and has a default weight of 1.0 unlike other types which default to INF
    ROAD, # Automatically converts to 0
    FOREST # Automatically converts to 1, ...
}
```
Now you assign these terrain IDs to the points in your DijkstraMap. This can be done while adding the points (`add_point()` method has optional second parameter for terrain ID) or even after they were added (via `set_terrain_for_point()` method). By default (if not specified otherwise), points get terrain ID of `-1`.

When recalculating the DijkstraMap for the Cavalry, we specify "terrain_weights" optional argument as follows:
```gdscript
my_dijkstra_map.recalculate(origin_point, {"terrain_weights": {Terrain.FOREST: 2.0} } )
```
Now, during this recalculation, connection costs of forest points are doubled* (ie. movement speed is halved) and the shortest paths will try to avoid forest points, to minimize travel time. Specifically, path segments will only lead through forests, if they are half the length of alternative paths. 

* *important note, if terrain_weights doesn't specify a terrain present in the dijkstra, this terrain will be inaccessible (cost = INF).
* *note: connection costs between two points are multiplied by the average of their respective weights. All terrain weights that remain unspecified in the argument have default terrain weight of `1.0`.

When recalculating the DijkstraMap for the Wagon, we specify "terrain weights" optional argument as follows:
```
my_dijkstra_map.recalculate(origin_point, {"terrain_weights": {Terrain.FOREST: INF, Terrain.OTHER: INF} } )
```
During this recalculation, all points except roads are completely inaccessible, because their connections have infinite cost. The calculated paths will only follow roads.


## C# Support

A wrapper located in `addons/dijkstra-map/dijkstra_map_library/DijkstraMap.cs` can be used to interface with the library. [Example use](#examples) can be seen in `addons/dijkstra-map/visualization_demo/visualization.tscn`. The benefits of this wrapper: 

* First-class development experience (same as GDScript).

    In GDScript you can do:
    ```GDScript
    var bmp: Rect2 = Rect2(0, 0, 23, 19)
    var dijkstramap = DijkstraMap.new()
    dijkstramap.add_square_grid(bmp)
    ```
    And then the same in C# with the DijkstraMap wrapper:
    ```C#
    var bmp = new Rect2(0, 0, 23, 19);
    var dijkstramap = new DijkstraMap();
    dijkstramap.AddSquareGrid(bmp);
    ```

* Strongly typed inputs and outputs.

* CSharpScript setup is already done. 

Make sure your C# code can find the `DijkstraMap.cs` file and its class.


## Notes

Careful! If you pass arguments of the wrong signature to the Rust API, the game will not crash; if you're lucky and have a terminal open, it might print an error there, but not inside Godot! This issue can be avoided by using a GDScript wrapper but it can lead to non trivial bugs, consider yourself warned.
We're working on friendlier errors at runtime.


## Running the Tests

You can use the GUT panel in the editor to select and run tests. If this panel doesn't show up as an option, ensure that the GUT addon files are present in the /addons directory and that the GUT plugin is enabled in the project settings. GUT is configured to run any tests in the `/tests` directory, and expects test files to have the `test_` filename prefix.

You can also run `cargo test` and you're free to look at the Rust tests or contribute to them.


## Contributing

Open an Issue before working on a feature, bugfix, or unit test, so we can then discuss it. Then you can work on it (or let someone else) before initiating a pull request.

Before opening a pull request, please check the following:
* If you modified the Rust code, be sure you have built it with `cargo build --release` and it still works!
* The unit tests should pass (`cargo test` and the GUT tests)
* All the example scenes (visualization demo and project examples) should run correctly
* Ensure you have run `cargo fmt` and `gdformat` (via [GDScript Toolkit](https://github.com/Scony/godot-gdscript-toolkit)) on your added/edited files

To set up gdformat/GDScript Toolkit, it is recommended to use a Python virtual environment (venv)
* `python3 -m venv .venv` or `python -m venv .venv` will create a .venv/ folder you can [activate](https://docs.python.org/3/tutorial/venv.html)
* After activating the venv, verify that you are using Python 3: `python --version`
* Install GDToolkit: `pip install gdtoolkit==4.*`
* Run the linter on your GDScript file with `gdlint path/to/file.gd` to show you what needs to be formatted
* Format your file with `gdformat path/to/file.gd` (careful, data loss is possible), double check linter afterward in case some code couldn't be auto-formatted


## TODO

* if performance on dijkstra is a real heavy consideration, consider implementing threading 


## Use in Projects

- [tacticalRPG](https://github.com/astrale-sharp/tacticalRPG): An in-development framework for creating a tactical rpg using Rust and Godot. 


## Acknowledgments
* KohuGaly
* Astrale
* Eäradrier
