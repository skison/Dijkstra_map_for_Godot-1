//! Implementation of [Dijkstra's algorithm](https://en.wikipedia.org/wiki/Dijkstra's_algorithm) in Rust.
//!
//! `DijkstraMap` is a general-purpose pathfinding class. It is intended
//! to cover functionality that is currently absent from build-in
//! [AStar] pathfinding class. Its main purpose is to do bulk
//! pathfinding by calculating shortest paths between given point and
//! all points in the graph. It also allows viewing useful information
//! about the paths, such as their length, listing all paths with
//! certain length, etc.
//!
//! Just like [AStar], `DijkstraMap` operates on directed weighted
//! graph. To match the naming convention with [AStar], vertices are
//! called points and edges are called connections. Points are always
//! referred to by their unique [integer](int) ID. Unlike [AStar],
//! `DijkstraMap` does not store information about their real positions.
//! Users have to store that information themselves, if they want it;
//! for example, in a [Dictionary].

use dijkstra_map::{Cost, PointId, Read, TerrainType, Weight};
use fnv::FnvHashMap;
use fnv::FnvHashSet;
use godot::prelude::*;

struct MyExtension;

#[gdextension]
unsafe impl ExtensionLibrary for MyExtension {}

/// Integer representing success in gdscript
const OK: i64 = 0;
/// Integer representing failure in gdscript
const FAILED: i64 = 1;

/// Interface exported to Godot
///
/// # Usage
/// 1. Fill the map using [add_point](#func-add_point),
/// [connect_points](#func-connect_points),
/// [add_square_grid](#func-add_square_grid)...
/// 2. Call [recalculate](#func-recalculate) on it.
///   
///     `DijkstraMap` does not calculate the paths automatically. It has
/// to be triggered to execute Dijkstra's algorithm and calculate all
/// the paths. [recalculate](#func-recalculate) support a variety of
/// inputs and optional arguments that affect the end result.
///
///     Unlike [AStar], which calculates a single shortest path between
/// two given points, `DijkstraMap` supports multiple origin points,
/// multiple destination points, with initial priorities, both
/// directions, custom terrain weights and ability to terminate
/// the algorithm early based on distance or specified termination
/// points.
///
///     Performance is expected to be slightly worse than [AStar],
/// because of the extra functionality.
/// 3. Access shortest path using `get_***` methods:
/// [get_direction_at_point](#func-get_direction_at_point),
/// [get_cost_at_point](#func-get_cost_at_point), ...
///
/// # Notes
/// - The [add_square_grid](#func-add_square_grid) and
/// [add_hexagonal_grid](#func-add_hexagonal_grid) methods are
/// convenience methods for bulk-adding standard grids.
/// - The `get_***` methods documentation was written with the
/// assumption that `"input_is_destination"` argument was set to `true`
/// (the default behavior) in [recalculate](#func-recalculate).
///
///   In this case, paths point towards the origin and inspected points
/// are assumed to be destinations.
///
///   If the `"input_is_destination"` argument was set to `false`, paths
/// point towards the destination and inspected points are assumed to be
/// origins.
#[derive(GodotClass, Clone)]

pub struct DijkstraMap {
    dijkstra: dijkstra_map::DijkstraMap,
}

/// Change a Rust's [`Result`] to an integer (which is how errors are reported
/// to Godot).
///
/// [`Ok`] becomes `0`, and [`Err`] becomes `1`.
fn result_to_int<O, E>(res: Result<O, E>) -> i64 {
    match res {
        Ok(_) => OK,
        Err(_) => FAILED,
    }
}

/// Try to convert the given [`Variant`] into a rectangle of `usize`.
///
/// Only works if `bounds` is a [`Rect2D`].
///
/// # Return
///
/// `(x_offset, y_offset, width, height)`
fn variant_to_width_and_height(bounds: Variant) -> Option<(usize, usize, usize, usize)> {
    bounds
        .try_to()
        .map(|rect: Rect2| {
            {
                (
                    rect.position.x as usize,
                    rect.position.y as usize,
                    rect.size.x as usize,
                    rect.size.y as usize,
                )
            }
        })
        .ok()
}

#[godot_api]
impl IRefCounted for DijkstraMap {
    /// Create a new empty `DijkstraMap`.
    ///
    /// # Example
    /// ```gdscript
    /// var dijkstra_map = DijkstraMap.new()
    /// ```

    /// Clears the `DijkstraMap` of all points and connections.
    ///
    /// # Example
    /// ```gdscript
    /// var dijkstra_map = DijkstraMap.new()
    /// dijkstra_map.clear()
    /// ```
    fn init(sprite: Base<RefCounted>) -> Self {
        Self {
            dijkstra: dijkstra_map::DijkstraMap::new(),
        }
    }
}

#[godot_api]
impl DijkstraMap {
    #[func]
    pub fn clear(&mut self) {
        self.dijkstra.clear()
    }

