defmodule Ecto.Adapters.LibSQL.Connection.StringEscapeTest do
  use ExUnit.Case, async: true

  import Ecto.Query
  import Ecto.Adapters.LibSQL.TestHelpers

  test "escapes escaped characters" do
    query =
      "schema"
      |> where(foo: "'\\  ")
      |> select([], true)
      |> plan()

    assert ~s{SELECT 1 FROM \"schema\" AS s0 WHERE (s0.\"foo\" = '''\\\\  ')} ==
             all(query)
  end

  test "escapes single quotes" do
    query =
      "schema"
      |> where(foo: "'")
      |> select([], true)
      |> plan()

    assert ~s{SELECT 1 FROM "schema" AS s0 WHERE (s0."foo" = '''')} == all(query)
  end
end
