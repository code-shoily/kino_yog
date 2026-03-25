# KinoYog

Kino smart cells for [Yog](https://github.com/code-shoily/yog_ex) graph library.

## Features

Two smart cells for interactive graph work in Livebook:

1. **Yog - Load Graph** - Import graphs from files (GraphML, JSON, GDF, Pajek, LEDA, TGF) or paste content (adjacency list, matrix, JSON, edge list)
2. **Yog - Render Graph** - Generate graphs from built-in generators with live preview or visualize existing variables in the notebook

## Installation

Add to your `mix.exs`:

```elixir
def deps do
  [
    {:kino_yog, "~> 0.1.0"}
  ]
end
```

## Usage

In Livebook, click "Smart" and select one of the Yog graph cells.

### Load Graph

Select "From File" and enter a path, or "Paste Content" and choose a format.
It supports auto-detection for files and provides live parsing for content.

### Render Graph

Select "Render Variable" to pick a graph from your notebook, or "Render Graph" to use generators.
It includes all classic and random generators from `Yog`.

Select a graph file and assign it to a variable:

```elixir
graph = KinoYog.import_file("path/to/graph.graphml")
```

Supported formats (auto-detected by extension):
- `.graphml`, `.xml` - GraphML format
- `.json` - JSON format
- `.gdf` - GUESS GDF format
- `.net`, `.paj` - Pajek format
- `.leda` - LEDA format
- `.tgf` - Trivial Graph Format

### Graph Content Import

Paste graph content and select the format:

```elixir
# Adjacency list
graph = 
  Yog.IO.List.from_string(
    :undirected,
    """
    1: 2 3
    2: 3
    3:
    """,
    weighted: false
  )

# Or adjacency matrix
matrix = [
  [0, 1, 1],
  [1, 0, 0],
  [1, 0, 0]
]
graph = Yog.IO.Matrix.from_matrix(:undirected, matrix)
```

### Graph Gallery

Generate graphs with parameter sliders and live preview:

```elixir
# Complete graph K₅
graph = Yog.Generator.Classic.complete(5)

# Or directed
graph = Yog.Generator.Classic.complete_with_type(5, :directed)

# Random graph
graph = Yog.Generator.Random.barabasi_albert(50, 2)
```

Available generators:
- **Classic**: Complete, Cycle, Path, Star, Wheel, Grid, Bipartite, Binary Tree, Petersen, Hypercube, Ladder, Turán
- **Random**: Erdős-Rényi, Barabási-Albert, Watts-Strogatz, Random Regular

## Screenshots

### Graph Gallery

Select graph type, adjust parameters with sliders, see live preview:

```
┌────────────────────────────────────────────────────────────┐
│ Graph Type: [Complete Graph (Kₙ) ▼]   ☑ Directed           │
├────────────────────────────────────────────────────────────┤
│ Parameters                                                 │
│   n: [────────●──────] 5                                   │
├────────────────────────────────────────────────────────────┤
│ Stats: 5 nodes, 10 edges, Connected: Yes                   │
├────────────────────────────────────────────────────────────┤
│ Visualization (GraphViz SVG)                               │
│       ┌───┐                                                │
│      /  1  \                                               │
│     /   │   \                                              │
│    2────┼────3                                             │
│     \   │   /                                              │
│      \  │  /                                               │
│       └─┴─┘                                                │
│        4 5                                                 │
└────────────────────────────────────────────────────────────┘
```

## License

Apache-2.0
