defmodule KinoYogTest do
  use ExUnit.Case

  describe "Importer" do
    alias KinoYog.Importer

    test "import_content with adjacency list" do
      content = """
      1: 2 3
      2: 3
      3:
      """

      graph = Importer.import_content(content, :adjacency_list, directed: false)
      assert Yog.Model.order(graph) == 3
      assert Yog.Model.edge_count(graph) == 3
    end

    test "import_content with adjacency matrix" do
      content = """
      0 1 1
      1 0 0
      1 0 0
      """

      graph = Importer.import_content(content, :adjacency_matrix, directed: false)
      assert Yog.Model.order(graph) == 3
      assert Yog.Model.edge_count(graph) == 2
    end

    test "import_content with edge list" do
      content = """
      1 2
      2 3
      1 3
      """

      graph = Importer.import_content(content, :edge_list, directed: false)
      assert Yog.Model.order(graph) == 3
      assert Yog.Model.edge_count(graph) == 3
    end
  end
end