    /// If `source_instance` is a `DijkstraMap`, it is cloned into
    /// `self`.
    ///
    /// # Errors
    ///
    /// This function returns [FAILED] if `source_instance` is not a
    /// `DijkstraMap`, else [OK].
    ///
    /// # Example
    /// ```gdscript
    /// var dijkstra_map = DijkstraMap.new()
    /// # fill dijkstra_map
    /// dijkstra_map.add_point(1)
    /// dijkstra_map.add_point(2)
    /// dijkstra_map.add_point(3)
    /// dijkstra_map.connect_points(1, 2, 1.0)
    /// var dijkstra_map_copy = DijkstraMap.new()
    /// dijkstra_map_copy.duplicate_graph_from(dijkstra_map)
    /// dijkstra_map.add_point(4)
    /// assert_true(dijkstra_map_copy.has_point(1))
    /// assert_true(dijkstra_map_copy.has_point(2))
    /// assert_true(dijkstra_map_copy.has_point(3))
    /// assert_true(dijkstra_map_copy.has_connection(1, 2))
    /// assert_false(dijkstra_map_copy.has_point(4))
    /// ```
    #[func]
    pub fn duplicate_graph_from(&mut self, source_instance: Variant) -> i64 {
        let Ok(source_instance) = source_instance.try_to::<Gd<Self>>() else {
            return FAILED;
        };
        *self = (*source_instance.bind()).clone();
        OK
    }
    /// Returns the first positive available id.
    ///
    /// # Example
    /// ```gdscript
    /// var dijkstra_map = DijkstraMap.new()
    /// dijkstra_map.add_point(0)
    /// dijkstra_map.add_point(1)
    /// assert_eq(dijkstra_map.get_available_point_id(), 2)
    /// ```
    #[func]
    pub fn get_available_point_id(&mut self) -> i32 {
        self.dijkstra.get_available_id(None).into()
    }

    /// Add a new point with the given `terrain_type`.
    ///
    /// If `terrain_type` is not specified, `-1` is used.
    ///
    /// # Errors
    ///
    /// If a point with the given id already exists, the map is unchanged and
    /// [FAILED] is returned, else it returns [OK].
    ///
    /// # Example
    /// ```gdscript
    /// var res: int
    /// var dijkstra_map = DijkstraMap.new()
    /// res = dijkstra_map.add_point(0) # default terrain_type is -1
    /// assert_eq(res, OK)
    /// res = dijkstra_map.add_point(1, 0) # terrain_type is 0
    /// assert_eq(res, OK, "you may add a point once")
    /// res = dijkstra_map.add_point(1, 0)
    /// assert_eq(res, FAILED, "but not twice")
    /// res = dijkstra_map.add_point(1, 1)
    /// assert_eq(res, FAILED, "you cannot even change the terrain this way")
    /// ```
    // TODO opt args?
    #[func]
    pub fn add_point(
        &mut self,
        point_id: i32,
        //TODO opt
        terrain_type: i32,
    ) -> i64 {
        // let terrain_type: TerrainType = terrain_type.unwrap_or(-1).into();
        let res = self
            .dijkstra
            .add_point(point_id, dijkstra_map::TerrainType::Terrain(terrain_type));
        result_to_int(res)
    }

    /// Set the terrain type for `point_id`.
    ///
    /// If `terrain_id` is not specified, `-1` is used.
    ///
    /// # Errors
    /// If the given id does not exists in the map, [FAILED] is returned, else
    /// [OK].
    ///
    /// # Example
    /// ```gdscript
    /// var res: int
    /// var dijkstra_map = DijkstraMap.new()
    /// dijkstra_map.add_point(0, 2)
    /// res = dijkstra_map.set_terrain_for_point(0, 1)
    /// assert_eq(res, OK, "you can set the point's terrain")
    /// assert_eq(dijkstra_map.get_terrain_for_point(0), 1, "the terrain corresponds")
    /// res = dijkstra_map.set_terrain_for_point(0)
    /// assert_eq(res, OK, "multiple times if you want")
    /// assert_eq(dijkstra_map.get_terrain_for_point(0), -1, "default terrain is -1")
    /// ```
    #[func]
    pub fn set_terrain_for_point(
        &mut self,
        point_id: i32,
        // TODO opt
        terrain_id: i32, // terrain_id: Option<i32>
    ) -> i64 {
        // let terrain_id = terrain_id.unwrap_or(-1);
        let terrain: TerrainType = terrain_id.into();
        let res = self.dijkstra.set_terrain_for_point(point_id, terrain);
        result_to_int(res)
    }

    /// Get the terrain type for the given point.
    ///
    /// This function returns `-1` if no point with the given id exists in the
    /// map.
    ///
    /// # Example
    /// ```gdscript
    /// var dijkstra_map = DijkstraMap.new()
    /// dijkstra_map.add_point(0, 1)
    /// dijkstra_map.add_point(1, -1)
    /// assert_eq(dijkstra_map.get_terrain_for_point(0), 1)
    /// assert_eq(dijkstra_map.get_terrain_for_point(1), -1)
    /// # `2` is not in the map, so this returns `-1`
    /// assert_eq(dijkstra_map.get_terrain_for_point(2), -1)
    /// ```
    // #[func]
    pub fn get_terrain_for_point(&mut self, point_id: i32) -> i32 {
        // TODO : TerrainType::DefaultTerrain also convert into -1, so this function cannot separate points that exists and have a default terrain, and those that do not exist.
        // We need a different convention here.
        self.dijkstra
            .get_terrain_for_point(point_id.into())
            .unwrap_or(TerrainType::Terrain(-1))
            .into()
    }

