defmodule LiveSync.MixProject do
  use Mix.Project

  def project do
    [
      app: :live_sync,
      version: "0.1.0-beta.2",
      elixir: "~> 1.17",
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

  def application do
    [
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  defp package do
    [
      description: "LiveView Sync Engine",
      files: ~w(lib .formatter.exs mix.exs README.md),
      links: %{"GitHub" => "https://github.com/devhub-tools/live-sync"},
      licenses: ["Apache-2.0"]
    ]
  end

  defp deps do
    [
      {:ecto, "~> 3.12"},
      {:phoenix_live_view, "~> 1.0"},
      {:postgrex, "~> 0.19"},
      # dev/test deps
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:excoveralls, "~> 0.10", only: :test},
      {:mix_audit, "~> 2.0", only: [:dev, :test], runtime: false},
      {:sobelow, "~> 0.13", only: [:dev, :test], runtime: false},
      {:styler, "~> 1.0", only: [:dev, :test], runtime: false}
    ]
  end
end
