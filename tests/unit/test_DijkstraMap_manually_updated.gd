extends GutTest

# This file was automatically generated using [gdnative-doc-rs](https://github.com/arnaudgolfouse/gdnative-doc-rs)
# NOTE: this file was manually updated to work with Godot 4 and the WIP Rust API
# TODO: Link up auto-generation of tests and markdown files with newer Rust GDExtension tools
#
# Crate: dijkstra_map_gd
# Source file: lib.rs

const TERRAIN_WEIGHTS_WARNING := (
	"no terrain weights specified : all terrains will have infinite cost !")


func test_new() -> void:
	var dijkstra_map := DijkstraMap.new()
	assert_not_null(dijkstra_map)


func test_clear() -> void:
	var dijkstra_map := DijkstraMap.new()
	dijkstra_map.add_point(0)
	assert_true(dijkstra_map.has_point(0))
	dijkstra_map.clear()
	assert_false(dijkstra_map.has_point(0))


func test_duplicate_graph_from() -> void:
	var dijkstra_map := DijkstraMap.new()
	# fill dijkstra_map
	dijkstra_map.add_point(1)
	dijkstra_map.add_point(2)
	dijkstra_map.add_point(3)
	dijkstra_map.connect_points(1, 2, 1.0)
	var dijkstra_map_copy := DijkstraMap.new()
	dijkstra_map_copy.duplicate_graph_from(dijkstra_map)
	dijkstra_map.add_point(4)
	assert_true(dijkstra_map_copy.has_point(1))
	assert_true(dijkstra_map_copy.has_point(2))
	assert_true(dijkstra_map_copy.has_point(3))
	assert_true(dijkstra_map_copy.has_connection(1, 2))
	assert_false(dijkstra_map_copy.has_point(4))


func test_get_available_point_id() -> void:
	var dijkstra_map := DijkstraMap.new()
	dijkstra_map.add_point(0)
	dijkstra_map.add_point(1)
	assert_eq(dijkstra_map.get_available_point_id(), 2)


func test_add_point() -> void:
	var res: int
	var dijkstra_map := DijkstraMap.new()
	res = dijkstra_map.add_point(0) # default terrain_type is -1
	assert_eq(res, OK)
	res = dijkstra_map.add_point(1, 0) # terrain_type is 0
	assert_eq(res, OK, "you may add a point once")
	res = dijkstra_map.add_point(1, 0)
	assert_eq(res, FAILED, "but not twice")
	res = dijkstra_map.add_point(1, 1)
	assert_eq(res, FAILED, "you cannot even change the terrain this way")


func test_set_terrain_for_point() -> void:
	var res: int
	var dijkstra_map := DijkstraMap.new()
	dijkstra_map.add_point(0, 2)
	res = dijkstra_map.set_terrain_for_point(0, 1)
	assert_eq(res, OK, "you can set the point's terrain")
	assert_eq(dijkstra_map.get_terrain_for_point(0), 1, "the terrain corresponds")
	res = dijkstra_map.set_terrain_for_point(0)
	assert_eq(res, OK, "multiple times if you want")
	assert_eq(dijkstra_map.get_terrain_for_point(0), -1, "default terrain is -1")


func test_get_terrain_for_point() -> void:
	var dijkstra_map := DijkstraMap.new()
	dijkstra_map.add_point(0, 1)
	dijkstra_map.add_point(1, -1)
	assert_eq(dijkstra_map.get_terrain_for_point(0), 1)
	assert_eq(dijkstra_map.get_terrain_for_point(1), -1)
	# `2` is not in the map, so this returns `-1`
	assert_eq(dijkstra_map.get_terrain_for_point(2), -1)


func test_remove_point() -> void:
	var dijkstra_map := DijkstraMap.new()
	dijkstra_map.add_point(0)
	assert_eq(dijkstra_map.remove_point(0), OK)
	assert_eq(dijkstra_map.remove_point(0), FAILED)


func test_has_point() -> void:
	var dijkstra_map := DijkstraMap.new()
	dijkstra_map.add_point(0)
	dijkstra_map.add_point(1)
	assert_true(dijkstra_map.has_point(0))
	assert_true(dijkstra_map.has_point(1))
	assert_false(dijkstra_map.has_point(2))