    /// Removes a point from the map.
    ///
    /// # Errors
    ///
    /// Returns [FAILED] if the point does not exists in the map, else
    /// [OK].
    ///
    /// # Example
    /// ```gdscript
    /// var dijkstra_map = DijkstraMap.new()
    /// dijkstra_map.add_point(0)
    /// assert_eq(dijkstra_map.remove_point(0), OK)
    /// assert_eq(dijkstra_map.remove_point(0), FAILED)
    /// ```
    #[func]
    pub fn remove_point(&mut self, point_id: i32) -> i64 {
        let res = self.dijkstra.remove_point(point_id);
        result_to_int(res)
    }

    /// Returns [true] if the map contains the given point.
    ///
    /// # Example
    /// ```gdscript
    /// var dijkstra_map = DijkstraMap.new()
    /// dijkstra_map.add_point(0)
    /// dijkstra_map.add_point(1)
    /// assert_true(dijkstra_map.has_point(0))
    /// assert_true(dijkstra_map.has_point(1))
    /// assert_false(dijkstra_map.has_point(2))
    /// ```
    #[func]
    pub fn has_point(&mut self, point_id: i32) -> bool {
        self.dijkstra.has_point(point_id.into())
    }

    /// Disable the given point for pathfinding.
    ///
    /// # Errors
    ///
    /// Returns [FAILED] if the point does not exists in the map, else [OK].
    ///
    /// # Example
    /// ```gdscript
    /// var dijkstra_map = DijkstraMap.new()
    /// dijkstra_map.add_point(0)
    /// assert_eq(dijkstra_map.disable_point(0), OK)
    /// assert_eq(dijkstra_map.disable_point(1), FAILED)
    /// ```
    #[func]
    pub fn disable_point(&mut self, point_id: i32) -> i64 {
        let res = self.dijkstra.disable_point(point_id);
        result_to_int(res)
    }

    /// Enables the given point for pathfinding.
    ///
    /// # Errors
    /// Returns [FAILED] if the point does not exists in the map, else [OK].
    ///
    /// # Note
    /// Points are enabled by default.
    ///
    /// # Example
    /// ```gdscript
    /// var dijkstra_map = DijkstraMap.new()
    /// dijkstra_map.add_point(0)
    /// assert_eq(dijkstra_map.enable_point(0), OK)
    /// assert_eq(dijkstra_map.enable_point(1), FAILED)
    /// ```
    #[func]
    pub fn enable_point(&mut self, point_id: i32) -> i64 {
        let res = self.dijkstra.enable_point(point_id);
        result_to_int(res)
    }

    /// Returns [true] if the point exists and is disabled, otherwise
    /// returns [false].
    ///
    /// # Example
    /// ```gdscript
    /// var dijkstra_map = DijkstraMap.new()
    /// dijkstra_map.add_point(0)
    /// dijkstra_map.add_point(1)
    /// dijkstra_map.disable_point(0)
    /// assert_true(dijkstra_map.is_point_disabled(0))
    /// assert_false(dijkstra_map.is_point_disabled(1)) # not disabled
    /// assert_false(dijkstra_map.is_point_disabled(2)) # not in the map
    /// ```
    #[func]
    pub fn is_point_disabled(&mut self, point_id: i32) -> bool {
        self.dijkstra.is_point_disabled(point_id)
    }

    /// Connects the two given points.
    ///
    /// # Parameters
    ///
    /// - `source`: source point of the connection.
    /// - `target`: target point of the connection.
    /// - `weight` (default : `1.0`): weight of the connection.
    /// - `bidirectional` (default : [true]): whether or not the
    /// reciprocal connection should be made.
    ///
    /// # Errors
    /// Return [FAILED] if one of the points does not exists in the map.
    ///
    /// # Example
    /// ```gdscript
    /// var dijkstra_map = DijkstraMap.new()
    /// dijkstra_map.add_point(0)
    /// dijkstra_map.add_point(1)
    /// dijkstra_map.add_point(2)
    /// dijkstra_map.add_point(3)
    /// # bidirectional is enabled by default
    /// assert_eq(dijkstra_map.connect_points(0, 1, 2.0), OK)
    /// # default weight is 1.0
    /// assert_eq(dijkstra_map.connect_points(1, 2), OK)
    /// assert_eq(dijkstra_map.connect_points(1, 3, 1.0, false), OK)
    /// # produces the graph :
    /// # 0 <---> 1 <---> 2 ----> 3
    /// #    2.0     1.0     1.0
    /// assert_eq(dijkstra_map.connect_points(1, 4), FAILED, "4 does not exists in the map")
    /// assert_eq(dijkstra_map.connect_points(1, 5, 1.0), FAILED, "5 does not exists in the map")
    /// assert_eq(dijkstra_map.connect_points(1, 6, 1.0, true), FAILED, "6 does not exists in the map")
    /// ```
    #[func]
    pub fn connect_points(
        &mut self,
        source: i32,
        target: i32,
        // todo opt
        weight: f32,
        bidirectional: bool,
        // #[opt] weight: Option<f32>,
        // #[opt] bidirectional: Option<bool>,
    ) -> i64 {
        result_to_int(self.dijkstra.connect_points(
            source,
            target,
            Some(Weight(weight)),
            Some(bidirectional),
        ))
    }

