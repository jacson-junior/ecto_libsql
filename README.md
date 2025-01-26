# Ecto libSQL Adapter

[![Build Status](https://github.com/jacson-junior/ecto_libsql/workflows/CI/badge.svg)](https://github.com/jacson-junior/ecto_libsql/actions)

An Ecto libSQL Adapter. Uses [ExLibSQL](https://github.com/jacson-junior/ex_libsql)
as the driver to communicate with libSQL.
Based on the [Ecto SQLite3 Adapter](https://github.com/elixir-sqlite/exqlite)

## Installation

```elixir
defp deps do
  [
    {:ecto_libsql, "~> 0.1"}
  ]
end
```

## Usage

Define your repo similar to this.

```elixir
defmodule MyApp.Repo do
  use Ecto.Repo, otp_app: :my_app, adapter: Ecto.Adapters.LibSQL
end
```

Configure your repository similar to the following. If you want to know more
about the possible options to pass the repository, checkout the documentation
for [`Ecto.Adapters.LibSQL`](https://hexdocs.pm/ecto_libsql/). It will have
more information on what is configurable.

```elixir
config :my_app,
  ecto_repos: [MyApp.Repo]

config :my_app, MyApp.Repo,
  mode: :local,
  path: "path/to/my/database.db"
```

## Benchmarks

We have some benchmarks comparing it against the `MySQL` and `Postgres` adapters.

You can read more about those at [bench/README.md](bench/README.md).

## Running Tests

Running unit tests

```sh
mix test
```

Running integration tests

```sh
EX_LIBSQL_INTEGRATION=true mix test
```
