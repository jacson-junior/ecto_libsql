defmodule Ecto.Adapters.LibSQL.Connection.LockTest do
  use ExUnit.Case, async: true

  import Ecto.Query
  import Ecto.Adapters.LibSQL.TestHelpers

  alias EctoLibSQL.Schemas.Schema

  test "locks are unsupported" do
    assert_raise ArgumentError, "locks are not supported by libSQL", fn ->
      Schema
      |> lock("FOR SHARE NOWAIT")
      |> select([], true)
      |> plan()
      |> all()
    end

    assert_raise ArgumentError, "locks are not supported by libSQL", fn ->
      Schema
      |> lock([p], fragment("UPDATE on ?", p))
      |> select([], true)
      |> plan()
      |> all()
    end
  end
end