    /// Remove a connection between the two given points.
    ///
    /// # Parameters
    ///
    /// - `source`: source point of the connection.
    /// - `target`: target point of the connection.
    /// - `bidirectional` (default : [true]): if [true], also removes
    /// connection from target to source.
    ///
    /// # Errors
    ///
    /// Returns [FAILED] if one of the points does not exist. Else, returns [OK].
    ///
    /// # Example
    /// ```gdscript
    /// var dijkstra_map = DijkstraMap.new()
    /// dijkstra_map.add_point(0)
    /// dijkstra_map.add_point(1)
    /// dijkstra_map.connect_points(0, 1)
    /// assert_eq(dijkstra_map.remove_connection(0, 1), OK)
    /// assert_eq(dijkstra_map.remove_connection(0, 2), FAILED) # 2 does not exists in the map
    /// dijkstra_map.connect_points(0, 1)
    /// # only removes connection from 0 to 1
    /// assert_eq(dijkstra_map.remove_connection(0, 1, false), OK)
    /// assert_true(dijkstra_map.has_connection(1, 0))
    /// ```
    #[func]
    pub fn remove_connection(
        &mut self,
        source: i32,
        target: i32,
        bidirectional: bool,
        // TODO opt
        // #[opt] bidirectional: Option<bool>,
    ) -> i64 {
        result_to_int(
            self.dijkstra
                .remove_connection(source, target, Some(bidirectional)),
        )
    }

    /// Returns [true] if there is a connection from `source` to
    /// `target` (and they both exist).
    ///
    /// # Example
    /// ```gdscript
    /// var dijkstra_map = DijkstraMap.new()
    /// dijkstra_map.add_point(0)
    /// dijkstra_map.add_point(1)
    /// dijkstra_map.connect_points(0, 1, 1.0, false)
    /// assert_true(dijkstra_map.has_connection(0, 1))
    /// assert_false(dijkstra_map.has_connection(1, 0))
    /// assert_false(dijkstra_map.has_connection(0, 2))
    /// ```
    #[func]
    pub fn has_connection(&mut self, source: i32, target: i32) -> bool {
        self.dijkstra.has_connection(source, target)
    }

    /// Given a point, returns the id of the next point along the
    /// shortest path toward the target.
    ///
    /// # Errors
    ///
    /// This function return `-1` if there is no path from the point to
    /// the target.
    ///
    /// # Example
    /// ```gdscript
    /// var dijkstra_map = DijkstraMap.new()
    /// dijkstra_map.add_point(0)
    /// dijkstra_map.add_point(1)
    /// dijkstra_map.add_point(2)
    /// dijkstra_map.connect_points(0, 1)
    /// dijkstra_map.recalculate(0)
    /// assert_eq(dijkstra_map.get_direction_at_point(0), 0)
    /// assert_eq(dijkstra_map.get_direction_at_point(1), 0)
    /// assert_eq(dijkstra_map.get_direction_at_point(2), -1)
    /// ```
    #[func]
    pub fn get_direction_at_point(&mut self, point_id: i32) -> i32 {
        self.dijkstra
            .get_direction_at_point(point_id)
            .unwrap_or(PointId(-1))
            .into()
    }

    /// Returns the cost of the shortest path from this point to the
    /// target.
    ///
    /// If there is no path, the cost is [INF].
    ///
    /// # Example
    /// ```gdscript
    /// var dijkstra_map = DijkstraMap.new()
    /// dijkstra_map.add_point(0)
    /// dijkstra_map.add_point(1)
    /// dijkstra_map.add_point(2)
    /// dijkstra_map.connect_points(0, 1)
    /// dijkstra_map.recalculate(0)
    /// assert_eq(dijkstra_map.get_cost_at_point(0), 0.0)
    /// assert_eq(dijkstra_map.get_cost_at_point(1), 1.0)
    /// assert_eq(dijkstra_map.get_cost_at_point(2), INF)
    /// ```
    #[func]
    pub fn get_cost_at_point(&mut self, point_id: i32) -> f32 {
        self.dijkstra.get_cost_at_point(point_id).into()
    }

