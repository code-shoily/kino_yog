defmodule KinoYog.RenderCell do
  @moduledoc """
  Smart cell for rendering graphs.

  Two modes:
  1. **Render Variable** - Visualize existing graph variables with GraphViz
  2. **Render Graph** - Generate and visualize graphs from built-in generators
  """

  use Kino.JS
  use Kino.JS.Live
  use Kino.SmartCell, name: "Yog - Render Graph"

  @graph_configs KinoYog.Generators.all()
  @graph_types Enum.map(@graph_configs, fn g -> Map.drop(g, [:estimator]) end)

  @impl true
  # GraphViz layout engines
  @layout_engines [
    %{id: "dot", name: "Dot (hierarchical)", description: "Good for directed graphs and trees"},
    %{
      id: "neato",
      name: "Neato (spring model)",
      description: "Force-directed, good for undirected graphs"
    },
    %{id: "fdp", name: "FDP (force-directed)", description: "Fast force-directed, large graphs"},
    %{
      id: "sfdp",
      name: "SFDP (scalable FDP)",
      description: "Multiscale force-directed, very large graphs"
    },
    %{
      id: "circo",
      name: "Circo (circular)",
      description: "Circular layout, good for cyclic structures"
    },
    %{id: "twopi", name: "Twopi (radial)", description: "Radial layout, good for trees"},
    %{id: "osage", name: "Osage (array-based)", description: "Good for structured layouts"},
    %{id: "patchwork", name: "Patchwork (squarified)", description: "Squarified treemap layout"}
  ]

  def init(attrs, ctx) do
    # "render" or "generate" (render is first/default)
    mode = attrs["mode"] || "render"
    graph_type = attrs["graph_type"] || "complete"
    params = attrs["params"] || %{}
    variable = attrs["variable"] || "graph"
    render_var = attrs["render_var"] || ""
    directed = attrs["directed"] || false
    layout = attrs["layout"] || "dot"

    # Set default params if empty
    params =
      if map_size(params) == 0 do
        graph_def = Enum.find(@graph_types, &(&1.id == graph_type))

        for p <- graph_def.params, into: %{} do
          {p.name, to_string(p.default)}
        end
      else
        params
      end

    ctx =
      assign(ctx,
        mode: mode,
        graph_type: graph_type,
        params: params,
        variable: variable,
        render_var: render_var,
        directed: directed,
        layout: layout,
        svg: nil,
        stats: nil,
        error: nil,
        available_graphs: [],
        binding: []
      )

    # Generate initial graph if in generate mode, or try to render if in render mode
    ctx =
      cond do
        mode == "generate" -> generate_and_render(ctx)
        mode == "render" and render_var != "" -> render_existing(ctx)
        true -> ctx
      end

    {:ok, ctx, reevaluate_on_change: true}
  end

  @impl true
  def handle_connect(ctx) do
    # Send initial render if available
    if ctx.assigns.svg do
      send(self(), {:send_initial_render, ctx.assigns.svg, ctx.assigns.stats})
    end

    {:ok,
     %{
       mode: ctx.assigns.mode,
       graph_types: @graph_types,
       graph_type: ctx.assigns.graph_type,
       params: ctx.assigns.params,
       variable: ctx.assigns.variable,
       render_var: ctx.assigns.render_var,
       directed: ctx.assigns.directed,
       layout: ctx.assigns.layout,
       layout_engines: @layout_engines,
       available_graphs: ctx.assigns.available_graphs
     }, ctx}
  end

  @impl true
  def handle_info({:send_initial_render, svg, stats}, ctx) do
    broadcast_event(ctx, "render", %{svg: svg, stats: stats, error: nil})
    {:noreply, ctx}
  end

  @impl true
  def handle_info({:scan_binding_result, graphs, binding}, ctx) do
    ctx = assign(ctx, available_graphs: graphs, binding: binding)

    # Broadcast updated graphs list to UI
    broadcast_event(ctx, "update_graphs", %{graphs: graphs})

    # If in render mode with a variable set, try to render it
    ctx =
      if ctx.assigns.mode == "render" and ctx.assigns.render_var != "" do
        render_existing(ctx)
      else
        ctx
      end

    {:noreply, ctx}
  end

  @impl true
  def handle_event("update_mode", %{"mode" => mode}, ctx) do
    {:noreply, assign(ctx, mode: mode)}
  end

  @impl true
  def handle_event("update_type", %{"type" => type}, ctx) do
    graph_def = Enum.find(@graph_types, &(&1.id == type))

    # Reset params with defaults
    default_params =
      for p <- graph_def.params, into: %{} do
        {p.name, to_string(p.default)}
      end

    ctx =
      assign(ctx,
        graph_type: type,
        params: default_params
      )

    {:noreply, generate_and_render(ctx)}
  end

  @impl true
  def handle_event("update_param", %{"name" => name, "value" => value}, ctx) do
    params = Map.put(ctx.assigns.params, name, value)
    ctx = assign(ctx, params: params)
    {:noreply, generate_and_render(ctx)}
  end

  @impl true
  def handle_event("update_variable", %{"variable" => variable}, ctx) do
    {:noreply, assign(ctx, variable: sanitize_variable(variable))}
  end

  @impl true
  def handle_event("update_render_var", %{"variable" => variable}, ctx) do
    ctx = assign(ctx, render_var: sanitize_variable(variable))
    {:noreply, render_existing(ctx)}
  end

  @impl true
  def handle_event("toggle_directed", %{"directed" => directed}, ctx) do
    ctx = assign(ctx, directed: directed)
    {:noreply, generate_and_render(ctx)}
  end

  @impl true
  def handle_event("update_layout", %{"layout" => layout}, ctx) do
    ctx = assign(ctx, layout: layout)
    {:noreply, generate_and_render(ctx)}
  end

  @impl true
  def scan_binding(pid, binding, _env) do
    # Find all Yog graph variables in the binding
    graphs =
      for {key, value} <- binding,
          is_atom(key),
          is_map(value),
          Map.has_key?(value, :__struct__),
          is_atom(value.__struct__),
          Module.split(value.__struct__) |> List.first() == "Yog",
          do: %{name: Atom.to_string(key), struct: value.__struct__}

    send(pid, {:scan_binding_result, graphs, binding})
  end

  defp generate_and_render(ctx) when ctx.assigns.mode == "generate" do
    case generate_graph(ctx.assigns) do
      {:ok, graph, stats} ->
        svg = render_graphviz(graph, ctx.assigns.layout)
        broadcast_event(ctx, "render", %{svg: svg, stats: stats, error: nil})
        assign(ctx, svg: svg, stats: stats, error: nil)

      {:error, reason} ->
        broadcast_event(ctx, "render", %{svg: nil, stats: nil, error: reason})
        assign(ctx, error: reason)
    end
  end

  defp generate_and_render(ctx), do: ctx

  defp render_existing(ctx) when ctx.assigns.mode == "render" do
    var = ctx.assigns.render_var
    binding = ctx.assigns.binding

    if var == "" or var == nil do
      broadcast_event(ctx, "render", %{
        svg: "<div class=\"p-4 text-gray-500\">Enter a variable name to render</div>",
        stats: nil,
        error: nil
      })

      ctx
    else
      # Try to access the variable from stored binding
      case fetch_graph_from_binding(var, binding) do
        {:ok, graph} ->
          svg = render_graphviz(graph, ctx.assigns.layout)
          stats = compute_stats_safe(graph)
          broadcast_event(ctx, "render", %{svg: svg, stats: stats, error: nil})
          assign(ctx, svg: svg, stats: stats, error: nil)

        {:error, reason} ->
          broadcast_event(ctx, "render", %{
            svg: "<div class=\"p-4 text-red-600\">#{reason}</div>",
            stats: nil,
            error: reason
          })

          assign(ctx, error: reason)
      end
    end
  end

  defp render_existing(ctx), do: ctx

  defp fetch_graph_from_binding(var_name, binding) do
    try do
      # Convert var_name to atom (since bindings use atoms)
      var_atom = String.to_atom(var_name)

      case List.keyfind(binding, var_atom, 0) do
        {^var_atom, value} ->
          # Check if it's a graph structure
          if is_map(value) and Map.has_key?(value, :__struct__) and
               is_atom(value.__struct__) and
               Module.split(value.__struct__) |> List.first() == "Yog" do
            {:ok, value}
          else
            {:error, "'#{var_name}' is not a Yog graph"}
          end

        nil ->
          {:error, "Variable '#{var_name}' not found"}
      end
    rescue
      e -> {:error, "Error accessing variable: #{Exception.message(e)}"}
    end
  end

  defp compute_stats_safe(graph) do
    try do
      compute_stats(graph)
    rescue
      _ -> nil
    end
  end

  defp generate_graph(%{graph_type: type_id, params: params, directed: directed}) do
    graph_def = Enum.find(@graph_types, &(&1.id == type_id))
    type = if directed, do: :directed, else: :undirected

    # Check guards
    guards = graph_def.guards || %{}

    try do
      parsed_params =
        for {k, v} <- params, into: %{} do
          case graph_def.params |> Enum.find(&(&1.name == k)) do
            %{type: "integer"} -> {k, String.to_integer(v)}
            %{type: "float"} -> {k, String.to_float(v)}
            _ -> {k, v}
          end
        end

      # Validate guards
      estimated_nodes = estimate_nodes(type_id, parsed_params)

      if estimated_nodes > Map.get(guards, :max_nodes, 1000) do
        {:error, "Graph too large (#{estimated_nodes} nodes). Max: #{guards.max_nodes}"}
      else
        graph = do_generate(type_id, parsed_params, type)
        stats = compute_stats(graph)
        {:ok, graph, stats}
      end
    rescue
      e -> {:error, Exception.message(e)}
    end
  end

  defp estimate_nodes(type_id, parsed_params) do
    KinoYog.Generators.estimate_nodes(type_id, parsed_params)
  end

  defp do_generate(type_id, params, type) do
    graph_def = Enum.find(@graph_configs, &(&1.id == type_id))
    module = graph_def.module

    # PLATONIC SOLIDS and some others might not support graph_type or have different names
    function_name = graph_def[:function] || String.to_atom("#{type_id}_with_type")

    # Map params to arguments in order
    args = for p <- graph_def.params, do: params[p.name]

    # Append type if not explicitly disabled
    args = if graph_def[:no_type_suffix], do: args, else: args ++ [type]

    apply(module, function_name, args)
  end

  defp compute_stats(graph) do
    %{
      nodes: Yog.Model.order(graph),
      edges: Yog.Model.edge_count(graph),
      type: if(graph.kind == :directed, do: "Directed", else: "Undirected"),
      connected:
        safe_check(fn -> length(Yog.Connectivity.Components.connected_components(graph)) == 1 end),
      bipartite: safe_check(fn -> Yog.Property.Bipartite.bipartite?(graph) end),
      has_eulerian: safe_check(fn -> Yog.Property.Eulerian.has_eulerian_circuit?(graph) end)
    }
  end

  defp safe_check(fun) do
    try do
      if fun.(), do: "Yes", else: "No"
    rescue
      _ -> "N/A"
    end
  end

  defp render_graphviz(graph, layout) do
    dot = Yog.Render.DOT.to_dot(graph, Yog.Render.DOT.default_options())

    # Check if the selected layout engine is available
    layout_engine = System.find_executable(layout)
    dot_engine = System.find_executable("dot")

    cond do
      is_nil(layout_engine) and not is_nil(dot_engine) and layout != "dot" ->
        # Fall back to dot if selected layout not found
        render_with_engine(dot, "dot", dot_engine, layout)

      is_nil(layout_engine) ->
        # GraphViz not installed at all
        """
        <div class="p-4 bg-yellow-50 text-yellow-800 rounded">
          <p class="font-semibold">GraphViz not installed</p>
          <p class="text-sm mt-1">Install GraphViz to see graph visualization:</p>
          <ul class="text-sm mt-1 list-disc list-inside">
            <li>Ubuntu/Debian: <code>sudo apt-get install graphviz</code></li>
            <li>macOS: <code>brew install graphviz</code></li>
            <li>Other: <a href="https://graphviz.org/download/" target="_blank">https://graphviz.org/download/</a></li>
          </ul>
          <p class="text-xs mt-2 text-gray-600">Generated DOT:</p>
          <pre class="text-xs bg-gray-100 p-2 mt-1 rounded overflow-auto max-h-40">#{escape_html(dot)}</pre>
        </div>
        """

      true ->
        render_with_engine(dot, layout, layout_engine, nil)
    end
  end

  defp render_with_engine(dot, _layout, engine_path, requested_layout) do
    tmp_dir = System.tmp_dir!()
    dot_file = Path.join(tmp_dir, "kino_yog_#{:erlang.unique_integer([:positive])}.dot")
    svg_file = Path.join(tmp_dir, "kino_yog_#{:erlang.unique_integer([:positive])}.svg")

    try do
      File.write!(dot_file, dot)

      case System.cmd(engine_path, ["-Tsvg", "-o", svg_file, dot_file]) do
        {_, 0} ->
          svg = File.read!(svg_file)

          # Add warning if we fell back to dot
          if requested_layout do
            warning = """
            <div class="mb-2 p-2 bg-yellow-50 text-yellow-800 text-sm rounded">
              ⚠️ Layout '#{requested_layout}' not found. Using 'dot' instead.
            </div>
            """

            warning <> svg
          else
            svg
          end

        {error, _} ->
          "<pre class=\"text-red-600\">GraphViz error: #{escape_html(error)}</pre>"
      end
    rescue
      e ->
        "<pre class=\"text-red-600\">Error: #{Exception.message(e)}</pre>"
    after
      File.rm_rf(dot_file)
      File.rm_rf(svg_file)
    end
  end

  defp escape_html(str) do
    str
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
  end

  defp sanitize_variable(name) do
    name
    |> String.trim()
    |> String.replace(~r/[^a-zA-Z0-9_]/, "_")
    |> String.replace(~r/^[0-9]/, "_\\0")
  end

  @impl true
  def to_attrs(ctx) do
    %{
      "mode" => ctx.assigns.mode,
      "graph_type" => ctx.assigns.graph_type,
      "params" => ctx.assigns.params,
      "variable" => ctx.assigns.variable,
      "render_var" => ctx.assigns.render_var,
      "directed" => ctx.assigns.directed,
      "layout" => ctx.assigns.layout
    }
  end

  @impl true
  def to_source(attrs) do
    if attrs["mode"] == "render" do
      """
      # Render existing graph variable: #{attrs["render_var"]}
      # The graph visualization is shown above
      """
    else
      graph_def = Enum.find(@graph_configs, &(&1.id == attrs["graph_type"]))

      param_list =
        graph_def.params
        |> Enum.map(fn p ->
          val = attrs["params"][p.name]
          if p.type == "integer", do: val, else: val
        end)
        |> Enum.join(", ")

      function_name = graph_def[:function] || attrs["graph_type"]

      type_suffix =
        cond do
          graph_def[:no_type_suffix] ->
            "(#{param_list})"

          attrs["directed"] ->
            "_with_type(#{param_list}#{if(param_list == "", do: "", else: ", ")}:directed)"

          true ->
            "(#{param_list})"
        end

      """
      # Generate #{graph_def.name}
      #{attrs["variable"]} = Yog.Generator.#{graph_def.module |> Module.split() |> List.last()}.#{function_name}#{type_suffix}
      """
    end
  end

  asset "main.js" do
    """
    export async function init(ctx, payload) {
      ctx.importCSS("https://cdn.jsdelivr.net/npm/tailwindcss@2.2.19/dist/tailwind.min.css");
      
      const root = document.createElement("div");
      root.innerHTML = `
        <div class="p-4 bg-white rounded-lg shadow space-y-4">
          <!-- Mode Selector -->
          <div class="flex space-x-4 border-b pb-4">
            <button id="mode-render" class="px-4 py-2 rounded-md font-medium transition-colors">
              Render Variable
            </button>
            <button id="mode-generate" class="px-4 py-2 rounded-md font-medium transition-colors">
              Render Graph
            </button>
          </div>
          
          <!-- Render Variable Mode (First) -->
          <div id="panel-render" class="space-y-4">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Graph Variable</label>
              <input type="text" id="render-var" value="${payload.render_var}" 
                class="block w-full px-3 py-2 border rounded-md"
                placeholder="Enter variable name (e.g., my_graph)">
              <div id="available-graphs" class="mt-2">
                ${payload.available_graphs && payload.available_graphs.length > 0 ? `
                  <p class="text-xs text-gray-500 mb-1">Available graphs:</p>
                  <div class="flex flex-wrap gap-2">
                    ${payload.available_graphs.map(g => 
                      `<button class="graph-var-btn px-2 py-1 text-xs bg-blue-100 hover:bg-blue-200 text-blue-800 rounded" data-var="${g.name}">${g.name}</button>`
                    ).join('')}
                  </div>
                ` : '<p class="text-xs text-gray-400">No graph variables found in notebook</p>'}
              </div>
            </div>
          </div>
          
          <!-- Render Graph Mode (Second) -->
          <div id="panel-generate" class="hidden space-y-4">
            <div class="flex items-center space-x-4">
              <div class="flex-1">
                <label class="block text-sm font-medium text-gray-700 mb-1">Graph Type</label>
                <select id="graph-type" class="block w-full px-3 py-2 border rounded-md">
                  <optgroup label="Classic Graphs">
                    ${payload.graph_types.filter(t => t.category === 'Classic').map(t => 
                      `<option value="${t.id}" ${t.id === payload.graph_type ? 'selected' : ''}>${t.name}</option>`
                    ).join('')}
                  </optgroup>
                  <optgroup label="Named Graphs">
                    ${payload.graph_types.filter(t => t.category === 'Named').map(t => 
                      `<option value="${t.id}" ${t.id === payload.graph_type ? 'selected' : ''}>${t.name}</option>`
                    ).join('')}
                  </optgroup>
                  <optgroup label="Random Graphs">
                    ${payload.graph_types.filter(t => t.category === 'Random').map(t => 
                      `<option value="${t.id}" ${t.id === payload.graph_type ? 'selected' : ''}>${t.name}</option>`
                    ).join('')}
                  </optgroup>
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
              <label class="block text-sm font-medium text-gray-700 mb-1">Variable Name</label>
              <input type="text" id="variable" value="${payload.variable}" 
                class="block w-48 px-3 py-2 border rounded-md">
            </div>
            
            <div id="params-container" class="grid grid-cols-2 gap-4">
              <!-- Params injected here -->
            </div>
            
            <!-- Layout Engine -->
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Layout Engine</label>
              <select id="layout" class="block w-full px-3 py-2 border rounded-md">
                ${payload.layout_engines.map(l => 
                  `<option value="${l.id}" ${l.id === payload.layout ? 'selected' : ''}>${l.name}</option>`
                ).join('')}
              </select>
              <p id="layout-desc" class="text-xs text-gray-500 mt-1"></p>
            </div>
          </div>
          
          <!-- Stats -->
          <div id="stats" class="hidden grid grid-cols-3 gap-4 text-sm"></div>
          
          <!-- Visualization -->
          <div id="visualization" class="border rounded-lg p-4 bg-gray-50 min-h-[200px]"></div>
        </div>
      `;
      
      ctx.root.appendChild(root);
      
      // Mode switching
      const modeGenerate = root.querySelector('#mode-generate');
      const modeRender = root.querySelector('#mode-render');
      const panelGenerate = root.querySelector('#panel-generate');
      const panelRender = root.querySelector('#panel-render');
      
      function setMode(mode) {
        if (mode === 'generate') {
          modeGenerate.className = 'px-4 py-2 rounded-md font-medium bg-blue-600 text-white';
          modeRender.className = 'px-4 py-2 rounded-md font-medium text-gray-600 hover:bg-gray-100';
          panelGenerate.classList.remove('hidden');
          panelRender.classList.add('hidden');
        } else {
          modeRender.className = 'px-4 py-2 rounded-md font-medium bg-blue-600 text-white';
          modeGenerate.className = 'px-4 py-2 rounded-md font-medium text-gray-600 hover:bg-gray-100';
          panelRender.classList.remove('hidden');
          panelGenerate.classList.add('hidden');
        }
        ctx.pushEvent('update_mode', { mode });
      }
      
      setMode(payload.mode);
      
      modeGenerate.addEventListener('click', () => setMode('generate'));
      modeRender.addEventListener('click', () => setMode('render'));
      
      // Generate mode handlers
      const graphTypeSelect = root.querySelector('#graph-type');
      const directedCheck = root.querySelector('#directed');
      const variableInput = root.querySelector('#variable');
      const paramsContainer = root.querySelector('#params-container');
      const renderVarInput = root.querySelector('#render-var');
      
      function renderParams(typeId) {
        const type = payload.graph_types.find(t => t.id === typeId);
        if (!type || !type.params.length) {
          paramsContainer.innerHTML = '<p class="text-sm text-gray-500 col-span-2">No parameters for this graph type</p>';
          return;
        }
        
        paramsContainer.innerHTML = type.params.map(p => `
          <div>
            <label class="block text-xs text-gray-600 mb-1">${p.label || p.name}</label>
            <div class="flex items-center space-x-2">
              <input type="range" 
                data-param="${p.name}"
                min="${p.min}" max="${p.max}" 
                step="${p.step || (p.type === 'integer' ? 1 : 0.01)}"
                value="${payload.params[p.name] || p.default}"
                class="flex-1">
              <input type="number"
                data-param-input="${p.name}"
                min="${p.min}" max="${p.max}"
                step="${p.step || (p.type === 'integer' ? 1 : 0.01)}"
                value="${payload.params[p.name] || p.default}"
                class="w-20 px-2 py-1 border rounded text-sm">
            </div>
          </div>
        `).join('');
        
        // Attach handlers
        paramsContainer.querySelectorAll('[data-param]').forEach(range => {
          range.addEventListener('input', (e) => {
            const name = e.target.dataset.param;
            const val = e.target.value;
            paramsContainer.querySelector(`[data-param-input="${name}"]`).value = val;
            ctx.pushEvent('update_param', { name, value: val });
          });
        });
        
        paramsContainer.querySelectorAll('[data-param-input]').forEach(input => {
          input.addEventListener('input', (e) => {
            const name = e.target.dataset.paramInput;
            const val = e.target.value;
            paramsContainer.querySelector(`[data-param="${name}"]`).value = val;
            ctx.pushEvent('update_param', { name, value: val });
          });
        });
      }
      
      renderParams(payload.graph_type);
      
      graphTypeSelect.addEventListener('change', (e) => {
        renderParams(e.target.value);
        ctx.pushEvent('update_type', { type: e.target.value });
      });
      
      directedCheck.addEventListener('change', (e) => {
        ctx.pushEvent('toggle_directed', { directed: e.target.checked });
      });
      
      variableInput.addEventListener('input', (e) => {
        ctx.pushEvent('update_variable', { variable: e.target.value });
      });
      
      // Layout engine handler
      const layoutSelect = root.querySelector('#layout');
      const layoutDesc = root.querySelector('#layout-desc');
      
      function updateLayoutDesc(layoutId) {
        const layout = payload.layout_engines.find(l => l.id === layoutId);
        layoutDesc.textContent = layout ? layout.description : '';
      }
      
      updateLayoutDesc(payload.layout);
      
      layoutSelect.addEventListener('change', (e) => {
        updateLayoutDesc(e.target.value);
        ctx.pushEvent('update_layout', { layout: e.target.value });
      });
      
      // Render mode handlers
      renderVarInput.addEventListener('input', (e) => {
        ctx.pushEvent('update_render_var', { variable: e.target.value });
      });
      
      // Graph variable button handlers
      root.querySelectorAll('.graph-var-btn').forEach(btn => {
        btn.addEventListener('click', (e) => {
          const varName = e.target.dataset.var;
          renderVarInput.value = varName;
          ctx.pushEvent('update_render_var', { variable: varName });
        });
      });
      
      // Handle events from server
      ctx.handleEvent('render', ({ svg, stats, error }) => {
        const viz = root.querySelector('#visualization');
        const statsDiv = root.querySelector('#stats');
        
        if (error) {
          viz.innerHTML = `<div class="text-red-600">${error}</div>`;
          statsDiv.classList.add('hidden');
        } else if (svg) {
          viz.innerHTML = svg;
          
          if (stats) {
            statsDiv.innerHTML = `
              <div class="bg-blue-50 p-3 rounded"><span class="text-blue-600">Nodes:</span> <strong>${stats.nodes}</strong></div>
              <div class="bg-blue-50 p-3 rounded"><span class="text-blue-600">Edges:</span> <strong>${stats.edges}</strong></div>
              <div class="bg-blue-50 p-3 rounded"><span class="text-blue-600">Type:</span> <strong>${stats.type}</strong></div>
              <div class="bg-green-50 p-3 rounded"><span class="text-green-600">Connected:</span> <strong>${stats.connected}</strong></div>
              <div class="bg-green-50 p-3 rounded"><span class="text-green-600">Bipartite:</span> <strong>${stats.bipartite}</strong></div>
              <div class="bg-green-50 p-3 rounded"><span class="text-green-600">Eulerian:</span> <strong>${stats.has_eulerian}</strong></div>
            `;
            statsDiv.classList.remove('hidden');
          }
        }
      });
      
      // Update available graphs when binding changes
      ctx.handleEvent('update_graphs', ({ graphs }) => {
        const container = root.querySelector('#available-graphs');
        if (graphs && graphs.length > 0) {
          container.innerHTML = `
            <p class="text-xs text-gray-500 mb-1">Available graphs:</p>
            <div class="flex flex-wrap gap-2">
              ${graphs.map(g => 
                `<button class="graph-var-btn px-2 py-1 text-xs bg-blue-100 hover:bg-blue-200 text-blue-800 rounded" data-var="${g.name}">${g.name}</button>`
              ).join('')}
            </div>
          `;
          
          // Re-attach handlers
          container.querySelectorAll('.graph-var-btn').forEach(btn => {
            btn.addEventListener('click', (e) => {
              const varName = e.target.dataset.var;
              renderVarInput.value = varName;
              ctx.pushEvent('update_render_var', { variable: varName });
            });
          });
        } else {
          container.innerHTML = '<p class="text-xs text-gray-400">No graph variables found in notebook</p>';
        }
      });
    }
    """
  end
end
