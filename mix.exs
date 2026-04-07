defmodule KinoYog.MixProject do
  use Mix.Project

  @version "0.1.1"
  @source_url "https://github.com/code-shoily/kino_yog"

  def project do
    [
      app: :kino_yog,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Kino smart cells for Yog graph library",
      package: package(),
      docs: docs()
    ]
  end

  def application do
    [
      mod: {KinoYog, []},
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:yog_ex, git: "git@github.com:code-shoily/yog_ex.git", branch: "main"},
      {:kino, "~> 0.14"},
      {:jason, "~> 1.4"},
      {:ex_doc, "~> 0.40", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      name: "kino_yog",
      files: ~w(lib lib/assets mix.exs README.md LICENSE),
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => @source_url
      }
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"],
      source_url: @source_url
    ]
  end
end