    /// Recalculates cost map and direction map information for each
    /// point, overriding previous results.
    ///
    /// This is the central function of the library, the one that
    /// actually uses Dijkstra's algorithm.
    ///
    /// # Parameters
    ///
    /// - `origin` : ID of the origin point, or array of IDs (preferably
    /// [Int32Array]).
    /// - `optional_params:` [Dictionary] : Specifies optional arguments. \
    /// Valid arguments are :
    ///   - `"input_is_destination":` [bool] (default : [true]) : \
    ///     Wether or not the `origin` points are seen as destination.
    ///   - `"maximum_cost":` [float] (default : [INF]) : \
    ///     Specifies maximum cost. Once all the shortest paths no
    /// longer than the maximum cost are found, the algorithm
    /// terminates. All points with cost bigger than this are treated as
    /// inaccessible.
    ///   - `"initial_costs":` [float] [Array] (default : empty) : \
    ///     Specifies initial costs for the given `origin`s. Values are
    /// paired with corresponding indices in the origin argument. Every
    /// unspecified cost is defaulted to `0.0`. \
    ///     Can be used to weigh the `origin`s with a preference.
    ///   - `"terrain_weights":` [Dictionary] (default : empty) : \
    ///     Specifies weights of terrain types. Keys are terrain type
    /// IDs and values are floats. Unspecified terrains will have
    /// [infinite](INF) weight. \
    ///     Note that `-1` correspond to the default terrain (which have
    /// a weight of `1.0`), and will thus be ignored if it appears in
    /// the keys.
    ///   - `"termination_points":` [int] OR [int] [Array] (default : empty) : \
    ///     A set of points that stop the computation if they are
    /// reached by the algorithm. \
    ///     Note that keys of incorrect types are ignored with a warning.
    ///
    /// # Errors
    ///
    /// [FAILED] is returned if :
    /// - One of the keys in `optional_params` is invalid.
    /// - `origin` is neither an [int], a [PoolIntArray] or a [Array].
    ///
    /// # Example
    /// ```gdscript
    /// var dijkstra_map = DijkstraMap.new()
    /// dijkstra_map.add_point(0, 0)
    /// dijkstra_map.add_point(1, 1)
    /// dijkstra_map.add_point(2, 0)
    /// dijkstra_map.connect_points(0, 1)
    /// dijkstra_map.connect_points(1, 2, 10.0)
    /// var optional_params = {
    ///     "terrain_weights": { 0: 1.0, 1: 2.0 },
    ///     "input_is_destination": true,
    ///     "maximum_cost": 2.0,
    /// }
    /// dijkstra_map.recalculate(0, optional_params)
    /// assert_eq(dijkstra_map.get_direction_at_point(0), 0)
    /// assert_eq(dijkstra_map.get_direction_at_point(1), 0)
    /// # 2 is too far from 0, so because we set "maximum_cost" to 2.0, it is inaccessible.
    /// assert_eq(dijkstra_map.get_direction_at_point(2), -1)
    /// ```
    #[func]
    pub fn recalculate(
        &mut self,
        origin: Variant,
        optional_params: Dictionary,
        //TODO opt
        // #[opt] optional_params: Option<Dictionary>,
    ) -> i64 {
        const TERRAIN_WEIGHT: &str = "terrain_weights";
        const TERMINATION_POINTS: &str = "termination_points";
        const INPUT_IS_DESTINATION: &str = "input_is_destination";
        const MAXIMUM_COST: &str = "maximum_cost";
        const INITIAL_COSTS: &str = "initial_costs";
        const VALID_KEYS: [&str; 5] = [
            TERRAIN_WEIGHT,
            TERMINATION_POINTS,
            INPUT_IS_DESTINATION,
            MAXIMUM_COST,
            INITIAL_COSTS,
        ];

        fn display_type(t: VariantType) -> &'static str {
            match t {
                VariantType::Nil => "nil",
                VariantType::Bool => "bool",
                VariantType::Int => "integer",
                VariantType::Float => "float",
                VariantType::String => "string",
                VariantType::Vector2 => "Vector2",
                VariantType::Rect2 => "Rect2",
                VariantType::Vector3 => "Vector3",
                VariantType::Transform2D => "Transform2D",
                VariantType::Plane => "Plane",
                VariantType::Quaternion => "Quat",
                VariantType::Aabb => "Aabb",
                VariantType::Basis => "Basis",
                VariantType::Transform3D => "Transform3D",
                VariantType::Color => "Color",
                VariantType::NodePath => "NodePath",
                VariantType::Rid => "Rid",
                VariantType::Object => "Object",
                VariantType::Dictionary => "Dictionary",
                VariantType::Array => "array",
                VariantType::PackedByteArray => "array of bytes",
                VariantType::PackedInt32Array => "array of integers",
                VariantType::PackedInt64Array => "array of integers",
                VariantType::PackedFloat32Array => "array of floats",
                VariantType::PackedFloat64Array => "array of floats",
                VariantType::PackedStringArray => "array of strings",
                VariantType::PackedVector2Array => "array of Vector2",
                VariantType::PackedVector3Array => "array of Vector3",
                VariantType::PackedColorArray => "array of Color",
                VariantType::Vector2i => "Vector2i",
                VariantType::Rect2i => "Rect2i",
                VariantType::Vector3i => "Vector3i",
                VariantType::Vector4 => "Vector4",
                VariantType::Vector4i => "Vector4i",
                VariantType::Projection => "Projection",
                VariantType::StringName => "StringName",
                VariantType::Callable => "Callable",
                VariantType::Signal => "Signal",
                VariantType => "VariantType",
            }
        }

        /// Helper function for type warnings
        ///
        /// Ensure the style of warning reporting is consistent.
        fn type_warning(object: &str, expected: VariantType, got: VariantType, line: u32) {
            godot_warn!(
                "[{}:{}] {} has incorrect type : expected {}, got {}",
                file!(),
                line,
                object,
                display_type(expected),
                display_type(got)
            );
        }

        // let optional_params = optional_params.unwrap_or_default();

        // verify keys makes sense
        for k in optional_params.keys_shared().into_iter() {
            let string: String = k.to_string();
            if !VALID_KEYS.contains(&string.as_str()) {
                godot_error!("Invalid Key `{}` in parameter", string);
                return FAILED;
            }
        }

