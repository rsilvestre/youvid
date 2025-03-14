defmodule Youvid.MixProject do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :youvid,
      version: @version,
      name: "Youvid",
      description: "A tool to list or to retrieve video details from Youtube",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      docs: docs(),
      dialyzer: [
        plt_add_deps: :apps_direct,
        plt_add_apps: [],
        plt_ignore_apps: [:logger]
      ],
      # Coveralls configuration
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Youvid.Application, []}
    ]
  end

  defp deps do
    [
      {:elixir_xml_to_map, "~> 3.1"},
      {:ex_doc, "~> 0.37", only: :dev, runtime: false},
      {:poison, "~> 6.0"},
      {:httpoison, "~> 2.2"},
      {:typed_struct, "~> 0.3"},
      {:nimble_options, "~> 1.0"},
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      
      # YouCache dependency
      {:youcache, github: "rsilvestre/youcache"},

      # Optional S3 dependencies
      {:ex_aws, "~> 2.5", optional: true},
      {:ex_aws_s3, "~> 2.4", optional: true},
      {:sweet_xml, "~> 0.7", optional: true},
      {:configparser_ex, "~> 4.0", optional: true},

      # Optional Cachex dependency for distributed caching
      {:cachex, "~> 3.6", optional: true},
      # Mock library for testing
      {:meck, "~> 0.9", only: :test},
      # Test coverage tools
      {:excoveralls, "~> 0.18", only: :test},
      # Required by excoveralls
      {:castore, "~> 1.0", only: :test}
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"]
    ]
  end

  defp package() do
    [
      files: ~w(lib .formatter.exs mix.exs README*),
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/patrykwozinski/youvid"}
    ]
  end
end
