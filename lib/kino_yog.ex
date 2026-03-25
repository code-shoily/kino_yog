defmodule KinoYog do
  @moduledoc """
  Kino integration for Yog graph library.

  Provides smart cells for:

  1. **Load Graph** - Import graphs from files or paste content
  2. **Render Graph** - Visualize existing variables or generate new graphs

  ## Usage

  In Livebook, click "Smart" and select one of the Yog graph cells.

  ## Examples

  ### Load Graph from File

      graph = KinoYog.import_file("path/to/graph.graphml")

  ### Load Graph from Content

      graph = Yog.IO.List.from_string(:undirected, "1: 2 3\n2: 3")

  ### Render Graph

      # Visualize existing variable
      # OR generate new graph
      graph = Yog.Generator.Classic.complete(5)
  """

  use Application

  @impl true
  def start(_type, _args) do
    Kino.SmartCell.register(KinoYog.LoadGraphCell)
    Kino.SmartCell.register(KinoYog.RenderCell)

    Supervisor.start_link([], strategy: :one_for_one)
  end

  @doc """
  Import a graph from a file.
  """
  defdelegate import_file(path), to: KinoYog.Importer

  @doc """
  Import a graph from content.
  """
  defdelegate import_content(content, format, opts \\ []), to: KinoYog.Importer
end
