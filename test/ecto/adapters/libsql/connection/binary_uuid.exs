defmodule Ecto.Adapters.LibSQL.Connection.BinaryUUIDTest do
  use ExUnit.Case, async: false

  import Ecto.Query
  import Ecto.Adapters.LibSQL.TestHelpers

  alias EctoLibSQL.Schemas.Schema

  setup_all do
    Application.put_env(:ecto_libsql, :uuid_type, :binary)
    Application.put_env(:ecto_libsql, :binary_id_type, :binary)

    on_exit(fn ->
      Application.put_env(:ecto_libsql, :uuid_type, :string)
      Application.put_env(:ecto_libsql, :binary_id_type, :string)
    end)
  end

  describe "select" do
    test "casting uuid" do
      query =
        Schema
        |> select([], type(^"601d74e4-a8d3-4b6e-8365-eddb4c893327", Ecto.UUID))
        |> plan()

      assert ~s{SELECT ? FROM "schema" AS s0} == all(query)
    end

    test "casting binary_ids" do
      query =
        Schema
        |> select([], type(^"601d74e4-a8d3-4b6e-8365-eddb4c893327", :binary_id))
        |> plan()

      assert ~s{SELECT ? FROM "schema" AS s0} == all(query)
    end
  end
end
