defmodule KinoYog.Importer do
  @moduledoc """
  Helper functions for importing graphs in KinoYog smart cells.
  """

  @doc """
  Import a graph from a file, auto-detecting format from extension.
  """
  def import_file(path) do
    if File.exists?(path) do
      ext = String.downcase(Path.extname(path))

      case ext do
        ".graphml" -> Yog.IO.GraphML.read(path)
        ".xml" -> Yog.IO.GraphML.read(path)
        ".json" -> import_json_file(path)
        ".dot" -> import_dot_file(path)
        ".gv" -> import_dot_file(path)
        ".gdf" -> Yog.IO.GDF.read(path)
        ".net" -> Yog.IO.Pajek.read(path)
        ".paj" -> Yog.IO.Pajek.read(path)
        ".leda" -> Yog.IO.LEDA.read(path)
        ".tgf" -> Yog.IO.TGF.read(path, :directed)
        _ -> {:error, "Unknown file format: #{ext}"}
      end
    else
      {:error, "File not found: #{path}"}
    end
  end

  defp import_json_file(path) do
    case File.read(path) do
      {:ok, content} -> Yog.IO.JSON.from_json(content)
      {:error, _} = e -> e
    end
  end

  defp import_dot_file(_path) do
    # DOT import not yet implemented in Yog
    {:error, "DOT import not yet implemented. Use Render cell to see DOT output."}
  end

  @doc """
  Import graph from content string with explicit format.
  """
  def import_content(content, format, opts \\ [])

  def import_content(content, :adjacency_list, opts) do
    directed = Keyword.get(opts, :directed, false)
    weighted = Keyword.get(opts, :weighted, false)
    type = if directed, do: :directed, else: :undirected
    Yog.IO.List.from_string(type, content, weighted: weighted)
  end

  def import_content(content, :adjacency_matrix, opts) do
    directed = Keyword.get(opts, :directed, false)
    type = if directed, do: :directed, else: :undirected

    matrix =
      content
      |> String.split("\n", trim: true)
      |> Enum.map(fn line ->
        line
        |> String.split(~r/\s+/, trim: true)
        |> Enum.map(&parse_number/1)
      end)

    Yog.IO.Matrix.from_matrix(type, matrix)
  end

  def import_content(content, :json, _opts) do
    Yog.IO.JSON.from_json(content)
  end

  def import_content(content, :edge_list, opts) do
    directed = Keyword.get(opts, :directed, false)
    type = if directed, do: :directed, else: :undirected

    edges =
      content
      |> String.split("\n", trim: true)
      |> Enum.reject(&String.starts_with?(&1, "#"))
      |> Enum.map(fn line ->
        parts = String.split(line, ~r/\s+/, trim: true)

        case parts do
          [from, to] -> {parse_id(from), parse_id(to), 1}
          [from, to, weight | _] -> {parse_id(from), parse_id(to), parse_number(weight)}
          _ -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    edges
    |> Enum.reduce(Yog.new(type), fn {from, to, weight}, g ->
      g
      |> Yog.add_node(from, nil)
      |> Yog.add_node(to, nil)
      |> Yog.add_edge!(from: from, to: to, with: weight)
    end)
  end

  defp parse_number(str) do
    case Integer.parse(str) do
      {int, ""} ->
        int

      _ ->
        case Float.parse(str) do
          {float, ""} -> float
          _ -> 0
        end
    end
  end

  defp parse_id(str) do
    case Integer.parse(str) do
      {int, ""} -> int
      _ -> str
    end
  end
end
