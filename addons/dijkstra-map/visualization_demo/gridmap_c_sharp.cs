using Godot;
using Godot.Collections;

/// <summary>
/// Recreation of the GDScript DijkstraMap visualization code (gridmap.gd) in C#.
/// Please refer to the GDScript version for full code documentation.
/// </summary>
public partial class gridmap_c_sharp : TileMap
{
    private readonly DijkstraMap _dijkstraMap = new DijkstraMap();
    private readonly Dictionary<int, Vector2> _idToPos = new Dictionary<int, Vector2>();
    private Dictionary<Vector2, int> _posToId = new Dictionary<Vector2, int>();
    private int _tileToDraw = 0;
    private bool _dragging = false;

    private enum Layers { Main, Costs, Directions }
    private enum TileAtlases { Main, Gradient }
    private enum MainTiles { SmoothTerrain, RoughTerrain, Wall, Origin }
    private Dictionary<int, float> TerrainWeights = new Dictionary<int, float>() {
        { (int)MainTiles.SmoothTerrain, 1.0f },
        { (int)MainTiles.RoughTerrain, 4.0f },
        { (int)MainTiles.Wall, float.PositiveInfinity },
        { (int)MainTiles.Origin, 1.0f },
    };
    private enum ArrowTiles { Right, UpRight, Down, DownRight, Left, DownLeft, Up, UpLeft }
    private Dictionary<Vector2I, int> ArrowDirections = new Dictionary<Vector2I, int>() {
        { new Vector2I(1, 0), (int)ArrowTiles.Right },
        { new Vector2I(1, -1), (int)ArrowTiles.UpRight },
        { new Vector2I(0, 1), (int)ArrowTiles.Down },
        { new Vector2I(1, 1), (int)ArrowTiles.DownRight },
        { new Vector2I(-1, 0), (int)ArrowTiles.Left },
        { new Vector2I(-1, 1), (int)ArrowTiles.DownLeft },
        { new Vector2I(0, -1), (int)ArrowTiles.Up },
        { new Vector2I(-1, -1), (int)ArrowTiles.UpLeft }
    };
    private const int MaxVisualCost = 31;
    private Rect2 TileMapRect = new Rect2(0, 0, 23, 19);

    public override void _Ready()
    {
        var @event = new InputEventMouseButton();
        @event.ButtonIndex = MouseButton.Left;
        if (!InputMap.HasAction("left_mouse_button"))
        {
            InputMap.AddAction("left_mouse_button");
        }
        InputMap.ActionAddEvent("left_mouse_button", @event);

        _posToId = _dijkstraMap.AddSquareGrid(TileMapRect, -1, 1.0f, float.PositiveInfinity);
        foreach (var posToId in _posToId)
        {
            _idToPos[posToId.Value] = posToId.Key;
        }

        UpdateTerrainIds();
        Recalculate();
    }

    private void Recalculate()
    {
        var targets = new Array<Vector2I>(GetUsedCellsById((int)Layers.Main, (int)TileAtlases.Main, GetMainTileSetAtlasPos((int)MainTiles.Origin)));
        var targetIds = new Array<int>();
        foreach (var pos in targets)
        {
            targetIds.Add(_posToId[pos]);
        }
        _dijkstraMap.Recalculate(targetIds, new IDijkstraMapRecalculateOptions[]
        {
            new TerrainWeights(TerrainWeights)
        });

        var costs = _dijkstraMap.GetCostMap();
        ClearLayer((int)Layers.Costs);

        foreach (var id in costs.Keys)
        {
            var cost = Mathf.Clamp(costs[id], 0, MaxVisualCost);
            SetCell((int)Layers.Costs, (Vector2I)_idToPos[id], (int)TileAtlases.Gradient, GetTileSetAtlasPosForCostValue((int)cost));
        }

        var dirIds = _dijkstraMap.GetDirectionMap();
        ClearLayer((int)Layers.Directions);

        foreach (var id in dirIds.Keys)
        {
            var pos = (Vector2I)_idToPos[id];
            var dir = (
                _idToPos.ContainsKey(dirIds[id]) ? (Vector2I)_idToPos[dirIds[id]] : new Vector2I(int.MaxValue, int.MaxValue)
            ) - pos;
            SetCell((int)Layers.Directions, (Vector2I)_idToPos[id], (int)TileAtlases.Main, GetArrowTileAtlasPosForDirection(dir));
        }
    }

    private void UpdateTerrainIds()
    {
        foreach (var id in _idToPos.Keys)
        {
            var pos = _idToPos[id];
            _dijkstraMap.SetTerrainForPoint(id, GetTileTypeFromCellPosition((Vector2I)pos));
        }
    }

    private Vector2I GetMainTileSetAtlasPos(int mainTileType)
    {
        return new Vector2I(mainTileType, 0);
    }

    private int GetTileTypeFromCellPosition(Vector2I cellPos)
    {
        return GetCellAtlasCoords((int)Layers.Main, cellPos).X;
    }

    private Vector2I GetTileSetAtlasPosForCostValue(int cost)
    {
        return new Vector2I(Mathf.Clamp(cost, 0, MaxVisualCost), 0);
    }

    private int GetArrowTileTypeForDirection(Vector2I dir)
    {
        return ArrowDirections.ContainsKey(dir) ? ArrowDirections[dir] : 0;
    }

    private Vector2I GetArrowTileAtlasPosForType(int arrowTileType)
    {
        return new Vector2I(arrowTileType, 1);
    }

    private Vector2I GetArrowTileAtlasPosForDirection(Vector2I dir)
    {
        return GetArrowTileAtlasPosForType(GetArrowTileTypeForDirection(dir));
    }

    public void OnTerrainSelectionItemSelected(int index)
    {
        _tileToDraw = index;
    }

    public void OnVisualizationSelectionItemSelected(int index)
    {
        foreach (var layer in new[] { (int)Layers.Costs, (int)Layers.Directions })
        {
            SetLayerEnabled(layer, index == layer);
        }
    }

    public override void _UnhandledInput(InputEvent @event)
    {
        if (@event.IsActionPressed("left_mouse_button")) _dragging = true;
        if (@event.IsActionReleased("left_mouse_button")) _dragging = false;

        if ((@event is InputEventMouseMotion || @event is InputEventMouseButton) && _dragging)
        {
            var pos = GetLocalMousePosition();
            var cell = LocalToMap(pos);
            if (cell.X >= 0 && cell.X < TileMapRect.Size.X && cell.Y >= 0 && cell.Y < TileMapRect.Size.Y)
            {
                SetCell((int)Layers.Main, cell, (int)TileAtlases.Main, GetMainTileSetAtlasPos(_tileToDraw));
                _dijkstraMap.SetTerrainForPoint(_posToId[cell], _tileToDraw);
                Recalculate();
            }
        }
    }
}