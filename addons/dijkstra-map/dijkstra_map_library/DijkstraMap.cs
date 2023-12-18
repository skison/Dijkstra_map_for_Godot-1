using System;
using System.Collections.Generic;
using Godot;
using Godot.Collections;
using Array = Godot.Collections.Array;
using Object = Godot.GodotObject;

/// <summary>
/// C# Wrapper for DijkstraMap code, provides easier access to the DijkstraMap API.
/// This is only optional, you can also choose to access DijkstraMap via ClassDB, e.g.:
///     var my_dijkstramap = ClassDB.Instantiate("DijkstraMap").AsGodotObject();
/// But this alone will not enforce type safety or give autocompletion hints.
/// Keep an eye out for future Godot Engine advancements that may make this wrapper obsolete,
/// e.g. via automatic C# bindings generation or a conversion over to a unified GDExtension layer.
/// </summary>
public partial class DijkstraMap : Node
{
    private Object _dijkstraMap;
    
    public DijkstraMap()
    {
        _dijkstraMap = ClassDB.Instantiate("DijkstraMap").AsGodotObject();
        if (_dijkstraMap is null) throw new ArgumentNullException($"{nameof(_dijkstraMap)} cannot be null.");
    }

    public void Clear()
    {
        _dijkstraMap.Call("clear");
    }

    public Error DuplicateGraphFrom(DijkstraMap sourceInstance)
    {
        return (Error)_dijkstraMap.Call("duplicate_graph_from", sourceInstance._dijkstraMap).Obj;
    }

    public int GetAvailablePointId()
    {
        return (int)_dijkstraMap.Call("get_available_point_id");
    }

    public Error AddPoint(int pointId, int terrainType = -1)
    {
        return (Error)_dijkstraMap.Call("add_point", pointId, terrainType).Obj;
    }

    public Error SetTerrainForPoint(int pointId, int terrainId = -1)
    {
        return (Error)_dijkstraMap.Call("set_terrain_for_point", pointId, terrainId).Obj;
    }

    public int GetTerrainForPoint(int pointId)
    {
        return (int)_dijkstraMap.Call("get_terrain_for_point", pointId);
    }

    public Error RemovePoint(int pointId)
    {
        return (Error)_dijkstraMap.Call("remove_point", pointId).Obj;
    }

    public bool HasPoint(int pointId)
    {
        return (bool)_dijkstraMap.Call("has_point", pointId);
    }

    public Error DisablePoint(int pointId)
    {
        return (Error)_dijkstraMap.Call("disable_point", pointId).Obj;
    }

    public Error EnablePoint(int pointId)
    {
        return (Error)_dijkstraMap.Call("enable_point", pointId).Obj;
    }

    public bool IsPointDisabled(int pointId)
    {
        return (bool)_dijkstraMap.Call("is_point_disabled", pointId);
    }

    public Error ConnectPoints(int source, int target, float weight = 1f, bool bidirectional = true)
    {
        return (Error)_dijkstraMap.Call("connect_points", source, target, weight, bidirectional).Obj;
    }

    public Error RemoveConnection(int source, int target, bool bidirectional = true)
    {
        return (Error)_dijkstraMap.Call("remove_connection", source, target, bidirectional).Obj;
    }

    public bool HasConnection(int source, int target)
    {
        return (bool)_dijkstraMap.Call("has_connection", source, target);
    }

    public int GetDirectionAtPoint(int pointId)
    {
        return (int)_dijkstraMap.Call("get_direction_at_point", pointId);
    }

    public float GetCostAtPoint(int pointId)
    {
        return (float)_dijkstraMap.Call("get_cost_at_point", pointId);
    }

    public Error Recalculate(int pointId, Godot.Collections.Dictionary<string, Variant> options)
    {
        return (Error)_dijkstraMap.Call("recalculate", pointId, options).Obj;
    }

    public Error Recalculate(Array<int> pointIds, Godot.Collections.Dictionary<string, Variant> options)
    {
        return (Error)_dijkstraMap.Call("recalculate", pointIds, options).Obj;
    }

    public Error Recalculate(int pointId, IEnumerable<IDijkstraMapRecalculateOptions> options)
    {
        return Recalculate(pointId, GetGeneralizedOptions(options));
    }

