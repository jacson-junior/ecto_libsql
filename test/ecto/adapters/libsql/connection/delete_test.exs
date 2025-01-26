defmodule Ecto.Adapters.LibSQL.DeleteTest do
  use ExUnit.Case, async: true

  import Ecto.Adapters.LibSQL.TestHelpers

  test "delete" do
    query = delete(nil, "schema", [x: 1, y: 2], [])
    assert query == ~s{DELETE FROM "schema" WHERE "x" = ? AND "y" = ?}
  end
end