func test_disable_point() -> void:
	var dijkstra_map := DijkstraMap.new()
	dijkstra_map.add_point(0)
	assert_eq(dijkstra_map.disable_point(0), OK)
	assert_eq(dijkstra_map.disable_point(1), FAILED)


func test_enable_point() -> void:
	var dijkstra_map := DijkstraMap.new()
	dijkstra_map.add_point(0)
	assert_eq(dijkstra_map.enable_point(0), OK)
	assert_eq(dijkstra_map.enable_point(1), FAILED)


func test_is_point_disabled() -> void:
	var dijkstra_map := DijkstraMap.new()
	dijkstra_map.add_point(0)
	dijkstra_map.add_point(1)
	dijkstra_map.disable_point(0)
	assert_true(dijkstra_map.is_point_disabled(0))
	assert_false(dijkstra_map.is_point_disabled(1)) # not disabled
	assert_false(dijkstra_map.is_point_disabled(2)) # not in the map


func test_connect_points() -> void:
	var dijkstra_map := DijkstraMap.new()
	dijkstra_map.add_point(0)
	dijkstra_map.add_point(1)
	dijkstra_map.add_point(2)
	dijkstra_map.add_point(3)
	# bidirectional is enabled by default
	assert_eq(dijkstra_map.connect_points(0, 1, 2.0), OK)
	# default weight is 1.0
	assert_eq(dijkstra_map.connect_points(1, 2), OK)
	assert_eq(dijkstra_map.connect_points(1, 3, 1.0, false), OK)
	# produces the graph :
	# 0 <---> 1 <---> 2 ----> 3
	#    2.0     1.0     1.0
	assert_eq(dijkstra_map.connect_points(1, 4), FAILED, "4 does not exists in the map")
	assert_eq(dijkstra_map.connect_points(1, 5, 1.0), FAILED, "5 does not exists in the map")
	assert_eq(dijkstra_map.connect_points(1, 6, 1.0, true), FAILED, "6 does not exists in the map")


func test_remove_connection() -> void:
	var dijkstra_map := DijkstraMap.new()
	dijkstra_map.add_point(0)
	dijkstra_map.add_point(1)
	dijkstra_map.connect_points(0, 1)
	assert_eq(dijkstra_map.remove_connection(0, 1), OK)
	assert_eq(dijkstra_map.remove_connection(0, 2), FAILED) # 2 does not exists in the map
	dijkstra_map.connect_points(0, 1)
	# only removes connection from 0 to 1
	assert_eq(dijkstra_map.remove_connection(0, 1, false), OK)
	assert_true(dijkstra_map.has_connection(1, 0))


func test_has_connection() -> void:
	var dijkstra_map := DijkstraMap.new()
	dijkstra_map.add_point(0)
	dijkstra_map.add_point(1)
	dijkstra_map.connect_points(0, 1, 1.0, false)
	assert_true(dijkstra_map.has_connection(0, 1))
	assert_false(dijkstra_map.has_connection(1, 0))
	assert_false(dijkstra_map.has_connection(0, 2))


func test_get_direction_at_point() -> void:
	var dijkstra_map := DijkstraMap.new()
	dijkstra_map.add_point(0)
	dijkstra_map.add_point(1)
	dijkstra_map.add_point(2)
	dijkstra_map.connect_points(0, 1)
	dijkstra_map.recalculate(0, {})
	assert_engine_error(TERRAIN_WEIGHTS_WARNING)
	assert_eq(dijkstra_map.get_direction_at_point(0), 0)
	assert_eq(dijkstra_map.get_direction_at_point(1), 0)
	assert_eq(dijkstra_map.get_direction_at_point(2), -1)