        // get origin points
        let mut res_origins = Vec::<PointId>::new();
        match origin.get_type() {
            godot::builtin::VariantType::Int => {
                res_origins.push((origin.to::<i64>() as i32).into())
            }
            godot::builtin::VariantType::PackedInt32Array => {
                res_origins = origin
                    .to::<godot::builtin::PackedInt32Array>()
                    .as_slice()
                    .iter()
                    .map(|&x| x.into())
                    .collect();
            }
            godot::builtin::VariantType::Array => {
                for i in origin.to::<godot::builtin::VariantArray>().iter_shared() {
                    match i.try_to::<i64>() {
                        Ok(intval) => res_origins.push(PointId(intval as i32)),
                        Err(_) => type_warning(
                            "element of 'origin'",
                            VariantType::Int,
                            i.get_type(),
                            line!(),
                        ),
                    }
                }
            }
            _ => {
                godot_error!("Invalid argument type : Expected int or Array of ints");
                return FAILED;
            }
        };

        // ===================
        // Optional parameters
        // ===================
        let read: Option<Read> = {
            // we need to check that the parameter exists first, because
            // `optional_params.get` will create a `Nil` entry if it does not.
            if optional_params.contains_key(INPUT_IS_DESTINATION) {
                let value = optional_params.get(INPUT_IS_DESTINATION).unwrap();
                match value.try_to::<bool>() {
                    Ok(b) => Some(if b {
                        Read::InputIsDestination
                    } else {
                        Read::InputIsOrigin
                    }),
                    Err(_) => {
                        type_warning(
                            "'input_is_destination' key",
                            VariantType::Bool,
                            value.get_type(),
                            line!(),
                        );
                        None
                    }
                }
            } else {
                None
            }
        };

        let max_cost: Option<Cost> = {
            if optional_params.contains_key(MAXIMUM_COST) {
                let value = optional_params.get(MAXIMUM_COST).unwrap();
                match value.try_to::<f64>() {
                    Ok(f) => Some(Cost(f as f32)),
                    Err(_) => {
                        type_warning(
                            "'max_cost' key",
                            VariantType::Float,
                            value.get_type(),
                            line!(),
                        );
                        None
                    }
                }
            } else {
                None
            }
        };

        let initial_costs: Vec<Cost> = {
            if optional_params.contains_key(INITIAL_COSTS) {
                let mut initial_costs = Vec::<Cost>::new();
                let value = optional_params.get(INITIAL_COSTS).unwrap();
                match value.get_type() {
                    godot::builtin::VariantType::PackedFloat32Array => {
                        for f in value
                            .to::<godot::builtin::PackedFloat32Array>()
                            .as_slice()
                            .iter()
                        {
                            initial_costs.push(Cost(*f))
                        }
                    }
                    godot::builtin::VariantType::Array => {
                        for f in value.to::<godot::builtin::VariantArray>().iter_shared() {
                            initial_costs.push(match f.try_to::<f64>() {
                                Ok(fval) => Cost(fval as f32),
                                Err(_) => {
                                    type_warning(
                                        "element of 'initial_costs'",
                                        VariantType::Float,
                                        f.get_type(),
                                        line!(),
                                    );
                                    Cost(0.0)
                                }
                            })
                        }
                    }
                    incorrect_type => type_warning(
                        "'initial_costs' key",
                        VariantType::PackedFloat32Array,
                        incorrect_type,
                        line!(),
                    ),
                }
                initial_costs
            } else {
                Vec::new()
            }
        };

        let mut terrain_weights = FnvHashMap::<TerrainType, Weight>::default();
        if optional_params.contains_key(TERRAIN_WEIGHT) {
            let value = optional_params.get(TERRAIN_WEIGHT).unwrap();
            if let Ok(dict) = value.try_to::<godot::builtin::Dictionary>() {
                for key in dict.keys_shared() {
                    if let Ok(id) = key.try_to::<i64>() {
                        terrain_weights.insert(
                            TerrainType::from(id as i32),
                            Weight(dict.get(key).unwrap().try_to::<f64>().unwrap_or(1.0) as f32),
                        );
                    } else {
                        type_warning(
                            "key in 'terrain_weights'",
                            VariantType::Int,
                            key.get_type(),
                            line!(),
                        );
                    }
                }
            } else {
                type_warning(
                    "'terrain_weights' key",
                    VariantType::PackedInt32Array,
                    value.get_type(),
                    line!(),
                );
            }
        }

        if terrain_weights.is_empty() {
            godot_warn!("no terrain weights specified : all terrains will have infinite cost !")
        }

        let termination_points = if optional_params.contains_key(TERMINATION_POINTS) {
            let value = optional_params.get(TERMINATION_POINTS).unwrap();
            match value.get_type() {
                godot::builtin::VariantType::Int => {
                    std::iter::once(PointId(value.to::<i64>() as i32)).collect()
                }
                godot::builtin::VariantType::PackedInt32Array => value
                    .to::<godot::builtin::PackedInt32Array>()
                    .as_slice()
                    .iter()
                    .map(|&x| PointId::from(x))
                    .collect(),
                godot::builtin::VariantType::Array => value
                    .to::<godot::builtin::VariantArray>()
                    .iter_shared()
                    .filter_map(|i| {
                        let int = i.try_to::<i64>();
                        if int.is_err() {
                            type_warning(
                                "value in 'termination_points'",
                                VariantType::Int,
                                i.get_type(),
                                line!(),
                            );
                        }
                        int.ok()
                    })
                    .map(|ival| PointId(ival as i32))
                    .collect(),
                incorrect_type => {
                    type_warning(
                        "'termination_points' key",
                        VariantType::PackedInt32Array,
                        incorrect_type,
                        line!(),
                    );
                    FnvHashSet::<PointId>::default()
                }
            }
        } else {
            FnvHashSet::default()
        };

