defmodule LiveSync.MixProject do
  use Mix.Project

  def project do
    [
      app: :live_sync,
      version: "0.1.3",
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      test_paths: ["lib"],
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.html": :test,
        "coveralls.json": :test
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_env), do: ["lib"]

  def application do
    [
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  defp package do
    [
      maintainers: ["Michael St Clair"],
      description: "LiveView Sync Engine",
      files: ~w(lib .formatter.exs mix.exs README.md),
      links: %{"GitHub" => "https://github.com/devhub-tools/live-sync"},
      licenses: ["Apache-2.0"]
    ]
  end

  defp deps do
    [
      {:ecto, "~> 3.12"},
      {:ecto_sql, "~> 3.12"},
      {:phoenix_live_view, "~> 1.0"},
      {:postgrex, "~> 0.19"},
      # dev/test deps
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:excoveralls, "~> 0.10", only: :test},
      {:floki, ">= 0.30.0", only: :test},
      {:mix_audit, "~> 2.0", only: [:dev, :test], runtime: false},
      {:sobelow, "~> 0.13", only: [:dev, :test], runtime: false},
      {:styler, "~> 1.0", only: [:dev, :test], runtime: false}
    ]
  end
end
