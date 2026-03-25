defmodule KinoYog.LoadGraphCell do
  @moduledoc """
  Smart cell for loading graphs from files or pasted content.

  Two modes:
  1. **From File** - Auto-detects format from extension
  2. **Paste Content** - User selects format explicitly
  """

  use Kino.JS
  use Kino.JS.Live
  use Kino.SmartCell, name: "Yog - Load Graph"

  @file_formats %{
    ".graphml" => :graphml,
    ".xml" => :graphml,
    ".json" => :json,
    ".dot" => :dot,
    ".gv" => :dot,
    ".gdf" => :gdf,
    ".net" => :pajek,
    ".paj" => :pajek,
    ".leda" => :leda,
    ".tgf" => :tgf
  }

  @content_formats [
    %{id: "adjacency_list", name: "Adjacency List", example: "1: 2 3\n2: 3\n3:"},
    %{id: "adjacency_matrix", name: "Adjacency Matrix", example: "0 1 1\n1 0 0\n1 0 0"},
    %{
      id: "json",
      name: "JSON",
      example: ~s|{"nodes": [{"id": 1}], "edges": [{"source": 1, "target": 2}]}|
    },
    %{id: "dot", name: "DOT (GraphViz)", example: "graph G { 1 -- 2; 2 -- 3; }"},
    %{id: "graphml", name: "GraphML", example: "<graphml>...</graphml>"},
    %{id: "edge_list", name: "Edge List", example: "1 2\n2 3\n1 3"}
  ]

  @impl true
  def init(attrs, ctx) do
    # "paste" or "file"
    mode = attrs["mode"] || "paste"

    # File mode attrs
    file_path = attrs["file_path"] || ""

    # Paste mode attrs
    content = attrs["content"] || ""
    content_format = attrs["content_format"] || "adjacency_list"
    directed = attrs["directed"] || false

    # Common
    variable = attrs["variable"] || "graph"

    ctx =
      assign(ctx,
        mode: mode,
        # File mode
        file_path: file_path,
        file_format: detect_file_format(file_path),
        # Paste mode
        content: content,
        content_format: content_format,
        directed: directed,
        parsed: nil,
        # Common
        variable: variable,
        error: nil
      )

    # Try to parse content if in paste mode
    ctx = if mode == "paste" and content != "", do: try_parse(ctx), else: ctx

    {:ok, ctx, reevaluate_on_change: true}
  end

  @impl true
  def handle_connect(ctx) do
    {:ok,
     %{
       mode: ctx.assigns.mode,
       file_path: ctx.assigns.file_path,
       file_format: ctx.assigns.file_format,
       file_extensions: Map.keys(@file_formats),
       content: ctx.assigns.content,
       content_format: ctx.assigns.content_format,
       content_formats: @content_formats,
       directed: ctx.assigns.directed,
       variable: ctx.assigns.variable
     }, ctx}
  end

  # Mode switching
  @impl true
  def handle_event("update_mode", %{"mode" => mode}, ctx) do
    {:noreply, assign(ctx, mode: mode)}
  end

  # File mode handlers
  @impl true
  def handle_event("update_file_path", %{"path" => path}, ctx) do
    format = detect_file_format(path)

    ctx =
      assign(ctx,
        file_path: path,
        file_format: format,
        error: if(format == nil and path != "", do: "Unknown file format", else: nil)
      )

    {:noreply, ctx}
  end

  # Paste mode handlers
  @impl true
  def handle_event("update_content", %{"content" => content}, ctx) do
    ctx = assign(ctx, content: content)
    {:noreply, try_parse(ctx)}
  end

  @impl true
  def handle_event("update_content_format", %{"format" => format}, ctx) do
    ctx = assign(ctx, content_format: format)
    {:noreply, try_parse(ctx)}
  end

  @impl true
  def handle_event("toggle_directed", %{"directed" => directed}, ctx) do
    ctx = assign(ctx, directed: directed)
    {:noreply, try_parse(ctx)}
  end

  # Common handlers
  @impl true
  def handle_event("update_variable", %{"variable" => variable}, ctx) do
    {:noreply, assign(ctx, variable: sanitize_variable(variable))}
  end

  defp try_parse(ctx) do
    content = ctx.assigns.content
    format = ctx.assigns.content_format
    directed = if ctx.assigns.directed, do: :directed, else: :undirected

    if content == "" do
      assign(ctx, parsed: nil, error: nil)
    else
      case parse_content(content, format, directed) do
        {:ok, graph} ->
          stats = %{
            nodes: Yog.Model.order(graph),
            edges: Yog.Model.edge_count(graph)
          }

          broadcast_event(ctx, "parsed", %{stats: stats, error: nil})
          assign(ctx, parsed: graph, error: nil)

        {:error, reason} ->
          broadcast_event(ctx, "parsed", %{stats: nil, error: inspect(reason)})
          assign(ctx, parsed: nil, error: reason)
      end
    end
  end

  # Maximum content length to prevent UI freezing
  # 500KB
  @max_content_length 500_000

  defp parse_content(content, "adjacency_list", directed) do
    try do
      if String.length(content) > @max_content_length do
        {:error,
         "Content too large (#{String.length(content)} chars). Maximum: #{@max_content_length}"}
      else
        weighted = String.contains?(content, ",")
        graph = Yog.IO.List.from_string(directed, content, weighted: weighted)
        {:ok, graph}
      end
    rescue
      e -> {:error, Exception.message(e)}
    end
  end

  # Maximum matrix size to prevent UI freezing (100x100 = 10,000 cells)
  @max_matrix_size 100

  defp parse_content(content, "adjacency_matrix", directed) do
    try do
      lines = String.split(content, "\n", trim: true)

      # Check size limits
      row_count = length(lines)

      if row_count > @max_matrix_size do
        {:error,
         "Matrix too large (#{row_count} rows). Maximum: #{@max_matrix_size}x#{@max_matrix_size}"}
      else
        matrix =
          lines
          |> Enum.map(fn line ->
            line
            |> String.split(~r/\s+/, trim: true)
            |> Enum.map(&parse_number/1)
          end)

        # Check column count
        col_count = List.first(matrix, []) |> length()

        if col_count > @max_matrix_size do
          {:error,
           "Matrix too large (#{col_count} columns). Maximum: #{@max_matrix_size}x#{@max_matrix_size}"}
        else
          graph = Yog.IO.Matrix.from_matrix(directed, matrix)
          {:ok, graph}
        end
      end
    rescue
      e -> {:error, Exception.message(e)}
    end
  end

  defp parse_content(content, "json", _directed) do
    if String.length(content) > @max_content_length do
      {:error,
       "Content too large (#{String.length(content)} chars). Maximum: #{@max_content_length}"}
    else
      Yog.IO.JSON.from_json(content)
    end
  end

  # Maximum number of edges to prevent UI freezing
  @max_edges 10_000

  defp parse_content(content, "edge_list", directed) do
    try do
      if String.length(content) > @max_content_length do
        {:error,
         "Content too large (#{String.length(content)} chars). Maximum: #{@max_content_length}"}
      else
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

        if length(edges) > @max_edges do
          {:error, "Too many edges (#{length(edges)}). Maximum: #{@max_edges}"}
        else
          graph =
            edges
            |> Enum.reduce(Yog.new(directed), fn {from, to, weight}, g ->
              g
              |> Yog.add_node(from, nil)
              |> Yog.add_node(to, nil)
              |> Yog.add_edge!(from: from, to: to, with: weight)
            end)

          {:ok, graph}
        end
      end
    rescue
      e -> {:error, Exception.message(e)}
    end
  end

  defp parse_content(_content, format, _directed) do
    {:error, "Format '#{format}' not yet implemented"}
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

  defp detect_file_format(path) do
    ext = String.downcase(Path.extname(path))
    Map.get(@file_formats, ext)
  end

  defp sanitize_variable(name) do
    name
    |> String.trim()
    |> String.replace(~r/[^a-zA-Z0-9_]/, "_")
    |> String.replace(~r/^[0-9]/, "_\\0")
  end

  # Maximum content size to store in attributes (to prevent UI freezing)
  @max_attr_content_size 10_000

  @impl true
  def to_attrs(ctx) do
    content = ctx.assigns.content

    # Truncate content in attrs if too large (full content stays in process state)
    stored_content =
      if String.length(content) > @max_attr_content_size do
        String.slice(content, 0, @max_attr_content_size) <> "\n...[truncated]"
      else
        content
      end

    %{
      "mode" => ctx.assigns.mode,
      "file_path" => ctx.assigns.file_path,
      "content" => stored_content,
      "content_format" => ctx.assigns.content_format,
      "directed" => ctx.assigns.directed,
      "variable" => ctx.assigns.variable
    }
  end

  @impl true
  def to_source(attrs) do
    mode = attrs["mode"]
    variable = attrs["variable"]

    case mode do
      "file" ->
        path = attrs["file_path"]

        if path == "" do
          "# Select a graph file to import"
        else
          format = detect_file_format(path)

          if format do
            """
            # Import graph from #{format} file
            {:ok, #{variable}} = KinoYog.import_file("#{escape_string(path)}")
            """
          else
            """
            # Unsupported file format: #{Path.extname(path)}
            # Supported: .graphml, .json, .dot, .gdf, .net, .paj, .leda, .tgf
            """
          end
        end

      "paste" ->
        content = attrs["content"]
        format = attrs["content_format"]
        directed = attrs["directed"]

        if content == "" do
          "# Paste graph content above"
        else
          case format do
            "adjacency_list" ->
              if String.length(content) > @max_attr_content_size do
                """
                # Content too large for inline code (#{String.length(content)} chars)
                # Please save to a file and use:
                # {:ok, #{variable}} = KinoYog.import_file("/path/to/graph.txt")
                raise "Content too large - please use file import for large graphs"
                """
              else
                weighted = String.contains?(content, ",")
                content_escaped = escape_triple_quotes(content)

                """
                # Import from adjacency list
                #{variable} = 
                  KinoYog.import_content(
                    "#{content_escaped}",
                    :adjacency_list,
                    directed: #{directed},
                    weighted: #{weighted}
                  )
                """
              end

            "adjacency_matrix" ->
              lines = String.split(content, "\n", trim: true)

              if length(lines) > 50 do
                # For large matrices, suggest using file import instead
                """
                # Matrix too large for inline code (#{length(lines)}x#{length(lines)})
                # Please save to a file and use:
                # {:ok, #{variable}} = KinoYog.import_file("/path/to/matrix.txt")
                # Or use: KinoYog.import_content(your_matrix_content, :adjacency_matrix)
                raise "Matrix too large - please use file import for matrices larger than 50x50"
                """
              else
                """
                # Import from adjacency matrix
                content = \"\"\"
                #{content}
                \"\"\"
                #{variable} = KinoYog.import_content(content, :adjacency_matrix, directed: #{directed})
                """
              end

            "json" ->
              if String.length(content) > @max_attr_content_size do
                """
                # JSON too large for inline code (#{String.length(content)} chars)
                # Please save to a file and use:
                # {:ok, #{variable}} = KinoYog.import_file("/path/to/graph.json")
                raise "JSON too large - please use file import for large graphs"
                """
              else
                content_escaped = escape_triple_quotes(content)

                """
                # Import from JSON
                {:ok, #{variable}} = KinoYog.import_content("#{content_escaped}", :json)
                """
              end

            "edge_list" ->
              if String.length(content) > @max_attr_content_size do
                """
                # Edge list too large for inline code (#{String.length(content)} chars)
                # Please save to a file and use:
                # {:ok, #{variable}} = KinoYog.import_file("/path/to/edges.txt")
                raise "Edge list too large - please use file import for large graphs"
                """
              else
                content_escaped = escape_triple_quotes(content)

                """
                # Import from edge list
                #{variable} = KinoYog.import_content("#{content_escaped}", :edge_list, directed: #{directed})
                """
              end

            _ ->
              "# Format #{format} not yet implemented"
          end
        end
    end
  end

  defp escape_string(str) do
    str
    |> String.replace("\\", "\\\\")
    |> String.replace("\"", "\\\"")
  end

  defp escape_triple_quotes(content) do
    content
    |> String.replace("\\", "\\\\")
    |> String.replace("\"", "\\\"")
    |> String.replace("\n", "\\n")
  end

  asset "main.js" do
    """
    export async function init(ctx, payload) {
      ctx.importCSS("https://cdn.jsdelivr.net/npm/tailwindcss@2.2.19/dist/tailwind.min.css");
      
      const formats = payload.content_formats;
      const format = formats.find(f => f.id === payload.content_format) || formats[0];
      
      const root = document.createElement("div");
      root.innerHTML = `
        <div class="p-4 bg-white rounded-lg shadow space-y-4">
          <!-- Tabs -->
          <div class="flex space-x-4 border-b pb-4">
            <button id="tab-paste" class="px-4 py-2 rounded-md font-medium transition-colors">
              Paste Content
            </button>
            <button id="tab-file" class="px-4 py-2 rounded-md font-medium transition-colors">
              From File
            </button>
          </div>
          
          <!-- Variable Name (Common) -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Variable Name</label>
            <input type="text" id="variable" value="${payload.variable}"
              class="block w-full px-3 py-2 border rounded-md"
              placeholder="graph">
          </div>
          
          <!-- File Mode -->
          <div id="panel-file" class="space-y-4">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">File Path</label>
              <input type="text" id="file-path" value="${payload.file_path}"
                class="block w-full px-3 py-2 border rounded-md"
                placeholder="/path/to/graph.graphml">
              <p class="mt-1 text-xs text-gray-500">
                Supported: ${payload.file_extensions.join(", ")}
              </p>
              <p id="file-status" class="hidden mt-2 text-sm"></p>
            </div>
          </div>
          
          <!-- Paste Mode -->
          <div id="panel-paste" class="hidden space-y-4">
            <div class="flex items-center space-x-4">
              <div class="flex-1">
                <label class="block text-sm font-medium text-gray-700 mb-1">Format</label>
                <select id="content-format" class="block w-full px-3 py-2 border rounded-md">
                  ${formats.map(f => `<option value="${f.id}" ${f.id === payload.content_format ? 'selected' : ''}>${f.name}</option>`).join('')}
                </select>
              </div>
              <div class="pt-6">
                <label class="flex items-center">
                  <input type="checkbox" id="directed" ${payload.directed ? 'checked' : ''} class="mr-2">
                  <span class="text-sm text-gray-700">Directed</span>
                </label>
              </div>
            </div>
            
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Content</label>
              <textarea id="content" rows="8"
                class="block w-full px-3 py-2 border rounded-md font-mono text-sm"
                placeholder="${format.example.replace(/"/g, '&quot;')}"></textarea>
              <p class="mt-1 text-xs text-gray-500" id="example"></p>
            </div>
            
            <div id="paste-status" class="hidden"></div>
          </div>
        </div>
      `;
      
      ctx.root.appendChild(root);
      
      // Tab switching
      const tabFile = root.querySelector('#tab-file');
      const tabPaste = root.querySelector('#tab-paste');
      const panelFile = root.querySelector('#panel-file');
      const panelPaste = root.querySelector('#panel-paste');
      
      function setMode(mode) {
        if (mode === 'file') {
          tabFile.className = 'px-4 py-2 rounded-md font-medium bg-blue-600 text-white';
          tabPaste.className = 'px-4 py-2 rounded-md font-medium text-gray-600 hover:bg-gray-100';
          panelFile.classList.remove('hidden');
          panelPaste.classList.add('hidden');
        } else {
          tabPaste.className = 'px-4 py-2 rounded-md font-medium bg-blue-600 text-white';
          tabFile.className = 'px-4 py-2 rounded-md font-medium text-gray-600 hover:bg-gray-100';
          panelPaste.classList.remove('hidden');
          panelFile.classList.add('hidden');
        }
        ctx.pushEvent('update_mode', { mode });
      }
      
      setMode(payload.mode);
      
      tabFile.addEventListener('click', () => setMode('file'));
      tabPaste.addEventListener('click', () => setMode('paste'));
      
      // Common handlers
      const variableInput = root.querySelector('#variable');
      variableInput.addEventListener("input", (e) => {
        ctx.pushEvent("update_variable", { variable: e.target.value });
      });
      
      // File mode handlers
      const filePathInput = root.querySelector('#file-path');
      const fileStatus = root.querySelector('#file-status');
      filePathInput.addEventListener("input", (e) => {
        ctx.pushEvent("update_file_path", { path: e.target.value });
      });
      
      // Paste mode handlers
      const contentTextarea = root.querySelector('#content');
      const formatSelect = root.querySelector('#content-format');
      const directedCheck = root.querySelector('#directed');
      const exampleP = root.querySelector('#example');
      const pasteStatus = root.querySelector('#paste-status');
      
      contentTextarea.value = payload.content;
      updateExample(payload.content_format);
      
      function updateExample(formatId) {
        const f = formats.find(fmt => fmt.id === formatId);
        exampleP.textContent = f ? `Example: ${f.example}` : '';
      }
      
      formatSelect.addEventListener("change", (e) => {
        updateExample(e.target.value);
        // Only re-parse if content exists
        if (contentTextarea.value) {
          ctx.pushEvent("update_content_format", { format: e.target.value });
        }
      });
      
      directedCheck.addEventListener("change", (e) => {
        // Only re-parse if content exists
        if (contentTextarea.value) {
          ctx.pushEvent("toggle_directed", { directed: e.target.checked });
        }
      });
      
      // Debounced content update to prevent freezing with large inputs
      let debounceTimer;
      contentTextarea.addEventListener("input", (e) => {
        clearTimeout(debounceTimer);
        debounceTimer = setTimeout(() => {
          ctx.pushEvent("update_content", { content: e.target.value });
        }, 300);
      });
      
      // Handle parsed event for paste mode
      ctx.handleEvent("parsed", ({ stats, error }) => {
        if (error) {
          pasteStatus.className = "p-3 bg-red-50 text-red-700 rounded text-sm";
          pasteStatus.textContent = `Error: ${error}`;
        } else if (stats) {
          pasteStatus.className = "p-3 bg-green-50 text-green-700 rounded text-sm";
          pasteStatus.innerHTML = `✓ Parsed: <strong>${stats.nodes}</strong> nodes, <strong>${stats.edges}</strong> edges`;
        } else {
          pasteStatus.className = "hidden";
        }
        pasteStatus.classList.remove("hidden");
      });
    }
    """
  end
end