    public Error Recalculate(Array<int> pointIds, IEnumerable<IDijkstraMapRecalculateOptions> options)
    {
        return Recalculate(pointIds, GetGeneralizedOptions(options));
    }

    public Array<int> GetDirectionAtPoints(Array<int> points)
    {
        var array = _dijkstraMap.Call("get_direction_at_points", points).Obj as Array;
        return new Array<int>(array);
    }

    public Array<int> GetCostAtPoints(Array<int> points)
    {
        var array = _dijkstraMap.Call("get_cost_at_points", points).Obj as Array;
        return new Array<int>(array);
    }

    public Godot.Collections.Dictionary<int, float> GetCostMap()
    {
        var dictionary = _dijkstraMap.Call("get_cost_map").Obj as Dictionary;
        return new Godot.Collections.Dictionary<int, float>(dictionary);
    }

    public Godot.Collections.Dictionary<int, int> GetDirectionMap()
    {
        var dictionary = _dijkstraMap.Call("get_direction_map").Obj as Dictionary;
        return new Godot.Collections.Dictionary<int, int>(dictionary);
    }

    public Array<int> GetAllPointsWithCostBetween(float minCost, float maxCost)
    {
        var array = _dijkstraMap.Call("get_all_points_with_cost_between", minCost, maxCost).Obj as Array;
        return new Array<int>(array);
    }

    public Array<int> GetShortestPathFromPoint(int pointId)
    {
        var array = _dijkstraMap.Call("get_shortest_path_from_point", pointId).Obj as Array;
        return new Array<int>(array);
    }

    public Godot.Collections.Dictionary<Vector2, int> AddSquareGrid(Rect2 bounds, int terrainType = -1,
        float orthogonalCost = 1f, float diagonalCost = float.PositiveInfinity)
    {
        var dictionary = _dijkstraMap.Call("add_square_grid", bounds, terrainType, orthogonalCost, diagonalCost).Obj
            as Dictionary;
        return new Godot.Collections.Dictionary<Vector2, int>(dictionary);
    }

    public Godot.Collections.Dictionary<Vector2, int> AddHexagonalGrid(Rect2 bounds, int terrainType = -1,
        float weight = 1f)
    {
        var dictionary = _dijkstraMap.Call("add_hexagonal_grid", bounds, terrainType, weight).Obj
            as Dictionary;
        return new Godot.Collections.Dictionary<Vector2, int>(dictionary);
    }

    private static Godot.Collections.Dictionary<string, Variant> GetGeneralizedOptions(
        IEnumerable<IDijkstraMapRecalculateOptions> options)
    {
        var dictionary = new Godot.Collections.Dictionary<string, Variant>();
        foreach (var option in options)
        {
            dictionary.Add(option.Key, option.Value);
        }

        return dictionary;
    }
}

public interface IDijkstraMapRecalculateOptions
{
    string Key { get; }
    Variant Value { get; }
}

public class InputIsDestination : IDijkstraMapRecalculateOptions
{
    public string Key { get; }
    public Variant Value { get; }

    public InputIsDestination(bool value = true)
    {
        Key = "input_is_destination";
        Value = value;
    }
}

public class MaximumCost : IDijkstraMapRecalculateOptions
{
    public string Key { get; }
    public Variant Value { get; }

    public MaximumCost(float value = float.PositiveInfinity)
    {
        Key = "maximum_cost";
        Value = value;
    }
}

public class InitialCosts : IDijkstraMapRecalculateOptions
{
    public string Key { get; }
    public Variant Value { get; }

    public InitialCosts(Array<float> values)
    {
        Key = "initial_costs";
        Value = values;
    }
}

public class TerrainWeights : IDijkstraMapRecalculateOptions
{
    public string Key { get; }
    public Variant Value { get; }

    public TerrainWeights(Godot.Collections.Dictionary<int, float> weightsByTerrainId)
    {
        Key = "terrain_weights";
        Value = weightsByTerrainId;
    }
}

public class TerminationPoints : IDijkstraMapRecalculateOptions
{
    public string Key { get; }
    public Variant Value { get; }

    public TerminationPoints(Array<int> pointIds)
    {
        Key = "termination_points";
        Value = pointIds;
    }
}