defmodule Ecto.Adapters.LibSQL.Connection.DatetimeAddTest do
  use ExUnit.Case, async: true

  import Ecto.Query
  import Ecto.Adapters.LibSQL.TestHelpers

  test "add a month" do
    query =
      "schema"
      |> where([s], datetime_add(s.foo, 1, "month") > s.bar)
      |> select([], true)
      |> plan()

    assert ~s{SELECT 1 FROM "schema" AS s0 WHERE (CAST (strftime('%Y-%m-%dT%H:%M:%f000Z',s0.\"foo\",1 || ' month') AS TEXT) > s0."bar")} ==
             all(query)
  end

  test "add a month with a string cast" do
    query =
      "schema"
      |> where([s], datetime_add(type(s.foo, :string), 1, "month") > s.bar)
      |> select([], true)
      |> plan()

    assert ~s{SELECT 1 FROM "schema" AS s0 WHERE (CAST (strftime('%Y-%m-%dT%H:%M:%f000Z',CAST(s0.\"foo\" AS TEXT),1 || ' month') AS TEXT) > s0."bar")} ==
             all(query)
  end
end
