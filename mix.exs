defmodule EctoLibSQL.MixProject do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :ecto_libsql,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      source_url: "https://github.com/jacson-junior/ecto_libsql",
      homepage_url: "https://github.com/jacson-junior/ecto_libsql",
      deps: deps(),
      package: package(),
      description: description(),
      test_paths: test_paths(System.get_env("EX_LIBSQL_INTEGRATION")),
      elixirc_paths: elixirc_paths(Mix.env()),
      aliases: aliases(),

      # Docs
      name: "Ecto libSQL",
      docs: docs()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:decimal, "~> 1.6 or ~> 2.0"},
      {:ecto_sql, "~> 3.12"},
      {:ecto, "~> 3.12"},
      {:ex_libsql, path: "../ex_libsql"},
      {:ex_doc, "~> 0.27", only: [:dev], runtime: false},
      {:jason, ">= 0.0.0"},
      {:temp, "~> 0.4", only: [:test]},
      {:credo, "~> 1.6", only: [:dev, :test, :docs]},

      # Benchmarks
      {:benchee, "~> 1.0", only: :dev},
      {:benchee_markdown, "~> 0.2", only: :dev},
      {:postgrex, "~> 0.15", only: :dev},
      {:myxql, "~> 0.6", only: :dev}
    ]
  end

  defp description do
    "An libSQL Ecto3 adapter."
  end

  defp package do
    [
      files: ~w(
        lib
        .formatter.exs
        mix.exs
        README.md
        LICENSE
      ),
      name: "ecto_libsql",
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/jacson-junior/ecto_libsql"
      }
    ]
  end

  defp docs do
    [
      main: "Ecto.Adapters.LibSQL",
      source_ref: "v#{@version}",
      source_url: "https://github.com/jacson-junior/ecto_libsql"
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp test_paths(nil), do: ["test"]
  defp test_paths(_any), do: ["integration_test"]

  defp aliases do
    [
      lint: [
        "format --check-formatted",
        "deps.unlock --check-unused",
        "credo --all --strict"
      ]
    ]
  end
end