        self.dijkstra.recalculate(
            &res_origins,
            read,
            max_cost,
            initial_costs,
            terrain_weights,
            termination_points,
        );
        OK
    }

    /// For each point in the given array, returns the id of the next
    /// point along the shortest path toward the target.
    ///
    /// If a point does not exists, or there is no path from it to the
    /// target, the corresponding point will be `-1`.
    ///
    /// # Example
    /// ```gdscript
    /// var dijkstra_map = DijkstraMap.new()
    /// dijkstra_map.add_point(0)
    /// dijkstra_map.add_point(1)
    /// dijkstra_map.add_point(2)
    /// dijkstra_map.connect_points(0, 1)
    /// dijkstra_map.recalculate(0)
    /// assert_eq(Array(dijkstra_map.get_direction_at_points(PoolIntArray([0, 1, 2]))), [0, 0, -1])
    /// ```
    #[func]
    pub fn get_direction_at_points(&mut self, points: PackedInt32Array) -> PackedInt32Array {
        points
            .as_slice()
            .iter()
            .map(|int: &i32| {
                self.dijkstra
                    .get_direction_at_point(PointId::from(*int))
                    .unwrap_or(PointId(-1))
                    .into()
            })
            .collect()
    }
    /// For each point in the given array, returns the cost of the
    /// shortest path from this point to the target.
    ///
    /// If there is no path from a point to the target, the cost is
    /// [INF].
    ///
    /// # Example
    /// ```gdscript
    /// var dijkstra_map = DijkstraMap.new()
    /// dijkstra_map.add_point(0)
    /// dijkstra_map.add_point(1)
    /// dijkstra_map.add_point(2)
    /// dijkstra_map.connect_points(0, 1)
    /// dijkstra_map.recalculate(0)
    /// assert_eq(Array(dijkstra_map.get_cost_at_points(PoolIntArray([0, 1, 2]))), [0.0, 1.0, INF])
    /// ```
    #[func]
    pub fn get_cost_at_points(
        &mut self,
        points: godot::builtin::PackedInt32Array,
    ) -> godot::builtin::PackedFloat32Array {
        points
            .as_slice()
            .iter()
            .map(|point: &i32| {
                self.dijkstra
                    .get_cost_at_point(PointId::from(*point))
                    .into()
            })
            .collect()
    }

    /// Returns the entire Dijkstra map of costs in form of a
    /// `Dictionary`.
    ///
    /// Keys are points' IDs, and values are costs. Inaccessible points
    /// are not present in the dictionary.
    ///
    /// # Example
    /// ```gdscript
    /// var dijkstra_map = DijkstraMap.new()
    /// dijkstra_map.add_point(0)
    /// dijkstra_map.add_point(1)
    /// dijkstra_map.add_point(2)
    /// dijkstra_map.connect_points(0, 1)
    /// dijkstra_map.recalculate(0)
    /// var cost_map = { 0: 0.0, 1: 1.0 }
    /// var computed_cost_map = dijkstra_map.get_cost_map()
    /// for id in computed_cost_map.keys():
    ///     assert_eq(computed_cost_map[id], cost_map[id])
    /// ```
    #[func]
    pub fn get_cost_map(&mut self) -> Dictionary {
        let mut dict = Dictionary::new();
        for (&point, info) in self.dijkstra.get_direction_and_cost_map().iter() {
            let point: i32 = point.into();
            let cost: f32 = info.cost.into();
            dict.insert(point, cost);
        }
        dict
    }

    /// Returns the entire Dijkstra map of directions in form of a
    /// `Dictionary`.
    ///
    /// Keys are points' IDs, and values are the next point along the
    /// shortest path.
    ///
    /// ## Note
    /// Unreachable points are not present in the map.
    ///
    /// # Example
    /// ```gdscript
    /// var dijkstra_map = DijkstraMap.new()
    /// dijkstra_map.add_point(0)
    /// dijkstra_map.add_point(1)
    /// dijkstra_map.add_point(2)
    /// dijkstra_map.connect_points(0, 1)
    /// dijkstra_map.recalculate(0)
    /// var direction_map = { 0: 0, 1: 0 }
    /// var computed_direction_map = dijkstra_map.get_direction_map()
    /// for id in computed_direction_map.keys():
    ///     assert_eq(computed_direction_map[id], direction_map[id])
    /// ```
    #[func]
    pub fn get_direction_map(&mut self) -> Dictionary {
        let mut dict = Dictionary::new();
        for (&point, info) in self.dijkstra.get_direction_and_cost_map().iter() {
            let point: i32 = point.into();
            let direction: i32 = info.direction.into();
            dict.insert(point, direction);
        }
        dict
    }

    /// Returns an array of all the points whose cost is between
    /// `min_cost` and `max_cost`.
    ///
    /// The array will be sorted by cost.
    ///
    /// # Example
    /// ```gdscript
    /// var dijkstra_map = DijkstraMap.new()
    /// dijkstra_map.add_point(0)
    /// dijkstra_map.add_point(1)
    /// dijkstra_map.add_point(2)
    /// dijkstra_map.connect_points(0, 1)
    /// dijkstra_map.recalculate(0)
    /// assert_eq(Array(dijkstra_map.get_all_points_with_cost_between(0.5, 1.5)), [1])
    /// ```
    #[func]
    pub fn get_all_points_with_cost_between(
        &mut self,
        min_cost: f32,
        max_cost: f32,
    ) -> godot::builtin::PackedInt32Array {
        self.dijkstra
            .get_all_points_with_cost_between(min_cost.into(), max_cost.into())
            .iter()
            .map(|id: &PointId| (*id).into())
            .collect()
    }

    /// Returns an [array] of points describing the shortest path from a
    /// starting point.
    ///
    /// If the starting point is a target or is inaccessible, the
    /// [array] will be empty.
    ///
    /// ## Note
    /// The starting point itself is not included.
    ///
    /// [array]: gdnative::core_types::Int32Array
    #[func]
    pub fn get_shortest_path_from_point(
        &mut self,
        point_id: i32,
    ) -> godot::builtin::PackedInt32Array {
        self.dijkstra
            .get_shortest_path_from_point(point_id.into())
            .map(|id: PointId| id.into())
            .collect()
    }

    /// Adds a square grid of connected points.
    ///
    /// # Parameters
    ///
    /// - `bounds` : Dimensions of the grid. At the moment, only
    /// [Rect2] is supported.
    /// - `terrain_type` (default : `-1`) : Terrain to use for all
    /// points of the grid.
    /// - `orthogonal_cost` (default : `1.0`) : specifies cost of
    /// orthogonal connections (up, down, right and left). \
    ///   If `orthogonal_cost` is [INF] or [NAN], orthogonal
    /// connections are disabled.
    /// - `diagonal_cost` (default : [INF]) : specifies cost of
    /// diagonal connections. \
    ///   If `diagonal_cost` is [INF] or [NAN], diagonal connections
    /// are disabled.
    ///
    /// # Returns
    ///
    /// This function returns a [Dictionary] where keys are coordinates
    /// of points ([Vector2]) and values are their corresponding point
    /// IDs.
    #[func]
    pub fn add_square_grid(
        &mut self,
        bounds: Variant,
        terrain_type: i32,
        orthogonal_cost: f32,
        diagonal_cost: f32,
        // #[opt] terrain_type: Option<i32>,
        // #[opt] orthogonal_cost: Option<f32>,
        // #[opt] diagonal_cost: Option<f32>,
    ) -> Dictionary {
        let (x_offset, y_offset, width, height) =
            variant_to_width_and_height(bounds).expect("couldn't use bounds variant");
        let mut dict = Dictionary::new();
        for (&k, &v) in self
            .dijkstra
            .add_square_grid(
                width,
                height,
                Some((x_offset, y_offset).into()),
                Some(terrain_type).unwrap_or(-1).into(),
                Some(orthogonal_cost).map(Weight),
                Some(diagonal_cost).map(Weight),
            )
            .iter()
        {
            dict.insert(
                Vector2::new(k.x as f32, k.y as f32).to_variant(),
                i32::from(v),
            );
        }
        dict
    }

    /// Adds a hexagonal grid of connected points.
    ///
    /// # Parameters
    ///
    /// - `bounds` : Dimensions of the grid.
    /// - `terrain_type` (default : `-1`) : specifies terrain to be used.
    /// - `weight` (default : `1.0`) : specifies cost of connections.
    ///
    /// # Returns
    ///
    /// This function returns a [Dictionary] where keys are
    /// coordinates of points ([Vector2]) and values are their
    /// corresponding point IDs.
    ///
    /// # Note
    ///
    /// Hexgrid is in the "pointy" orientation by default (see example
    /// below).
    ///
    /// To switch to "flat" orientation, swap `width` and `height`, and
    /// switch `x` and `y` coordinates of the keys in the return
    /// `Dictionary`. ([Transform2D] may be convenient there)
    ///
    /// # Example
    ///
    /// This is what `dijkstra_map.add_hexagonal_grid(Rect2(1, 4, 2, 3), ...)` would produce:
    ///
    ///```text
    ///    / \     / \
    ///  /     \ /     \
    /// |  1,4  |  2,4  |
    ///  \     / \     / \
    ///    \ /     \ /     \
    ///     |  1,5  |  2,5  |
    ///    / \     / \     /
    ///  /     \ /     \ /
    /// |  1,6  |  2,6  |
    ///  \     / \     /
    ///    \ /     \ /
    ///```
    #[func]
    pub fn add_hexagonal_grid(
        &mut self,
        bounds: Variant,
        terrain_type: i32,
        weight: f32,
        // #[opt] terrain_type: Option<i32>,
        // #[opt] weight: Option<f32>,
    ) -> Dictionary {
        let (x_offset, y_offset, width, height) =
            variant_to_width_and_height(bounds).expect("couldn't use bounds variant");
        let mut dict = Dictionary::new();
        for (&k, &v) in self
            .dijkstra
            .add_hexagonal_grid(
                width,
                height,
                Some((x_offset, y_offset).into()),
                Some(terrain_type).unwrap_or(-1).into(),
                Some(weight).map(Weight),
            )
            .iter()
        {
            dict.insert(
                Vector2::new(k.x as f32, k.y as f32).to_variant(),
                i32::from(v),
            );
        }
        dict
    }
}