func test_get_cost_at_point() -> void:
	var dijkstra_map := DijkstraMap.new()
	dijkstra_map.add_point(0)
	dijkstra_map.add_point(1)
	dijkstra_map.add_point(2)
	dijkstra_map.connect_points(0, 1)
	dijkstra_map.recalculate(0, {})
	assert_engine_error(TERRAIN_WEIGHTS_WARNING)
	assert_eq(dijkstra_map.get_cost_at_point(0), 0.0)
	assert_eq(dijkstra_map.get_cost_at_point(1), 1.0)
	assert_eq(dijkstra_map.get_cost_at_point(2), INF)


func test_recalculate() -> void:
	var dijkstra_map := DijkstraMap.new()
	dijkstra_map.add_point(0, 0)
	dijkstra_map.add_point(1, 1)
	dijkstra_map.add_point(2, 0)
	dijkstra_map.connect_points(0, 1)
	dijkstra_map.connect_points(1, 2, 10.0)
	var params: Dictionary[String, Variant] = {
		"terrain_weights": { 0: 1.0, 1: 2.0 },
		"input_is_destination": true,
		"maximum_cost": 2.0,
	}
	dijkstra_map.recalculate(0, params)
	assert_eq(dijkstra_map.get_direction_at_point(0), 0)
	assert_eq(dijkstra_map.get_direction_at_point(1), 0)
	# 2 is too far from 0, so because we set "maximum_cost" to 2.0, it is inaccessible.
	assert_eq(dijkstra_map.get_direction_at_point(2), -1)


func test_get_direction_at_points() -> void:
	var dijkstra_map := DijkstraMap.new()
	dijkstra_map.add_point(0)
	dijkstra_map.add_point(1)
	dijkstra_map.add_point(2)
	dijkstra_map.connect_points(0, 1)
	dijkstra_map.recalculate(0, {})
	assert_engine_error(TERRAIN_WEIGHTS_WARNING)
	assert_eq(Array(dijkstra_map.get_direction_at_points(PackedInt32Array([0, 1, 2]))), [0, 0, -1])


func test_get_cost_at_points() -> void:
	var dijkstra_map := DijkstraMap.new()
	dijkstra_map.add_point(0)
	dijkstra_map.add_point(1)
	dijkstra_map.add_point(2)
	dijkstra_map.connect_points(0, 1)
	dijkstra_map.recalculate(0, {})
	assert_engine_error(TERRAIN_WEIGHTS_WARNING)
	assert_eq(Array(dijkstra_map.get_cost_at_points(PackedInt32Array([0, 1, 2]))), [0.0, 1.0, INF])


func test_get_cost_map() -> void:
	var dijkstra_map := DijkstraMap.new()
	dijkstra_map.add_point(0)
	dijkstra_map.add_point(1)
	dijkstra_map.add_point(2)
	dijkstra_map.connect_points(0, 1)
	dijkstra_map.recalculate(0, {})
	assert_engine_error(TERRAIN_WEIGHTS_WARNING)
	var cost_map: Dictionary[int, float] = { 0: 0.0, 1: 1.0 }
	var computed_cost_map := dijkstra_map.get_cost_map()
	for id: int in computed_cost_map.keys():
		assert_eq(computed_cost_map[id], cost_map[id])


func test_get_direction_map() -> void:
	var dijkstra_map := DijkstraMap.new()
	dijkstra_map.add_point(0)
	dijkstra_map.add_point(1)
	dijkstra_map.add_point(2)
	dijkstra_map.connect_points(0, 1)
	dijkstra_map.recalculate(0, {})
	assert_engine_error(TERRAIN_WEIGHTS_WARNING)
	var direction_map: Dictionary[int, int] = { 0: 0, 1: 0 }
	var computed_direction_map := dijkstra_map.get_direction_map()
	for id: int in computed_direction_map.keys():
		assert_eq(computed_direction_map[id], direction_map[id])


func test_get_all_points_with_cost_between() -> void:
	var dijkstra_map := DijkstraMap.new()
	dijkstra_map.add_point(0)
	dijkstra_map.add_point(1)
	dijkstra_map.add_point(2)
	dijkstra_map.connect_points(0, 1)
	dijkstra_map.recalculate(0, {})
	assert_engine_error(TERRAIN_WEIGHTS_WARNING)
	assert_eq(Array(dijkstra_map.get_all_points_with_cost_between(0.5, 1.5)), [1])
