defmodule KinoYog.Generators do
  def all do
    classic() ++ random()
  end

  def classic do
    [
      %{
        id: "complete",
        name: "Complete Graph (Kₙ)",
        category: "Classic",
        module: Yog.Generator.Classic,
        params: [%{name: "n", type: "integer", min: 1, max: 100, default: 5, label: "Nodes (n)"}],
        guards: %{max_nodes: 200}
      },
      %{
        id: "cycle",
        name: "Cycle Graph (Cₙ)",
        category: "Classic",
        module: Yog.Generator.Classic,
        params: [%{name: "n", type: "integer", min: 3, max: 200, default: 5, label: "Nodes (n)"}],
        guards: %{max_nodes: 500}
      },
      %{
        id: "path",
        name: "Path Graph (Pₙ)",
        category: "Classic",
        module: Yog.Generator.Classic,
        params: [%{name: "n", type: "integer", min: 1, max: 200, default: 5, label: "Nodes (n)"}],
        guards: %{max_nodes: 500}
      },
      %{
        id: "star",
        name: "Star Graph (Sₙ)",
        category: "Classic",
        module: Yog.Generator.Classic,
        params: [%{name: "n", type: "integer", min: 2, max: 200, default: 5, label: "Nodes (n)"}],
        guards: %{max_nodes: 500}
      },
      %{
        id: "wheel",
        name: "Wheel Graph (Wₙ)",
        category: "Classic",
        module: Yog.Generator.Classic,
        params: [%{name: "n", type: "integer", min: 4, max: 200, default: 5, label: "Nodes (n)"}],
        guards: %{max_nodes: 500}
      },
      %{
        id: "grid_2d",
        name: "2D Grid",
        category: "Classic",
        module: Yog.Generator.Classic,
        params: [
          %{name: "rows", type: "integer", min: 1, max: 20, default: 3, label: "Rows"},
          %{name: "cols", type: "integer", min: 1, max: 20, default: 4, label: "Columns"}
        ],
        guards: %{max_nodes: 400}
      },
      %{
        id: "complete_bipartite",
        name: "Complete Bipartite (Kₘ,ₙ)",
        category: "Classic",
        module: Yog.Generator.Classic,
        params: [
          %{name: "m", type: "integer", min: 1, max: 50, default: 3, label: "Partition A"},
          %{name: "n", type: "integer", min: 1, max: 50, default: 4, label: "Partition B"}
        ],
        guards: %{max_nodes: 100}
      },
      %{
        id: "binary_tree",
        name: "Binary Tree",
        category: "Classic",
        module: Yog.Generator.Classic,
        params: [%{name: "depth", type: "integer", min: 0, max: 10, default: 3, label: "Depth"}],
        guards: %{max_depth: 10, max_nodes: 2047}
      },
      %{
        id: "kary_tree",
        name: "k-ary Tree",
        category: "Classic",
        module: Yog.Generator.Classic,
        params: [
          %{name: "depth", type: "integer", min: 0, max: 8, default: 3, label: "Depth"},
          %{name: "arity", type: "integer", min: 1, max: 5, default: 2, label: "Arity (k)"}
        ],
        guards: %{max_nodes: 1000}
      },
      %{
        id: "complete_kary",
        name: "Complete k-ary Tree",
        category: "Classic",
        module: Yog.Generator.Classic,
        params: [
          %{name: "n", type: "integer", min: 1, max: 500, default: 15, label: "Nodes (n)"},
          %{name: "arity", type: "integer", min: 1, max: 5, default: 2, label: "Arity (k)"}
        ],
        guards: %{max_nodes: 1000}
      },
      %{
        id: "caterpillar",
        name: "Caterpillar Tree",
        category: "Classic",
        module: Yog.Generator.Classic,
        params: [
          %{name: "n", type: "integer", min: 1, max: 100, default: 20, label: "Total Nodes (n)"},
          %{
            name: "spine_length",
            type: "integer",
            min: 1,
            max: 50,
            default: 5,
            label: "Spine Length"
          }
        ],
        guards: %{max_nodes: 200}
      },
      %{
        id: "hypercube",
        name: "Hypercube (Qₙ)",
        category: "Classic",
        module: Yog.Generator.Classic,
        params: [
          %{name: "n", type: "integer", min: 0, max: 8, default: 3, label: "Dimension (n)"}
        ],
        guards: %{max_n: 8, max_nodes: 256}
      },
      %{
        id: "ladder",
        name: "Ladder Graph",
        category: "Classic",
        module: Yog.Generator.Classic,
        params: [%{name: "n", type: "integer", min: 1, max: 100, default: 4, label: "Rungs (n)"}],
        guards: %{max_nodes: 200}
      },
      %{
        id: "circular_ladder",
        name: "Circular Ladder",
        category: "Classic",
        module: Yog.Generator.Classic,
        params: [%{name: "n", type: "integer", min: 3, max: 100, default: 4, label: "Rungs (n)"}],
        guards: %{max_nodes: 200}
      },
      %{
        id: "mobius_ladder",
        name: "Möbius Ladder",
        category: "Classic",
        module: Yog.Generator.Classic,
        params: [%{name: "n", type: "integer", min: 2, max: 100, default: 4, label: "Rungs (n)"}],
        guards: %{max_nodes: 200}
      },
      %{
        id: "friendship",
        name: "Friendship Graph (Fₙ)",
        category: "Classic",
        module: Yog.Generator.Classic,
        params: [
          %{name: "n", type: "integer", min: 1, max: 100, default: 3, label: "Triangles (n)"}
        ],
        guards: %{max_nodes: 201}
      },
      %{
        id: "book",
        name: "Book Graph (Bₙ)",
        category: "Classic",
        module: Yog.Generator.Classic,
        params: [%{name: "n", type: "integer", min: 1, max: 100, default: 3, label: "Pages (n)"}],
        guards: %{max_nodes: 200}
      },
      %{
        id: "crown",
        name: "Crown Graph",
        category: "Classic",
        module: Yog.Generator.Classic,
        params: [%{name: "n", type: "integer", min: 2, max: 50, default: 4, label: "Size (n)"}],
        guards: %{max_nodes: 100}
      },
      %{
        id: "turan",
        name: "Turán Graph T(n,r)",
        category: "Classic",
        module: Yog.Generator.Classic,
        params: [
          %{name: "n", type: "integer", min: 1, max: 50, default: 10, label: "Total nodes (n)"},
          %{name: "r", type: "integer", min: 1, max: 10, default: 3, label: "Partitions (r)"}
        ],
        guards: %{max_nodes: 100}
      },
      %{
        id: "balanced_tree",
        name: "Balanced Tree",
        category: "Classic",
        module: Yog.Generator.Classic,
        params: [
          %{
            name: "r",
            type: "integer",
            min: 1,
            max: 5,
            default: 2,
            label: "Branching Factor (r)"
          },
          %{name: "h", type: "integer", min: 0, max: 8, default: 3, label: "Height (h)"}
        ],
        guards: %{max_nodes: 1024}
      },
      %{
        id: "binomial_tree",
        name: "Binomial Tree (Bₙ)",
        category: "Classic",
        module: Yog.Generator.Classic,
        params: [%{name: "n", type: "integer", min: 0, max: 10, default: 3, label: "Order (n)"}],
        guards: %{max_nodes: 1024}
      },
      %{
        id: "petersen",
        name: "Petersen Graph",
        category: "Named",
        module: Yog.Generator.Classic,
        params: [],
        guards: %{fixed_size: 10}
      },
      %{
        id: "tetrahedron",
        name: "Tetrahedron",
        category: "Named",
        module: Yog.Generator.Classic,
        function: :tetrahedron,
        no_type_suffix: true,
        params: [],
        guards: %{fixed_size: 4}
      },
      %{
        id: "cube",
        name: "Cube",
        category: "Named",
        module: Yog.Generator.Classic,
        function: :cube,
        no_type_suffix: true,
        params: [],
        guards: %{fixed_size: 8}
      },
      %{
        id: "octahedron",
        name: "Octahedron",
        category: "Named",
        module: Yog.Generator.Classic,
        function: :octahedron,
        no_type_suffix: true,
        params: [],
        guards: %{fixed_size: 6}
      },
      %{
        id: "dodecahedron",
        name: "Dodecahedron",
        category: "Named",
        module: Yog.Generator.Classic,
        function: :dodecahedron,
        no_type_suffix: true,
        params: [],
        guards: %{fixed_size: 20}
      },
      %{
        id: "icosahedron",
        name: "Icosahedron",
        category: "Named",
        module: Yog.Generator.Classic,
        function: :icosahedron,
        no_type_suffix: true,
        params: [],
        guards: %{fixed_size: 12}
      }
    ]
  end

  def random do
    [
      %{
        id: "erdos_renyi_gnp",
        name: "Erdős-Rényi G(n,p)",
        category: "Random",
        module: Yog.Generator.Random,
        params: [
          %{name: "n", type: "integer", min: 2, max: 100, default: 20, label: "Nodes (n)"},
          %{
            name: "p",
            type: "float",
            min: 0.0,
            max: 1.0,
            step: 0.01,
            default: 0.15,
            label: "Probability (p)"
          }
        ],
        guards: %{max_nodes: 200}
      },
      %{
        id: "erdos_renyi_gnm",
        name: "Erdős-Rényi G(n,m)",
        category: "Random",
        module: Yog.Generator.Random,
        params: [
          %{name: "n", type: "integer", min: 2, max: 100, default: 20, label: "Nodes (n)"},
          %{name: "m", type: "integer", min: 0, max: 500, default: 30, label: "Edges (m)"}
        ],
        guards: %{max_nodes: 200}
      },
      %{
        id: "barabasi_albert",
        name: "Barabási-Albert",
        category: "Random",
        module: Yog.Generator.Random,
        params: [
          %{name: "n", type: "integer", min: 2, max: 200, default: 50, label: "Nodes (n)"},
          %{name: "m", type: "integer", min: 1, max: 10, default: 2, label: "Edges per node (m)"}
        ],
        guards: %{max_nodes: 300}
      },
      %{
        id: "watts_strogatz",
        name: "Watts-Strogatz",
        category: "Random",
        module: Yog.Generator.Random,
        params: [
          %{name: "n", type: "integer", min: 3, max: 100, default: 20, label: "Nodes (n)"},
          %{name: "k", type: "integer", min: 2, max: 10, default: 4, label: "Neighbors (k)"},
          %{
            name: "p",
            type: "float",
            min: 0.0,
            max: 1.0,
            step: 0.01,
            default: 0.1,
            label: "Rewiring (p)"
          }
        ],
        guards: %{max_nodes: 200}
      },
      %{
        id: "random_regular",
        name: "Random d-Regular",
        category: "Random",
        module: Yog.Generator.Random,
        params: [
          %{name: "n", type: "integer", min: 2, max: 100, default: 10, label: "Nodes (n)"},
          %{name: "d", type: "integer", min: 0, max: 10, default: 3, label: "Degree (d)"}
        ],
        guards: %{max_nodes: 200}
      },
      %{
        id: "random_tree",
        name: "Random Tree",
        category: "Random",
        module: Yog.Generator.Random,
        params: [%{name: "n", type: "integer", min: 1, max: 200, default: 10, label: "Nodes (n)"}],
        guards: %{max_nodes: 500}
      },
      %{
        id: "sbm",
        name: "Stochastic Block Model",
        category: "Random",
        module: Yog.Generator.Random,
        params: [
          %{name: "n", type: "integer", min: 10, max: 200, default: 100, label: "Nodes (n)"},
          %{name: "k", type: "integer", min: 1, max: 10, default: 3, label: "Communities (k)"},
          %{
            name: "p_in",
            type: "float",
            min: 0.0,
            max: 1.0,
            step: 0.01,
            default: 0.1,
            label: "Prob In"
          },
          %{
            name: "p_out",
            type: "float",
            min: 0.0,
            max: 1.0,
            step: 0.01,
            default: 0.01,
            label: "Prob Out"
          }
        ],
        guards: %{max_nodes: 300}
      }
    ]
  end

  def estimate_nodes(id, params) do
    case id do
      "complete" ->
        params["n"]

      "cycle" ->
        params["n"]

      "path" ->
        params["n"]

      "star" ->
        params["n"]

      "wheel" ->
        params["n"]

      "grid_2d" ->
        params["rows"] * params["cols"]

      "complete_bipartite" ->
        params["m"] + params["n"]

      "binary_tree" ->
        Integer.pow(2, params["depth"] + 1) - 1

      "kary_tree" ->
        case params["arity"] do
          1 -> params["depth"] + 1
          k -> div(Integer.pow(k, params["depth"] + 1) - 1, k - 1)
        end

      "complete_kary" ->
        params["n"]

      "caterpillar" ->
        params["n"]

      "hypercube" ->
        Integer.pow(2, params["n"])

      "ladder" ->
        2 * params["n"]

      "circular_ladder" ->
        2 * params["n"]

      "mobius_ladder" ->
        2 * params["n"]

      "friendship" ->
        2 * params["n"] + 1

      "book" ->
        params["n"] + 2

      "crown" ->
        2 * params["n"]

      "turan" ->
        params["n"]

      "balanced_tree" ->
        case params["r"] do
          1 -> params["h"] + 1
          r -> div(Integer.pow(r, params["h"] + 1) - 1, r - 1)
        end

      "binomial_tree" ->
        Integer.pow(2, params["n"])

      "petersen" ->
        10

      "tetrahedron" ->
        4

      "cube" ->
        8

      "octahedron" ->
        6

      "dodecahedron" ->
        20

      "icosahedron" ->
        12

      "erdos_renyi_gnp" ->
        params["n"]

      "erdos_renyi_gnm" ->
        params["n"]

      "barabasi_albert" ->
        params["n"]

      "watts_strogatz" ->
        params["n"]

      "random_regular" ->
        params["n"]

      "random_tree" ->
        params["n"]

      "sbm" ->
        params["n"]

      _ ->
        100
    end
  end

  def get_by_id(id) do
    Enum.find(all(), &(&1.id == id))
  end
end
